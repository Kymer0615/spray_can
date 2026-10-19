import AppKit
import SwiftUI
import SprayCanCore

@main
enum SprayCanMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let controller = AppController()
    private var item: NSStatusItem!
    private var integrationHarness: IntegrationHarness?
    private var snapshot: OverlaySnapshot?
    private var settingsWindow: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.toolTip = String(localized: "Spray Can — keyboard navigation")
        controller.stateChanged = { [weak self] in self?.updateIcon(); self?.rebuildMenu() }
        controller.openSettings = { [weak self] in self?.showSettings() }
        updateIcon(); rebuildMenu()
        if ProcessInfo.processInfo.arguments.contains("--render-docs") { DocumentationRenderer.render(); NSApp.terminate(nil); return }
        if ProcessInfo.processInfo.arguments.contains("--render-overlay") { snapshot = OverlaySnapshot(); snapshot?.run(); return }
        if ProcessInfo.processInfo.arguments.contains("--analyze-apps") { AnalysisHarness.run(controller.analyzer, boost: controller.boost); return }
        if ProcessInfo.processInfo.arguments.contains("--diagnose") {
            print("Accessibility: \(controller.accessibilityGranted); Keyboard capture running: \(controller.keyboardReady); Screen Recording: \(controller.screenGranted)")
            NSApp.terminate(nil); return
        }
        if ProcessInfo.processInfo.arguments.contains("--integration-test") {
            integrationHarness = IntegrationHarness(controller: controller); integrationHarness?.start(); return
        }
        controller.start()
        if !controller.accessibilityGranted || !UserDefaults.standard.bool(forKey: "onboarded") {
            showSettings(); UserDefaults.standard.set(true, forKey: "onboarded")
        }
    }
    func applicationWillTerminate(_ notification: Notification) { controller.cancel(); controller.boost.restoreAll() }
    private func updateIcon() {
        let name = controller.active ? "MenuActive" : "MenuIdle"
        let image = NSImage(named: name) ?? NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.labelColor.setStroke()
            let path = NSBezierPath(roundedRect: CGRect(x: 5, y: 1, width: 9, height: 12), xRadius: 2, yRadius: 2)
            path.lineWidth = 1.4; path.stroke()
            NSBezierPath(rect: CGRect(x: 8, y: 14, width: 3, height: 3)).stroke()
            return true
        }
        image.isTemplate = true; image.size = NSSize(width: 18, height: 18)
        item?.button?.image = image
    }
    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: "Spray Can", action: nil, keyEquivalent: ""); title.isEnabled = false; menu.addItem(title)
        let status = NSMenuItem(title: controller.status, action: nil, keyEquivalent: ""); status.isEnabled = false; menu.addItem(status)
        for mode in NavigationMode.allCases {
            let entry = NSMenuItem(title: "\(mode.localizedTitle)  \(shortcutTitle(controller.settings.shortcuts[mode]!))", action: #selector(startMode(_:)), keyEquivalent: "")
            entry.representedObject = mode.rawValue; entry.target = self; menu.addItem(entry)
        }
        menu.addItem(.separator())
        let thisApp = NSMenuItem(title: "", action: nil, keyEquivalent: ""); thisApp.tag = Self.thisAppTag; menu.addItem(thisApp)
        updateThisApp(thisApp)
        let preferences = NSMenuItem(title: String(localized: "Settings…"), action: #selector(settingsAction), keyEquivalent: ","); preferences.target = self; menu.addItem(preferences)
        let help = NSMenuItem(title: String(localized: "Help & Shortcuts"), action: #selector(helpAction), keyEquivalent: ""); help.target = self; menu.addItem(help)
        let quit = NSMenuItem(title: String(localized: "Quit Spray Can"), action: #selector(quitAction), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        item.menu = menu
    }
    private static let thisAppTag = 77
    /// Opening a menu-bar menu leaves the app in use frontmost, so this names the app being worked in.
    private func updateThisApp(_ item: NSMenuItem) {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid(), let id = app.bundleIdentifier else {
            item.isHidden = true; return
        }
        let settings = controller.settings
        let name = app.localizedName ?? id
        let profile = settings.appProfiles[id] ?? AppProfile(name: name)
        item.isHidden = false
        item.title = String(localized: "This App: \(name)")
        let submenu = NSMenu()
        submenu.addItem(NSMenuItem.sectionHeader(title: String(localized: "Text recognition")))
        let choices: [(AppOverride, String)] = [(.inherit, settings.vision ? String(localized: "Same as General (On)") : String(localized: "Same as General (Off)")),
                                               (.on, String(localized: "On")), (.off, String(localized: "Off"))]
        for (choice, title) in choices {
            let entry = NSMenuItem(title: title, action: #selector(setTextRecognition(_:)), keyEquivalent: "")
            entry.target = self; entry.representedObject = [id, name, choice.rawValue]; entry.state = profile.ocr == choice ? .on : .off
            submenu.addItem(entry)
        }
        submenu.addItem(.separator())
        let extended = NSMenuItem(title: String(localized: "Extended scan time"), action: #selector(toggleScanTime(_:)), keyEquivalent: "")
        extended.target = self; extended.representedObject = [id, name]; extended.state = profile.scanTime == .extended ? .on : .off
        submenu.addItem(extended)
        submenu.addItem(.separator())
        let more = NSMenuItem(title: String(localized: "App Settings…"), action: #selector(appSettingsAction), keyEquivalent: ""); more.target = self
        submenu.addItem(more)
        item.submenu = submenu
    }
    @objc private func setTextRecognition(_ sender: NSMenuItem) {
        guard let values = sender.representedObject as? [String], values.count == 3, let choice = AppOverride(rawValue: values[2]) else { return }
        controller.settings.updateProfile(values[0], name: values[1]) { $0.ocr = choice }
    }
    @objc private func toggleScanTime(_ sender: NSMenuItem) {
        guard let values = sender.representedObject as? [String], values.count == 2 else { return }
        controller.settings.updateProfile(values[0], name: values[1]) { $0.scanTime = $0.scanTime == .extended ? .normal : .extended }
    }
    @objc private func appSettingsAction() { showSettings(); controller.requestedTab = "Apps" }
    func menuWillOpen(_ menu: NSMenu) {
        if let thisApp = menu.item(withTag: Self.thisAppTag) { updateThisApp(thisApp) }
        menu.item(at: 1)?.title = controller.status
        for (index, mode) in NavigationMode.allCases.enumerated() {
            menu.item(at: index + 2)?.title = "\(mode.localizedTitle)  \(shortcutTitle(controller.settings.shortcuts[mode]!))"
        }
    }
    @objc private func startMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = NavigationMode(rawValue: raw) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.controller.activate(mode) }
    }
    @objc private func settingsAction() { showSettings() }
    @objc private func helpAction() { NSWorkspace.shared.open(URL(string: "https://github.com/Kymer0615/spray_can/blob/main/docs/SHORTCUTS.md")!) }
    @objc private func quitAction() { NSApp.terminate(nil) }
    func showSettings() {
        controller.cancel()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 696, height: 540), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Spray Can"; window.titlebarAppearsTransparent = true
            window.contentView = NSHostingView(rootView: SettingsView(controller: controller, initialTab: controller.accessibilityGranted ? "General" : "Permissions"))
            window.isReleasedWhenClosed = false; window.center(); settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
