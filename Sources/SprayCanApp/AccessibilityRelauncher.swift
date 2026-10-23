import AppKit
import Darwin
import SprayCanCore

/// Opens Chromium-based apps (CEF: Spotify) with `--force-renderer-accessibility`, the only way they
/// build a full accessibility tree. An app opened normally is relaunched once, right after it starts,
/// when its profile asks for this.
final class AccessibilityRelauncher {
    static let flag = "--force-renderer-accessibility"
    private let settings = Settings.shared
    private var observers: [NSObjectProtocol] = []
    /// Bundle identifiers relaunched recently, so an app that ignores the flag is never relaunched in a loop.
    private var recent: [String: Date] = [:]

    init() {
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier, self.settings.appProfiles[id]?.launchAccessibility == true,
                  !Self.hasFlag(app.processIdentifier), (self.recent[id].map { Date().timeIntervalSince($0) > 60 } ?? true) else { return }
            self.relaunch(app) { _ in }
        })
    }
    deinit { observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver) }

    /// Apps opened just before Spray Can started (at login, Spotify often wins the race) were missed by
    /// the launch observer; relaunch those, but never one that has been in use for a while.
    func relaunchJustOpened() {
        for app in NSWorkspace.shared.runningApplications {
            guard let id = app.bundleIdentifier, settings.appProfiles[id]?.launchAccessibility == true, recent[id] == nil,
                  LaunchAccessibility.relaunchAtStart(launched: app.launchDate, now: Date()), !Self.hasFlag(app.processIdentifier) else { continue }
            relaunch(app) { _ in }
        }
    }

    /// The process's launch arguments, read with `sysctl(KERN_PROCARGS2)`; nil if unavailable.
    static func arguments(_ pid: pid_t) -> [String]? {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        let count = Int(buffer.withUnsafeBytes { $0.load(as: Int32.self) })
        // Layout: argc, executable path, padding NULs, then argc NUL-terminated arguments.
        var index = MemoryLayout<Int32>.size
        while index < size && buffer[index] != 0 { index += 1 }
        while index < size && buffer[index] == 0 { index += 1 }
        var arguments: [String] = []
        while arguments.count < count && index < size {
            let start = index
            while index < size && buffer[index] != 0 { index += 1 }
            arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments
    }
    static func hasFlag(_ pid: pid_t) -> Bool { arguments(pid)?.contains(flag) ?? false }

    /// Quit the app and open it again with the flag. Calls back with the new process, or nil if the
    /// app did not quit within 10 s (e.g. it asked to save) or did not reopen.
    func relaunch(_ app: NSRunningApplication, completion: @escaping (NSRunningApplication?) -> Void) {
        guard let id = app.bundleIdentifier, let url = app.bundleURL else { completion(nil); return }
        recent[id] = Date()
        app.terminate()
        func open(after waited: TimeInterval) {
            guard app.isTerminated else {
                if waited >= 10 { completion(nil); return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { open(after: waited + 0.25) }
                return
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = [Self.flag]
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { opened, _ in
                DispatchQueue.main.async { completion(opened) }
            }
        }
        open(after: 0)
    }
}
