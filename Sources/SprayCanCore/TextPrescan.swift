import Foundation
import CoreGraphics

/// Optional text recognition ahead of activation, so text labels can appear with the first frame
/// instead of reshuffling every label about a second later.
public enum TextPrescan {
    /// A window must keep focus this long before it is read; rapid switching never scans.
    public static let dwell: TimeInterval = 1.0
    /// Older results are discarded even when the window looks the same.
    public static let maxAge: TimeInterval = 120

    /// Background reading is a battery and privacy cost: only when asked for, on power, and idle.
    public static func allowed(enabled: Bool, vision: Bool, screenRecording: Bool, onPower: Bool, lowPower: Bool,
                               thermalSerious: Bool, sessionActive: Bool, ownApp: Bool) -> Bool {
        enabled && vision && screenRecording && onPower && !lowPower && !thermalSerious && !sessionActive && !ownApp
    }
}

/// A tiny grayscale thumbnail of a window, to tell whether saved text still matches the screen.
public struct TextFingerprint: Equatable {
    public static let width = 32, height = 20
    public let pixels: [UInt8]
    public init(pixels: [UInt8]) { self.pixels = pixels }

    /// Tolerates a blinking caret or a ticking clock, not a scroll or new text.
    public func matches(_ other: TextFingerprint) -> Bool {
        guard pixels.count == other.pixels.count, !pixels.isEmpty else { return false }
        var total = 0, changed = 0
        for (a, b) in zip(pixels, other.pixels) {
            let difference = abs(Int(a) - Int(b))
            total += difference
            if difference > 24 { changed += 1 }
        }
        return Double(total) / Double(pixels.count) <= 2 && Double(changed) <= Double(pixels.count) * 0.01
    }
}

/// Text read ahead of time for one window.
public struct TextCache {
    public let pid: Int32
    public let frame: CGRect
    public let languages: [String]
    public let fingerprint: TextFingerprint
    public let created: TimeInterval
    /// Text targets in global Quartz points.
    public let targets: [Target]
    public init(pid: Int32, frame: CGRect, languages: [String], fingerprint: TextFingerprint, created: TimeInterval, targets: [Target]) {
        self.pid = pid; self.frame = frame; self.languages = languages
        self.fingerprint = fingerprint; self.created = created; self.targets = targets
    }

    /// Same window, same languages, and recent; the caller still compares the fingerprint.
    public func reusable(pid: Int32, frame: CGRect, languages: [String], now: TimeInterval) -> Bool {
        let moved = max(abs(self.frame.minX - frame.minX), abs(self.frame.minY - frame.minY),
                        abs(self.frame.width - frame.width), abs(self.frame.height - frame.height))
        return self.pid == pid && moved <= 1 && self.languages == languages
            && now >= created && now - created <= TextPrescan.maxAge
    }
}
