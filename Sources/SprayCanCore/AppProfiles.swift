import Foundation
import CoreGraphics

/// A per-app choice that can defer to the global setting.
public enum AppOverride: String, Codable, CaseIterable {
    case inherit, on, off
    public func resolve(_ global: Bool) -> Bool { self == .inherit ? global : self == .on }
}

/// How long the accessibility scan may take. Some apps (Finder, System Settings) answer slowly.
public enum ScanTime: String, Codable, CaseIterable {
    case normal, extended
    /// The first scan's budget and the retry's, in seconds.
    public var budget: (first: TimeInterval, retry: TimeInterval) { self == .normal ? (0.85, 2.0) : (2.0, 4.0) }
}

/// Settings for one app, keyed by bundle identifier. Missing fields decode to their defaults,
/// so profiles saved by older versions keep working when fields are added.
public struct AppProfile: Codable, Equatable {
    public var name: String
    public var ocr: AppOverride
    public var prescan: AppOverride
    public var scanTime: ScanTime
    /// Ask the app for its full accessibility tree (`AXEnhancedUserInterface`), with nested
    /// pressable wrappers pruned from the labels. Only offered for web-based apps.
    public var enhanced: Bool
    /// Open the app with `--force-renderer-accessibility`, which makes Chromium-based apps (CEF:
    /// Spotify) build their full accessibility tree. Spray Can relaunches the app once when it opens.
    public var launchAccessibility: Bool
    public init(name: String, ocr: AppOverride = .inherit, prescan: AppOverride = .inherit, scanTime: ScanTime = .normal,
                enhanced: Bool = false, launchAccessibility: Bool = false) {
        self.name = name; self.ocr = ocr; self.prescan = prescan; self.scanTime = scanTime
        self.enhanced = enhanced; self.launchAccessibility = launchAccessibility
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        ocr = (try? values.decodeIfPresent(AppOverride.self, forKey: .ocr)) ?? .inherit
        prescan = (try? values.decodeIfPresent(AppOverride.self, forKey: .prescan)) ?? .inherit
        scanTime = (try? values.decodeIfPresent(ScanTime.self, forKey: .scanTime)) ?? .normal
        // Command-line defaults are property lists, where a flag arrives as text ("YES", "1").
        func flag(_ key: CodingKeys) -> Bool {
            (try? values.decodeIfPresent(Bool.self, forKey: key))
                ?? (try? values.decodeIfPresent(String.self, forKey: key)).flatMap { ["1", "yes", "true"].contains($0.lowercased()) } ?? false
        }
        enhanced = flag(.enhanced)
        launchAccessibility = flag(.launchAccessibility)
    }
    /// Nothing differs from the global settings.
    public var isDefault: Bool { ocr == .inherit && prescan == .inherit && scanTime == .normal && !enhanced && !launchAccessibility }
}

/// What Spray Can does in one app after applying its profile to the global settings.
public struct AppBehavior: Equatable {
    public var ocr: Bool
    public var prescan: Bool
    public var scanTime: ScanTime
    public var enhanced: Bool
    public var launchAccessibility: Bool
    public init(ocr: Bool, prescan: Bool, scanTime: ScanTime, enhanced: Bool = false, launchAccessibility: Bool = false) {
        self.ocr = ocr; self.prescan = prescan; self.scanTime = scanTime; self.enhanced = enhanced; self.launchAccessibility = launchAccessibility
    }

    public static func resolve(bundleID: String?, profiles: [String: AppProfile], vision: Bool, prescan: Bool) -> AppBehavior {
        let profile = bundleID.flatMap { profiles[$0] }
        let ocr = profile?.ocr.resolve(vision) ?? vision
        // Reading ahead only makes sense where text is read at all.
        let ahead = ocr && (profile?.prescan.resolve(prescan) ?? prescan)
        return AppBehavior(ocr: ocr, prescan: ahead, scanTime: profile?.scanTime ?? .normal,
                           enhanced: profile?.enhanced ?? false, launchAccessibility: profile?.launchAccessibility ?? false)
    }

    /// Profiles as saved: a JSON object keyed by bundle identifier. Unreadable data means no profiles.
    public static func decode(_ json: String) -> [String: AppProfile] {
        (try? JSONDecoder().decode([String: AppProfile].self, from: Data(json.utf8))) ?? [:]
    }
    public static func encode(_ profiles: [String: AppProfile]) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(profiles)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}

