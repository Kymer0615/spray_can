import AppKit
import Combine
import Carbon
import SprayCanCore
import os

final class AppController: ObservableObject {
    let settings = Settings.shared
    let keyboard = KeyboardCapture()
    let overlay = OverlayManager()
    let mouse = MouseDriver()
    let accessibility = AccessibilityProvider()
    let ocr = OCRProvider()
    let accessibilityChanges = AccessibilityChanges()
    @Published var status = "Ready when you are"
    @Published var active = false
    @Published var shortcutIssues: [String] = []
    var openSettings: (() -> Void)?
    var stateChanged: (() -> Void)?
    private var session = NavigationSession()
    var integrationTargets: [Target] { session.phase == .ready ? session.targets : [] }
    private var result = DiscoveryResult()
    private var targetPID: pid_t = 0
    private var deferred: [CapturedKey] = []
    private var selecting = false
    private var selectedTarget: Target?
    private var selectedFrame: CGRect?
    private var scrollIndex = 0
    private var previousG = false
    private var centerIndex = 0
    private var subscriptions = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var refreshWork: DispatchWorkItem?
    private let log = Logger(subsystem: "io.github.Kymer0615.SprayCan", category: "sessions")

    init() {
        accessibilityChanges.changed = { [weak self] in
            guard let self, self.active else { return }
            if !self.session.prefix.isEmpty || self.selecting || self.mouse.holding {
                self.cancel(); self.status = "The target window changed. Activate again to refresh."
            } else { self.scheduleRefresh() }
        }
        keyboard.onActivate = { [weak self] mode in self?.activate(mode) }
        keyboard.onKey = { [weak self] key in self?.handle(key) }
        keyboard.onInterrupted = { [weak self] message in
            guard let self else { return }
            if self.active { self.cancel() }
            if !message.isEmpty { self.status = message }
        }
        settings.$shortcuts.dropFirst().debounce(for: .milliseconds(150), scheduler: RunLoop.main).sink { [weak self] bindings in
            self?.keyboard.configure(bindings); self?.shortcutIssues = self?.keyboard.conflicts ?? []
        }.store(in: &subscriptions)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.willSleepNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.cancel(); self?.overlay.rebuild() })
        }
        observers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, self.active, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.processIdentifier != self.targetPID else { return }
            self.cancel()
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.cancel(); self?.overlay.rebuild() })
    }
    var accessibilityGranted: Bool { AXIsProcessTrusted() }
    var keyboardGranted: Bool { CGPreflightListenEventAccess() }
    var screenGranted: Bool { CGPreflightScreenCaptureAccess() }
    func start() {
        guard accessibilityGranted else { status = "Grant Accessibility to enable navigation."; return }
        keyboard.configure(settings.shortcuts); shortcutIssues = keyboard.conflicts
        keyboard.start(); status = "Ready when you are"
    }
    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }
    func requestKeyboard() { _ = CGRequestListenEventAccess() }
    func requestScreen() { _ = CGRequestScreenCaptureAccess() }
    func activate(_ mode: NavigationMode) {
        guard accessibilityGranted, !IsSecureEventInputEnabled() else {
            keyboard.setActive(false); status = "Navigation unavailable. Check permissions or Secure Input."; openSettings?(); return
        }
        refreshWork?.cancel(); ocr.cancel(); accessibilityChanges.stop(); mouse.release(); mouse.resetPosition(); deferred = []; selecting = false; selectedTarget = nil; selectedFrame = nil
        targetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        guard targetPID != getpid(), targetPID != 0 else { keyboard.setActive(false); status = "Switch to another app, then activate navigation."; return }
        active = true; keyboard.setActive(true); stateChanged?()
        let generation = session.begin(mode)
        status = mode == .freestyle ? "Move with arrows · Return to click" : "Finding targets…"
        render()
        let started = ProcessInfo.processInfo.systemUptime
        if mode == .grid || mode == .freestyle {
            let targets = mode == .grid ? Geometry.grid(screens: overlay.quartzScreens, cellSize: settings.cellSize) : []
            _ = session.publish(targets, generation: generation, vi: settings.vi)
            updateReadyStatus(); render(); return
        }
        let context = DiscoveryContext(pid: targetPID, screens: overlay.quartzScreens, allWindows: settings.allWindows, generation: generation)
        accessibility.discover(context) { [weak self] discovered in
            guard let self, self.active, self.session.generation == generation else { return }
            self.result = discovered
            self.accessibilityChanges.start(pid: self.targetPID)
            let targets = mode == .scroll ? discovered.scrollAreas : discovered.targets
            _ = self.session.publish(targets, generation: generation, vi: self.settings.vi)
            self.scrollIndex = 0
            self.updateReadyStatus()
            if mode == .scroll { self.focusScrollArea() }
            self.render(); self.drain()
            self.log.info("Discovery completed in \(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)) ms; targets: \(targets.count); bounded: \(discovered.timedOut)")
            if mode == .elements && self.settings.vision {
                let regions = discovered.captureRects.isEmpty ? context.screens : discovered.captureRects
                self.ocr.discover(screens: context.screens, regions: regions) { [weak self] text, error in
                    guard let self, self.active, self.session.generation == generation else { return }
                    if let error { self.status = error; self.render(); return }
                    guard !self.session.hasTyped else { return }
                    let merged = Geometry.merge(discovered.targets, text)
                    _ = self.session.publish(merged, generation: generation, vi: self.settings.vi)
                    self.updateReadyStatus(); self.render()
                }
            }
        }
    }
    func cancel() {
        refreshWork?.cancel(); ocr.cancel(); accessibilityChanges.stop(); session.cancel(); accessibility.invalidate(session.generation)
        deferred = []; selecting = false; active = false; selectedTarget = nil; selectedFrame = nil
        mouse.release(); mouse.resetPosition(); keyboard.setActive(false); overlay.hide(); stateChanged?()
    }
    private func updateReadyStatus() {
        if session.mode == .freestyle { status = "Move with arrows · Return to click" }
        else if session.mode == .scroll { status = result.scrollAreas.isEmpty ? "No scroll areas · ⇧⌘L for pointer scrolling" : "HJKL scroll · Tab changes area · Esc exits" }
        else { status = session.targets.isEmpty ? "No targets found · ⇧⌘K opens the grid" : "\(session.targets.count) targets · Type a label · Return clicks" }
        if result.timedOut && session.mode == .elements { status += " · Partial scan" }
    }
    private func render() {
        guard active else { return }
        overlay.render(targets: session.mode == .scroll ? [] : session.targets, prefix: session.prefix, mode: session.mode, status: status, selected: selectedFrame)
    }
    func handle(_ key: CapturedKey) {
        guard active else { return }
        let isLetter = key.text.count == 1 && key.text.first?.isLetter == true
        let action = KeyMap.action(code: key.code, text: key.text, modifiers: isLetter ? key.labelModifiers : key.modifiers, vi: settings.vi)
        if action == .hide || action == .settings { cancel(); if action == .settings { openSettings?() }; return }
        if action == .escape {
            if !deferred.isEmpty { deferred = []; status = "Input cleared"; render(); return }
            if session.escape() == .cancelled { cancel() } else { updateReadyStatus(); render() }
            return
        }
        if session.phase == .discovering || selecting {
            if deferred.count < 32 { deferred.append(key) } else { status = "Input queue full · Esc clears"; render() }
            return
        }
        if session.mode == .scroll { handleScroll(key); return }
        // Inherited activation modifiers affect labels only, never modified click actions.
        let labelAction = KeyMap.action(code: key.code, text: key.text, modifiers: key.labelModifiers, vi: settings.vi)
        if session.mode != .freestyle, case .label(let character) = labelAction {
            if !key.repeatKey { apply(session.type(character)) }
            render(); return
        }
        switch action {
        case .click(let button): performClick(button, modifiers: key.modifiers)
        case .doubleClick: performClick(0, modifiers: key.modifiers, count: 2)
        case .hold: mouse.hold(); status = "Dragging · Choose destination · Return drops"; render()
        case .backspace: session.backspace(); render()
        case .move(let x, let y, let full):
            let step = settings.cellSize / (full ? 1 : 6)
            move(CGPoint(x: mouse.point.x + CGFloat(x) * step, y: mouse.point.y + CGFloat(y) * step))
        case .edge(let x, let y):
            if let screen = screenAtPointer {
                move(CGPoint(x: x == 0 ? mouse.point.x : x < 0 ? screen.minX + 1 : screen.maxX - 1,
                             y: y == 0 ? mouse.point.y : y < 0 ? screen.minY + 1 : screen.maxY - 1))
            }
        case .center:
            if let screen = screenAtPointer {
                let points = [CGPoint(x: screen.midX, y: screen.midY), CGPoint(x: screen.minX + 1, y: screen.minY + 1), CGPoint(x: screen.maxX - 1, y: screen.minY + 1), CGPoint(x: screen.maxX - 1, y: screen.maxY - 1), CGPoint(x: screen.minX + 1, y: screen.maxY - 1)]
                move(points[centerIndex % points.count]); centerIndex += 1
            }
        case .scroll(let x, let y): mouse.scroll(x: x * 40, y: y * 40); scheduleRefresh()
        case .toggleLines: settings.showLines.toggle(); render()
        case .toggleLabels: settings.showLabels.toggle(); render()
        case .cellSize(let direction): settings.cellSize = min(240, max(32, settings.cellSize + Double(direction * 12))); rebuildGrid()
        case .contrast(let direction): settings.contrast = min(1, max(0.4, settings.contrast + Double(direction) * 0.05)); render()
        default: break
        }
    }
    private var screenAtPointer: CGRect? { overlay.quartzScreens.first { $0.contains(mouse.point) } ?? overlay.quartzScreens.first }
    private func move(_ point: CGPoint) {
        selectedTarget = nil; selectedFrame = nil
        let screens = overlay.quartzScreens
        let target: CGPoint
        if screens.contains(where: { $0.contains(point) }) { target = point }
        else if let screen = screenAtPointer { target = CGPoint(x: min(max(point.x, screen.minX), screen.maxX - 1), y: min(max(point.y, screen.minY), screen.maxY - 1)) }
        else { return }
        mouse.move(to: target); render()
    }
    private func apply(_ outcome: NavigationSession.Outcome) {
        switch outcome {
        case .selected(let target): select(target)
        case .invalid: status = "No matching label · Esc clears your input"
        default: break
        }
    }
    private func select(_ target: Target) {
        let generation = session.generation
        let finish: (CGRect?) -> Void = { [weak self] frame in
            guard let self, self.active, self.session.generation == generation else { return }
            self.selecting = false
            guard let frame, frame.width > 1, frame.height > 1 else { self.deferred = []; self.status = "Target changed · Activate again to refresh"; self.render(); return }
            self.selectedTarget = target; self.selectedFrame = frame
            self.mouse.move(to: CGPoint(x: frame.midX, y: frame.midY))
            self.status = target.source == .text ? "Text location · Return clicks here" : "Target selected · Return clicks · = starts dragging"
            self.render()
            if self.settings.instantClick && !self.mouse.holding { self.performClick(0, modifiers: []) }
            else { self.drain() }
        }
        if let element = result.elements[target.id], target.source == .accessibility {
            selecting = true; accessibility.validate(element, within: target.frame, completion: finish)
        } else { finish(target.frame) }
    }
    private func performClick(_ button: Int, modifiers: KeyModifiers, count: Int = 1) {
        let generation = session.generation
        let click: (CGRect?) -> Void = { [weak self] frame in
            guard let self, self.active, self.session.generation == generation else { return }
            self.selecting = false
            if self.selectedTarget?.source == .accessibility && frame == nil { self.deferred = []; self.status = "Target disappeared · Activate again to refresh"; self.render(); return }
            if let frame { self.mouse.move(to: CGPoint(x: frame.midX, y: frame.midY)) }
            // Order out click-through overlays before injecting mouse events; target app keeps focus.
            self.overlay.hide(); self.keyboard.setActive(false)
            self.selecting = true
            self.mouse.click(button: button, modifiers: modifiers, count: count) {
                guard self.session.generation == generation else { return }
                self.cancel(); self.status = "Ready when you are"
            }
        }
        if let target = selectedTarget, let element = result.elements[target.id], !mouse.holding {
            selecting = true; accessibility.validate(element, within: target.frame, completion: click)
        } else { click(nil) }
    }
    private func drain() {
        while active && !selecting && session.phase == .ready && !deferred.isEmpty {
            let key = deferred.removeFirst(); handle(key)
        }
    }
    private func rebuildGrid() {
        guard session.mode == .grid else { render(); return }
        let generation = session.begin(.grid)
        _ = session.publish(Geometry.grid(screens: overlay.quartzScreens, cellSize: settings.cellSize), generation: generation, vi: settings.vi)
        updateReadyStatus(); render()
    }
    private func scheduleRefresh() {
        guard session.mode == .elements, session.prefix.isEmpty, !mouse.holding else { return }
        selectedTarget = nil; selectedFrame = nil
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.active, self.session.prefix.isEmpty else { return }; self.activate(.elements)
        }
        refreshWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
    private func focusScrollArea() {
        guard !result.scrollAreas.isEmpty else { return }
        let target = result.scrollAreas[scrollIndex % result.scrollAreas.count]
        selectedFrame = target.frame; mouse.move(to: target.point); render()
    }
    private func handleScroll(_ key: CapturedKey) {
        if key.text == "[" && key.modifiers == .control { cancel(); return }
        guard !result.scrollAreas.isEmpty else { return }
        if key.code == 48 { scrollIndex = (scrollIndex + (key.modifiers.contains(.shift) ? result.scrollAreas.count - 1 : 1)) % result.scrollAreas.count; previousG = false; focusScrollArea(); return }
        let frame = result.scrollAreas[scrollIndex].frame
        let c = key.text
        let half = key.modifiers.contains(.shift)
        let dx = half ? Int(frame.width / 2) : 55
        let dy = half ? Int(frame.height / 2) : 55
        switch c {
        case "h": mouse.scroll(x: -dx, y: 0)
        case "l": mouse.scroll(x: dx, y: 0)
        case "j": mouse.scroll(x: 0, y: dy)
        case "k": mouse.scroll(x: 0, y: -dy)
        case "d": mouse.scroll(x: 0, y: Int(frame.height / 2))
        case "u": mouse.scroll(x: 0, y: -Int(frame.height / 2))
        case "g":
            if half { mouse.scroll(x: 0, y: 100000) }
            else if previousG { mouse.scroll(x: 0, y: -100000) }
            else { previousG = true; return }
        default: break
        }
        previousG = false
    }
}
