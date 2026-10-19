import AppKit

/// Apps that can be given their own settings: running apps with a user interface, by bundle identifier.
enum AppProfileCandidates {
    struct App { let id: String; let name: String }
    static func running(excluding: Set<String>) -> [App] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications.compactMap { app -> App? in
            guard app.activationPolicy == .regular, app.processIdentifier != getpid(), let id = app.bundleIdentifier,
                  !excluding.contains(id), seen.insert(id).inserted else { return nil }
            return App(id: id, name: app.localizedName ?? id)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    static func icon(for id: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }
}