/// What an app is built with, from the frameworks in its bundle. It decides which adaptations apply.
public enum AppKind: String, Codable {
    case native, electron, chromium, cef, webView2, qt, flutter

    public static func detect(frameworks: [String]) -> AppKind {
        func has(_ part: String) -> Bool { frameworks.contains { $0.localizedCaseInsensitiveContains(part) } }
        if has("Electron Framework") { return .electron }
        if has("Chromium Embedded Framework") { return .cef }
        if has("MSWebView2") { return .webView2 }
        if has("Chrome Framework") || has("Chromium Framework") || has("Edge Framework") || has("Brave") || has("Vivaldi") || has("Opera") { return .chromium }
        if frameworks.contains(where: { $0.hasPrefix("Qt") }) { return .qt }
        if has("FlutterMacOS") { return .flutter }
        return .native
    }
    /// Web-based apps that may answer `AXEnhancedUserInterface` with a fuller tree (Teams). Electron
    /// already exposes its tree when asked for a role; CEF (Spotify) accepts the switch but ignores it.
    public var enhanceable: Bool { [.chromium, .webView2].contains(self) }
    /// Chromium-based apps that build their full tree when launched with `--force-renderer-accessibility`
    /// (Spotify: 3 → 161 labels). Electron is left out: editors such as VS Code may switch to screen-reader mode.
    public var relaunchable: Bool { [.cef, .chromium].contains(self) }
}

/// One app's read-only measurement: how many labels Spray Can finds, and how much visible text they cover.
public struct AppAnalysis: Equatable {
    public var kind: AppKind
    public var labels: Int
    /// Share of recognized text lines that fall inside a labelled element; nil without Screen Recording.
    public var coverage: Double?
    public var textLines: Int
    public var scanMilliseconds: Int
    public var truncated: Bool
    /// Whether the app lets Spray Can turn on its full accessibility tree.
    public var enhanceSupported: Bool
    public init(kind: AppKind, labels: Int, coverage: Double?, textLines: Int, scanMilliseconds: Int, truncated: Bool, enhanceSupported: Bool) {
        self.kind = kind; self.labels = labels; self.coverage = coverage; self.textLines = textLines
        self.scanMilliseconds = scanMilliseconds; self.truncated = truncated; self.enhanceSupported = enhanceSupported
    }

    /// Labels already cover most visible text.
    public var readsWell: Bool { coverage.map { $0 >= 0.6 } ?? (labels >= 10) }

    /// Share of `lines` whose center lies inside (or within a few points of) some target.
    public static func coverage(lines: [CGRect], targets: [CGRect]) -> Double? {
        guard !lines.isEmpty else { return nil }
        let covered = lines.filter { line in targets.contains { $0.insetBy(dx: -4, dy: -4).contains(CGPoint(x: line.midX, y: line.midY)) } }
        return Double(covered.count) / Double(lines.count)
    }
}

/// Adaptations Spray Can can suggest after analyzing an app.
public enum AppAdvice: String, CaseIterable, Codable {
    case relaunch, enhance, ocr, extendScan

    /// Nothing is suggested when labels already cover most visible text, or for what `current` already does.
    public static func recommend(_ analysis: AppAnalysis, current: AppBehavior) -> [AppAdvice] {
        var advice: [AppAdvice] = []
        let coverage = analysis.coverage
        let poor = !analysis.readsWell
        if analysis.kind.relaunchable && poor && !current.launchAccessibility { advice.append(.relaunch) }
        if analysis.kind.enhanceable && analysis.enhanceSupported && poor && !current.enhanced { advice.append(.enhance) }
        // Little of the visible text is reachable: reading it is the dependable fallback. Some apps
        // (Spotify) accept the enhanced switch but ignore it, so this is offered alongside.
        if let coverage, coverage < 0.4, analysis.textLines >= 8, !current.ocr { advice.append(.ocr) }
        if (analysis.truncated || analysis.scanMilliseconds > 800) && current.scanTime == .normal { advice.append(.extendScan) }
        return advice
    }
}

/// Whether turning on an app's full accessibility tree helped enough to keep it.
public enum Enhancement {
    public static func worthKeeping(before: AppAnalysis, after: AppAnalysis) -> Bool {
        let more = Double(after.labels) >= Double(max(before.labels, 1)) * 1.2
        let covered = (after.coverage ?? 0) - (before.coverage ?? 0) >= 0.15
        return more || covered
    }
}
