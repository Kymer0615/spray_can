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
    private var settingsWindow: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.toolTip = "Spray Can — keyboard navigation"
        controller.stateChanged = { [weak self] in self?.updateIcon(); self?.rebuildMenu() }
        controller.openSettings = { [weak self] in self?.showSettings() }
        updateIcon(); rebuildMenu()
        if ProcessInfo.processInfo.arguments.contains("--render-docs") { DocumentationRenderer.render(); NSApp.terminate(nil); return }
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
    func applicationWillTerminate(_ notification: Notification) { controller.cancel() }
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
            let entry = NSMenuItem(title: "\(mode.title)  \(shortcutTitle(controller.settings.shortcuts[mode]!))", action: #selector(startMode(_:)), keyEquivalent: "")
            entry.representedObject = mode.rawValue; entry.target = self; menu.addItem(entry)
        }
        menu.addItem(.separator())
        let preferences = NSMenuItem(title: "Settings…", action: #selector(settingsAction), keyEquivalent: ","); preferences.target = self; menu.addItem(preferences)
        let help = NSMenuItem(title: "Help & Shortcuts", action: #selector(helpAction), keyEquivalent: ""); help.target = self; menu.addItem(help)
        let quit = NSMenuItem(title: "Quit Spray Can", action: #selector(quitAction), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
        item.menu = menu
    }
    func menuWillOpen(_ menu: NSMenu) {
        menu.item(at: 1)?.title = controller.status
        for (index, mode) in NavigationMode.allCases.enumerated() {
            menu.item(at: index + 2)?.title = "\(mode.title)  \(shortcutTitle(controller.settings.shortcuts[mode]!))"
        }
    }
    @objc private func startMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = NavigationMode(rawValue: raw) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.controller.activate(mode) }
    }
    @objc private func settingsAction() { showSettings() }
    @objc private func helpAction() { NSWorkspace.shared.open(URL(string: "https://github.com/Kymer0615/spray_can#shortcuts")!) }
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
