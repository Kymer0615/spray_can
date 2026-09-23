import AppKit

final class FixtureDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    var window: NSWindow!
    var clicks = 0
    var leakedCharacters = 0
    let output = ProcessInfo.processInfo.environment["SPRAYCAN_FIXTURE_STATE"]!
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: CGRect(x: 180, y: 180, width: 640, height: 430), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Spray Can Navigation Test Fixture"
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 640, height: 430))
        let title = NSTextField(labelWithString: "Controlled navigation test — no personal content")
        title.frame = CGRect(x: 30, y: 360, width: 570, height: 30); content.addSubview(title)
        let field = NSTextField(frame: CGRect(x: 30, y: 295, width: 560, height: 32))
        field.placeholderString = "Navigation keys must not enter this field"; field.delegate = self; content.addSubview(field)
        let button = NSButton(title: "Test Click", target: self, action: #selector(clicked))
        button.bezelStyle = .rounded; button.frame = CGRect(x: 40, y: 210, width: 180, height: 44); content.addSubview(button)
        let scroll = NSScrollView(frame: CGRect(x: 280, y: 30, width: 300, height: 220))
        scroll.hasVerticalScroller = true
        let document = NSView(frame: CGRect(x: 0, y: 0, width: 280, height: 1200))
        for i in 0..<20 {
            let row = NSButton(checkboxWithTitle: "Fixture row \(i + 1)", target: nil, action: nil)
            row.frame = CGRect(x: 15, y: i * 55 + 10, width: 220, height: 30); document.addSubview(row)
        }
        scroll.documentView = document; content.addSubview(scroll)
        window.contentView = content; window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true); window.makeFirstResponder(field)
        writeState()
    }
    @objc func clicked() { clicks += 1; writeState() }
    func controlTextDidChange(_ obj: Notification) {
        leakedCharacters += 1; writeState()
    }
    func writeState() {
        let state = ["clicks": clicks, "leakedCharacters": leakedCharacters]
        try? JSONSerialization.data(withJSONObject: state).write(to: URL(fileURLWithPath: output), options: .atomic)
    }
}
let app = NSApplication.shared
let delegate = FixtureDelegate()
app.setActivationPolicy(.regular); app.delegate = delegate
app.run()
