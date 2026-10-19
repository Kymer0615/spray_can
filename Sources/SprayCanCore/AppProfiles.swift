import Foundation

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
    public init(name: String, ocr: AppOverride = .inherit, prescan: AppOverride = .inherit, scanTime: ScanTime = .normal) {
        self.name = name; self.ocr = ocr; self.prescan = prescan; self.scanTime = scanTime
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        ocr = (try? values.decodeIfPresent(AppOverride.self, forKey: .ocr)) ?? .inherit
        prescan = (try? values.decodeIfPresent(AppOverride.self, forKey: .prescan)) ?? .inherit
        scanTime = (try? values.decodeIfPresent(ScanTime.self, forKey: .scanTime)) ?? .normal
    }
    /// Nothing differs from the global settings.
    public var isDefault: Bool { ocr == .inherit && prescan == .inherit && scanTime == .normal }
}

/// What Spray Can does in one app after applying its profile to the global settings.
public struct AppBehavior: Equatable {
    public var ocr: Bool
    public var prescan: Bool
    public var scanTime: ScanTime
    public init(ocr: Bool, prescan: Bool, scanTime: ScanTime) { self.ocr = ocr; self.prescan = prescan; self.scanTime = scanTime }

    public static func resolve(bundleID: String?, profiles: [String: AppProfile], vision: Bool, prescan: Bool) -> AppBehavior {
        let profile = bundleID.flatMap { profiles[$0] }
        let ocr = profile?.ocr.resolve(vision) ?? vision
        // Reading ahead only makes sense where text is read at all.
        let ahead = ocr && (profile?.prescan.resolve(prescan) ?? prescan)
        return AppBehavior(ocr: ocr, prescan: ahead, scanTime: profile?.scanTime ?? .normal)
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
