import AppKit
import Carbon
import SprayCanCore

struct CapturedKey {
    let code: UInt16
    let text: String
    let modifiers: KeyModifiers
    let labelModifiers: KeyModifiers
    let repeatKey: Bool
}

/// No discovery, rendering, logging of text, or synchronous main-thread work in the callback.
final class KeyboardCapture {
    var onReady: (() -> Void)?
    var isRunning: Bool {
        lock.lock(); let port = tap; lock.unlock()
        return port.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
    }
    var onActivate: ((NavigationMode) -> Void)?
    var onKey: ((CapturedKey) -> Void)?
    var onInterrupted: ((String) -> Void)?
    private let lock = NSLock()
    private var active = false
    private var activationModifiers = ActivationModifiers()
    private var consumed = Set<UInt16>()
    private var shortcuts = Shortcut.defaults
    private var tap: CFMachPort?
    private var loop: CFRunLoop?
    private var hotKeys: [EventHotKeyRef] = []
    private var disabledModes = Set<NavigationMode>()
    private var started = false
    private var watchdog: Timer?
    private(set) var conflicts: [String] = []

    func configure(_ bindings: [NavigationMode: Shortcut]) {
        hotKeys.forEach { UnregisterEventHotKey($0) }; hotKeys = []; conflicts = []
        var blocked = Set<NavigationMode>()
        var seen: [Shortcut] = []
        for (index, mode) in NavigationMode.allCases.enumerated() {
            guard let shortcut = bindings[mode] else { continue }
            guard !seen.contains(shortcut) else { conflicts.append("\(mode.title): duplicate shortcut"); blocked.insert(mode); continue }
            seen.append(shortcut)
            var carbon: UInt32 = 0
            if shortcut.modifiers.contains(.shift) { carbon |= UInt32(shiftKey) }
            if shortcut.modifiers.contains(.command) { carbon |= UInt32(cmdKey) }
            if shortcut.modifiers.contains(.control) { carbon |= UInt32(controlKey) }
            if shortcut.modifiers.contains(.option) { carbon |= UInt32(optionKey) }
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(shortcut.keyCode), carbon, EventHotKeyID(signature: 0x53505259, id: UInt32(index + 1)), GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref { hotKeys.append(ref) }
            else { conflicts.append("\(mode.title): \(shortcutTitle(shortcut)) is already registered"); blocked.insert(mode) }
        }
        lock.lock(); shortcuts = bindings; disabledModes = blocked; lock.unlock()
    }
    func setActive(_ value: Bool) { lock.lock(); active = value; lock.unlock() }
    func start() {
        guard !started else { return }
        started = true
        watchdog?.invalidate()
        Thread.detachNewThread { [weak self] in self?.run() }
        watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if IsSecureEventInputEnabled() {
                self.setActive(false)
                self.onInterrupted?("Secure Input is enabled by another app. Disable it there to resume navigation.")
            }
        }
    }
    private func run() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, ref in
            guard let ref else { return Unmanaged.passUnretained(event) }
            return Unmanaged<KeyboardCapture>.fromOpaque(ref).takeUnretainedValue().receive(type, event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            DispatchQueue.main.async { self.started = false; self.onInterrupted?("Keyboard capture unavailable. Grant Accessibility, then retry.") }
            return
        }
        lock.lock(); tap = port; lock.unlock()
        loop = CFRunLoopGetCurrent()
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(loop, source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        DispatchQueue.main.async { self.onReady?() }
        CFRunLoopRun()
    }
    private func receive(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            setActive(false)
            DispatchQueue.main.async { self.onInterrupted?("Keyboard capture recovered. Start navigation again.") }
            return Unmanaged.passUnretained(event)
        }
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = KeyModifiers(event.flags)
        lock.lock()
        defer { lock.unlock() }
        activationModifiers.observe(modifiers)
        if type == .flagsChanged { return Unmanaged.passUnretained(event) }
        if type == .keyUp {
            if consumed.remove(code) != nil { return nil }
            return Unmanaged.passUnretained(event)
        }
        let repeated = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        // A label can itself be J/K/L. Residual activation modifiers must not
        // reinterpret that letter as another global activation.
        let inheritedLabel = active && !modifiers.isEmpty && activationModifiers.labelModifiers(modifiers).isEmpty
        if !inheritedLabel, let match = shortcuts.first(where: { !disabledModes.contains($0.key) && $0.value.keyCode == code && $0.value.modifiers == modifiers }) {
            consumed.insert(code)
            if !repeated {
                active = true; activationModifiers.begin(modifiers)
                DispatchQueue.main.async { self.onActivate?(match.key) }
            }
            return nil
        }
        guard active else { return Unmanaged.passUnretained(event) }
        // System app switching must stay available, even during a navigation session.
        if !inheritedLabel && ((code == 48 && modifiers.contains(.command)) || (code == 12 && modifiers.contains(.command))) {
            active = false
            DispatchQueue.main.async { self.onInterrupted?("") }
            return Unmanaged.passUnretained(event)
        }
        consumed.insert(code)
        // Explicit physical Latin labels work with IMEs without switching the system input source.
        var text = physicalKeys[code] ?? ""
        if modifiers.contains(.shift) && code == 43 { text = "<" }
        if modifiers.contains(.shift) && code == 47 { text = ">" }
        let key = CapturedKey(code: code, text: text, modifiers: modifiers,
                              labelModifiers: activationModifiers.labelModifiers(modifiers), repeatKey: repeated)
        DispatchQueue.main.async { self.onKey?(key) }
        return nil
    }
}
