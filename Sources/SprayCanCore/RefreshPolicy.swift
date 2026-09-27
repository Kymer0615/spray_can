import Foundation

/// What changed around the navigation target.
public enum RefreshTrigger: Equatable {
    /// Focus moved to another window or app, or the window was created, moved, resized, or closed.
    case structural
    /// Only the focused window's title changed, e.g. a browser tab switch.
    case title
}

/// Decides how an active session reacts when its target window changes.
public enum RefreshPolicy {
    public enum Decision: Equatable { case refresh, cancel, ignore }
    /// Titles that tick (terminals, timers) must not re-scan continuously.
    public static let titleInterval: TimeInterval = 1.0

    public static func decide(_ trigger: RefreshTrigger, mode: NavigationMode, holding: Bool, selecting: Bool,
                              typing: Bool, sinceLastScan: TimeInterval) -> Decision {
        // A drag cannot follow a different window safely.
        if holding { return .cancel }
        // A click or validation in flight finishes the session itself.
        if selecting { return .ignore }
        switch mode {
        case .grid, .freestyle: return .ignore  // screen-based, independent of windows
        case .elements, .scroll:
            if trigger == .title && (typing || sinceLastScan < titleInterval) { return .ignore }
            return .refresh
        }
    }
}
