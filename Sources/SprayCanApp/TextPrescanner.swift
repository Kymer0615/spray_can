import AppKit
import IOKit.ps
import SprayCanCore

/// Reads the focused window shortly after it gets focus, when the user opted in and the Mac is on
/// power, so a later activation can show text labels with the first frame instead of reshuffling.
/// Results are reused only while a tiny thumbnail of the window still matches.
final class TextPrescanner {
    private let settings = Settings.shared
    private let watcher = AccessibilityChanges()
    private let ocr = OCRProvider()
    private var work: DispatchWorkItem?
    private var cache: TextCache?
    private var paused = false
    private let frontWindow: (pid_t) -> CGRect?
    private let screens: () -> [CGRect]

    init(frontWindow: @escaping (pid_t) -> CGRect?, screens: @escaping () -> [CGRect]) {
        self.frontWindow = frontWindow; self.screens = screens
        watcher.changed = { [weak self] _ in self?.schedule() }
    }

    /// A session started: stop watching and reading until it ends.
    func pause() { paused = true; work?.cancel(); ocr.cancel(); watcher.stop() }
    /// Watch the frontmost app again and read it once it keeps focus.
    func resume() {
        paused = false; work?.cancel(); ocr.cancel(); watcher.stop()
        guard settings.prescanText, settings.vision, let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid() else { return }
        watcher.start(pid: app.processIdentifier)
        schedule()
    }
    /// Settings changed: saved text may be read with other languages, or no longer wanted.
    func reset() { cache = nil; resume() }

    private func schedule() {
        work?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.scan() }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + TextPrescan.dwell, execute: item)
    }
    private static var onPower: Bool {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        return (IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?) == kIOPMACPowerKey
    }
    private func scan() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let pid = app.processIdentifier
        let process = ProcessInfo.processInfo
        guard TextPrescan.allowed(enabled: settings.prescanText, vision: settings.vision, screenRecording: CGPreflightScreenCaptureAccess(),
                                  onPower: Self.onPower, lowPower: process.isLowPowerModeEnabled,
                                  thermalSerious: process.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue,
                                  sessionActive: paused, ownApp: pid == getpid()),
              let window = frontWindow(pid) else { return }
        let languages = settings.ocrLanguages
        Task { @MainActor [weak self] in
            guard let before = await OCRProvider.fingerprint(of: window), let self, !self.paused else { return }
            // Still the same picture: nothing new to read.
            if let cache = self.cache, cache.reusable(pid: pid, frame: window, languages: languages, now: process.systemUptime),
               cache.fingerprint.matches(before) { return }
            self.ocr.discover(screens: self.screens(), regions: [window], languages: languages) { [weak self] text, error in
                guard let self, !self.paused, error == nil else { return }
                self.cache = TextCache(pid: pid, frame: window, languages: languages, fingerprint: before,
                                       created: process.systemUptime, targets: text)
            }
        }
    }

    /// Text read earlier for this window, if the window still looks the same. Returns false when
    /// nothing saved could apply, so the caller need not wait; otherwise calls back once on main.
    func text(pid: pid_t, frame: CGRect, languages: [String], completion: @escaping ([Target]?) -> Void) -> Bool {
        guard settings.prescanText, let cache, cache.reusable(pid: pid, frame: frame, languages: languages, now: ProcessInfo.processInfo.systemUptime)
        else { return false }
        Task { @MainActor in
            let now = await OCRProvider.fingerprint(of: frame)
            completion(now.map(cache.fingerprint.matches) == true ? cache.targets : nil)
        }
        return true
    }
}
