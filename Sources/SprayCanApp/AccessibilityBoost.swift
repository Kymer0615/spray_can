import AppKit
import SprayCanCore

/// Turns on `AXEnhancedUserInterface` (an app's full accessibility tree) for apps whose profile asks
/// for it, and off again when the profile changes or Spray Can quits. Apps that were already in this
/// mode (VoiceOver, another tool) are left alone, so Spray Can only turns off what it turned on.
final class AccessibilityBoost {
    private static let attribute = "AXEnhancedUserInterface" as CFString
    private let settings = Settings.shared
    /// Apps Spray Can switched on, by process.
    private var switched = Set<pid_t>()
    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            // A relaunched app starts without the mode; give it a moment to create its windows.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.apply() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { self?.switched.remove(app.processIdentifier) }
        })
    }
    deinit { observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver) }

    static func isOn(_ pid: pid_t) -> Bool {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), attribute, &value)
        return (value as? Bool) ?? false
    }
    static func supported(_ pid: pid_t) -> Bool {
        var settable: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(AXUIElementCreateApplication(pid), attribute, &settable) == .success && settable.boolValue
    }
    /// Some apps report an error yet take the value, so the result is read back.
    @discardableResult private static func set(_ pid: pid_t, _ on: Bool) -> Bool {
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), attribute, on ? kCFBooleanTrue : kCFBooleanFalse)
        return isOn(pid) == on
    }

    /// Switch an app on now (for a trial or a profile). False if it was already on or refused.
    @discardableResult func enable(_ pid: pid_t) -> Bool {
        guard !switched.contains(pid), !Self.isOn(pid), Self.set(pid, true) else { return switched.contains(pid) }
        switched.insert(pid); return true
    }
    func disable(_ pid: pid_t) {
        guard switched.remove(pid) != nil else { return }
        Self.set(pid, false)
    }
    /// Match running apps to their profiles.
    func apply() {
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            let wanted = app.bundleIdentifier.flatMap { settings.appProfiles[$0]?.enhanced } ?? false
            if wanted { enable(app.processIdentifier) } else { disable(app.processIdentifier) }
        }
    }
    /// Leave no app in enhanced mode after Spray Can quits.
    func restoreAll() { for pid in switched { Self.set(pid, false) }; switched = [] }
}
