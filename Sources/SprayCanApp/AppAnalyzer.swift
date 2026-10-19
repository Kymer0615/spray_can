import AppKit
import ScreenCaptureKit
import SprayCanCore

/// Measures how well Spray Can reads chosen apps, suggests adaptations, and tries enhanced
/// accessibility before keeping it. Analysis only reads; nothing changes until a suggestion is applied.
final class AppAnalyzer: ObservableObject {
    struct Entry {
        let name: String
        var analysis: AppAnalysis?
        var problem: String?
        var advice: [AppAdvice] = []
        /// What applying did, e.g. an enhancement kept or turned off again.
        var outcome: String?
    }
    @Published private(set) var entries: [String: Entry] = [:]
    @Published private(set) var busy = false
    private let accessibility = AccessibilityProvider()
    private let boost: AccessibilityBoost
    private let relauncher: AccessibilityRelauncher
    private let settings = Settings.shared
    private var generation = 1_000_000

    init(boost: AccessibilityBoost, relauncher: AccessibilityRelauncher) { self.boost = boost; self.relauncher = relauncher }
    /// Documentation renders show example results without analyzing real apps.
    func showExamples(_ examples: [String: Entry]) { entries = examples }

    static func kind(of id: String) -> AppKind {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return .native }
        let frameworks = (try? FileManager.default.contentsOfDirectory(atPath: url.appendingPathComponent("Contents/Frameworks").path)) ?? []
        return AppKind.detect(frameworks: frameworks)
    }

    /// Analyze apps one after another.
    func analyze(_ ids: [String]) {
        guard !busy, !ids.isEmpty else { return }
        busy = true
        func next(_ remaining: ArraySlice<String>) {
            guard let id = remaining.first else { busy = false; return }
            measure(id, prune: settings.appProfiles[id]?.enhanced ?? false) { [weak self] entry, _ in
                guard let self else { return }
                var entry = entry
                entry.advice = entry.analysis.map { AppAdvice.recommend($0, current: self.settings.behavior(for: id)) } ?? []
                self.entries[id] = entry
                next(remaining.dropFirst())
            }
        }
        next(ids[...])
    }

    /// Apply chosen suggestions. Enhanced accessibility is tried first and kept only if it helps.
    func apply(_ id: String, _ advice: Set<AppAdvice>, completion: @escaping () -> Void = {}) {
        guard let entry = entries[id] else { return }
        if advice.contains(.ocr) { settings.updateProfile(id, name: entry.name) { $0.ocr = .on } }
        if advice.contains(.extendScan) { settings.updateProfile(id, name: entry.name) { $0.scanTime = .extended } }
        if advice.contains(.relaunch) { relaunch(id, entry: entry, completion: completion); return }
        guard advice.contains(.enhance), let before = entry.analysis,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first else {
            entries[id]?.outcome = String(localized: "Applied."); completion(); return
        }
        busy = true
        let pid = app.processIdentifier
        guard boost.enable(pid) else {
            busy = false; entries[id]?.outcome = String(localized: "This app didn’t accept enhanced accessibility."); completion(); return
        }
        // Web apps rebuild their tree after the switch; give them a moment.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.measure(id, prune: true, lines: self.lastLines[id]) { [weak self] after, _ in
                guard let self else { return }
                self.busy = false
                guard let analysis = after.analysis, Enhancement.worthKeeping(before: before, after: analysis) else {
                    self.boost.disable(pid)
                    self.entries[id]?.outcome = String(localized: "Turned off again: it didn’t help enough (labels \(before.labels) → \(after.analysis?.labels ?? 0)).")
                    completion(); return
                }
                self.settings.updateProfile(id, name: entry.name) { $0.enhanced = true }
                self.entries[id]?.analysis = analysis
                self.entries[id]?.advice = []
                self.entries[id]?.outcome = String(localized: "Kept: labels \(before.labels) → \(analysis.labels), text covered \(Self.percent(before.coverage)) → \(Self.percent(analysis.coverage)).")
                completion()
            }
        }
    }

    /// Quit and reopen the app with full accessibility, wait for its window, and keep the setting only if it helps.
    private func relaunch(_ id: String, entry: Entry, completion: @escaping () -> Void) {
        guard let before = entry.analysis, let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first else { completion(); return }
        busy = true
        relauncher.relaunch(app) { [weak self] reopened in
            guard let self else { return }
            guard reopened != nil else {
                self.busy = false
                self.entries[id]?.outcome = String(localized: "The app didn’t quit or reopen. Quit it yourself, then try again.")
                completion(); return
            }
            self.whenWindowAppears(id, waited: 0) {
                self.measure(id, prune: false, lines: self.lastLines[id]) { [weak self] after, _ in
                    guard let self else { return }
                    self.busy = false
                    guard let analysis = after.analysis, Enhancement.worthKeeping(before: before, after: analysis) else {
                        self.entries[id]?.outcome = String(localized: "Not kept: it didn’t help enough (labels \(before.labels) → \(after.analysis?.labels ?? 0)). The app keeps running this way until you quit it.")
                        completion(); return
                    }
                    self.settings.updateProfile(id, name: entry.name) { $0.launchAccessibility = true }
                    self.entries[id]?.analysis = analysis
                    self.entries[id]?.advice = AppAdvice.recommend(analysis, current: self.settings.behavior(for: id))
                    self.entries[id]?.outcome = String(localized: "Kept: labels \(before.labels) → \(analysis.labels), text covered \(Self.percent(before.coverage)) → \(Self.percent(analysis.coverage)).")
                    completion()
                }
            }
        }
    }
    /// A relaunched app needs its window, then a moment to build its tree.
    private func whenWindowAppears(_ id: String, waited: TimeInterval, then: @escaping () -> Void) {
        if let pid = NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.processIdentifier, Self.mainWindow(of: pid) != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { then() }; return
        }
        guard waited < 20 else { then(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.whenWindowAppears(id, waited: waited + 0.5, then: then) }
    }

    static func percent(_ value: Double?) -> String { value.map { "\(Int(($0 * 100).rounded()))%" } ?? "–" }

    /// Recognized text lines per app, reused for the after-measurement (the text doesn't change).
    private var lastLines: [String: [CGRect]] = [:]

    private func measure(_ id: String, prune: Bool, lines known: [CGRect]? = nil, completion: @escaping (Entry, [CGRect]) -> Void) {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: id).first else {
            completion(Entry(name: id, problem: String(localized: "Not running.")), []); return
        }
        let name = app.localizedName ?? id
        let pid = app.processIdentifier
        guard let (windowID, frame) = Self.mainWindow(of: pid), let axWindow = Self.axWindow(of: pid, near: frame) else {
            completion(Entry(name: name, problem: String(localized: "Open a window of this app, then analyze again.")), []); return
        }
        generation += 1
        let screens = NSScreen.screens.map { Geometry.cocoa($0.frame, primaryHeight: NSScreen.screens.first?.frame.height ?? 0) }
        let context = DiscoveryContext(pid: pid, screens: screens, allWindows: false, generation: generation, prune: prune, window: axWindow)
        accessibility.survey(context) { [weak self] result, milliseconds in
            guard let self else { return }
            let finish = { (lines: [CGRect]?) in
                if let lines { self.lastLines[id] = lines }
                let analysis = AppAnalysis(kind: Self.kind(of: id), labels: result.targets.count,
                                           coverage: lines.flatMap { AppAnalysis.coverage(lines: $0, targets: result.targets.map(\.frame)) },
                                           textLines: lines?.count ?? 0, scanMilliseconds: milliseconds, truncated: result.timedOut,
                                           enhanceSupported: AccessibilityBoost.supported(pid))
                completion(Entry(name: name, analysis: analysis), lines ?? [])
            }
            if let known { finish(known); return }
            Task { @MainActor in finish(await Self.textLines(windowID: windowID, frame: frame, languages: self.settings.ocrLanguages)) }
        }
    }

    /// The app's largest on-screen normal window: its window number and global Quartz frame.
    private static func mainWindow(of pid: pid_t) -> (CGWindowID, CGRect)? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.compactMap { info -> (CGWindowID, CGRect)? in
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid, (info[kCGWindowLayer as String] as? Int) == 0,
                  let number = info[kCGWindowNumber as String] as? CGWindowID,
                  let frame = (info[kCGWindowBounds as String] as? NSDictionary).flatMap({ CGRect(dictionaryRepresentation: $0) }),
                  frame.width > 200, frame.height > 150 else { return nil }
            return (number, frame)
        }.max { $0.1.width * $0.1.height < $1.1.width * $1.1.height }
    }
    private static func axWindow(of pid: pid_t, near frame: CGRect) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.3)
        let windows: [AXUIElement] = axValue(app, kAXWindowsAttribute) ?? []
        return windows.first { axFrame($0).map { abs($0.minX - frame.minX) < 4 && abs($0.minY - frame.minY) < 4 } ?? false } ?? windows.first
    }
    /// Text lines in the window, read on-device; nil without Screen Recording.
    private static func textLines(windowID: CGWindowID, frame: CGRect, languages: [String]) async -> [CGRect]? {
        guard CGPreflightScreenCaptureAccess(),
              let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true),
              let window = content.windows.first(where: { $0.windowID == windowID }) else { return nil }
        let config = SCStreamConfiguration()
        config.width = Int(frame.width); config.height = Int(frame.height); config.showsCursor = false
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config),
              let text = try? OCRProvider.recognize(image, languages: languages) else { return nil }
        return text.filter { $0.confidence >= 0.65 }.map { line in
            let b = line.frame
            return CGRect(x: frame.minX + b.minX * frame.width, y: frame.minY + (1 - b.maxY) * frame.height, width: b.width * frame.width, height: b.height * frame.height)
        }
    }
}
