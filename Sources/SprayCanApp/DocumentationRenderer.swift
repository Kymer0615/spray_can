import AppKit
import SwiftUI
import SprayCanCore
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

/// Reproducible documentation images of real application views, using synthetic example data.
/// Captures only synthetic documentation windows; requires Screen Recording for native glass compositing.
enum DocumentationRenderer {
    static func render() {
        let directory = ProcessInfo.processInfo.environment["SPRAYCAN_DOCS_DIR"] ?? "docs/images"
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        @discardableResult func save(_ view: NSView, name: String, size: CGSize) -> CGImage? {
            let window = OverlayPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.contentView = view; view.frame = CGRect(origin: .zero, size: size)
            window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            // Glass is composited by WindowServer and is absent from cacheDisplay bitmaps.
            // Capture only this synthetic window, never the desktop or another app.
            var captured: CGImage?
            var finished = false
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
                guard let target = content?.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else {
                    DispatchQueue.main.async { finished = true }; return
                }
                let filter = SCContentFilter(desktopIndependentWindow: target)
                let configuration = SCStreamConfiguration()
                // Native display scale (2× on Retina), so README images stay sharp.
                let scale = window.backingScaleFactor
                configuration.width = Int(size.width * scale); configuration.height = Int(size.height * scale)
                configuration.showsCursor = false
                configuration.ignoreShadowsSingleWindow = true
                SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                    DispatchQueue.main.async { captured = image; finished = true }
                }
            }
            let deadline = Date().addingTimeInterval(15)
            while !finished && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            window.orderOut(nil)
            guard let captured else { print("Could not render \(name): Screen Recording permission is required for composited documentation visuals."); return nil }
            if !name.isEmpty {
                let bitmap = NSBitmapImageRep(cgImage: captured)
                if let data = bitmap.representation(using: .png, properties: [:]) { try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name)) }
            }
            return captured
        }
        if ProcessInfo.processInfo.environment["SPRAYCAN_OPACITY_CHECK_ONLY"] == "1" {
            let settings = Settings.shared
            let original = settings.contrast
            let originalGlass = settings.glassEnabled
            defer { settings.contrast = original; settings.glassEnabled = originalGlass }
            for glass in [true, false] {
              settings.glassEnabled = glass
              precondition(Settings().glassEnabled == glass, "Glass preference did not persist")
              for opacity in [0.4, 1.0] {
                settings.contrast = opacity
                precondition(Settings().contrast == opacity, "Opacity did not persist")
                let sample = NSView(frame: CGRect(x: 0, y: 0, width: 300, height: 120))
                let backdrop = NSHostingView(rootView: LinearGradient(colors: [.blue, .orange], startPoint: .leading, endPoint: .trailing))
                backdrop.frame = sample.bounds; sample.addSubview(backdrop)
                let hints = HintCanvas(frame: sample.bounds); hints.primaryHeight = 120
                hints.targets = [Target(id: "sample", frame: CGRect(x: 145, y: 55, width: 10, height: 10), source: .accessibility, label: "ab")]
                hints.prefix = "a"; sample.addSubview(hints)
                save(sample, name: "opacity-\(glass ? "glass" : "plain")-\(Int(opacity * 100)).png", size: CGSize(width: 300, height: 120))
              }
            }
            save(NSHostingView(rootView: SettingsView(controller: AppController(), initialTab: "Appearance")), name: "appearance.png", size: CGSize(width: 696, height: 540))
            return
        }
        save(NSHostingView(rootView: SettingsView(controller: AppController())), name: "settings.png", size: CGSize(width: 696, height: 540))
        save(NSHostingView(rootView: SettingsView(controller: AppController(), initialTab: "Appearance")), name: "appearance.png", size: CGSize(width: 696, height: 540))
        save(NSHostingView(rootView: SettingsView(controller: AppController(), initialTab: "About")), name: "about.png", size: CGSize(width: 696, height: 540))
        save(NSHostingView(rootView: AppearancePreview().frame(width: 600, height: 160).background(Color(nsColor: .windowBackgroundColor))), name: "clustered-labels.png", size: CGSize(width: 600, height: 160))
        for grid in [false, true] {
            let container = NSView(frame: CGRect(x: 0, y: 0, width: 1100, height: 700))
            let scene = DemoWindow(frame: container.bounds); container.addSubview(scene)
            let canvas = HintCanvas(frame: container.bounds); canvas.primaryHeight = 700
            if !grid { canvas.content = scene.texts; canvas.icons = scene.icons }
            canvas.targets = HintLabels.assign(grid ? Geometry.grid(screens: [container.bounds], cellSize: 100) : TargetCollection.collapsed(scene.targets))
            container.addSubview(canvas)
            let hud = NSHostingView(rootView: NavigationHUD(mode: grid ? .grid : .elements, status: "\(canvas.targets.count) targets · Type a label · Return clicks", prefix: ""))
            hud.frame = CGRect(x: 330, y: 0, width: 440, height: 76); container.addSubview(hud)
            let initial = save(container, name: grid ? "grid.png" : "elements.png", size: container.bounds.size)
            let targets = canvas.targets
            // A destination whose first letter leaves only a few matches, to show filtering.
            let destination = grid ? targets[min(26, targets.count - 1)] : targets.first { $0.label.hasPrefix("s") && $0.title.hasSuffix(".sketch") } ?? targets[3]
            var frames: [CGImage] = initial.map { [$0] } ?? []
            if !grid, let before = initial {
                // Before and after typing the first letter: badges and shading, then only the matches, outlined.
                canvas.prefix = String(destination.label.prefix(1)); canvas.needsLayout = true
                hud.rootView = NavigationHUD(mode: .elements, status: "Type " + destination.label.prefix(1).uppercased(), prefix: canvas.prefix)
                if let after = save(container, name: "", size: container.bounds.size) {
                    frames.append(after)
                    // The demo window plus room for labels just above its toolbar.
                    let scale = CGFloat(after.width) / container.bounds.width
                    let window = CGRect(x: 30, y: 30, width: 1040, height: 520)
                    let area = CGRect(x: window.minX * scale, y: window.minY * scale, width: window.width * scale, height: window.height * scale)
                    if let left = before.cropping(to: area), let right = after.cropping(to: area),
                       let context = CGContext(data: nil, width: left.width * 2 + Int(24 * scale), height: left.height, bitsPerComponent: 8, bytesPerRow: 0,
                                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                        context.setFillColor(CGColor(gray: 1, alpha: 0)); context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
                        context.draw(left, in: CGRect(x: 0, y: 0, width: left.width, height: left.height))
                        context.draw(right, in: CGRect(x: left.width + Int(24 * scale), y: 0, width: right.width, height: right.height))
                        if let image = context.makeImage(), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                            try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("color-coding.png"))
                        }
                    }
                }
                canvas.prefix = ""; canvas.needsLayout = true
            }
            let steps: [(String, CGRect?, String)] = grid ? [
                ("⇧⌘K · Type " + targets[3].label.uppercased(), targets[3].frame, ""),
                ("Space · Hold the left mouse button", targets[3].frame, ""),
                ("Type " + destination.label.uppercased() + " · Drag there", destination.frame, ""),
                ("Space · Drop", destination.frame, "")
            ] : [
                ("Type " + destination.label.uppercased() + " · Move to " + destination.title, destination.frame, ""),
                ("Return · Click", destination.frame, "")
            ]
            for (message, selection, prefix) in steps {
                canvas.selected = selection; canvas.prefix = prefix; canvas.needsDisplay = true
                hud.rootView = NavigationHUD(mode: grid ? .grid : .elements, status: message, prefix: prefix)
                if let frame = save(container, name: "", size: container.bounds.size) { frames.append(frame) }
            }
            writeGIF(frames, name: grid ? "drag-demo.gif" : "element-demo.gif")
        }
        // Keyboard screenshots: ⇧⌘4, then grid labels and Space to drag the selection.
        let container = NSView(frame: CGRect(x: 0, y: 0, width: 1100, height: 700))
        let scene = DemoWindow(frame: container.bounds); container.addSubview(scene)
        let canvas = HintCanvas(frame: container.bounds); canvas.primaryHeight = 700
        container.addSubview(canvas)
        let screenshot = ScreenshotOverlay(frame: container.bounds); container.addSubview(screenshot)
        let hud = NSHostingView(rootView: NavigationHUD(mode: .grid, status: "", prefix: ""))
        hud.frame = CGRect(x: 330, y: 0, width: 440, height: 76); container.addSubview(hud)
        let cells = HintLabels.assign(Geometry.grid(screens: [container.bounds], cellSize: 100))
        let start = cells.first { $0.frame.contains(CGPoint(x: 210, y: 120)) }!, end = cells.first { $0.frame.contains(CGPoint(x: 1010, y: 430)) }!
        let selection = CGRect(x: start.point.x, y: start.point.y, width: end.point.x - start.point.x, height: end.point.y - start.point.y)
        screenshot.snapshot = { rect in
            guard let rep = scene.bitmapImageRepForCachingDisplay(in: rect) else { return nil }
            scene.cacheDisplay(in: rect, to: rep); let image = NSImage(size: rect.size); image.addRepresentation(rep); return image
        }
        let steps: [(String, [Target], CGRect?, CGPoint?, CGRect?, Bool)] = [
            ("⇧⌘4 · Start a screenshot", [], nil, CGPoint(x: 550, y: 330), nil, false),
            ("⇧⌘K · Type " + start.label.uppercased() + " · Move to one corner", cells, start.frame, start.point, nil, false),
            ("Space · Hold to start the selection", cells, start.frame, start.point, CGRect(origin: start.point, size: .zero), false),
            ("Type " + end.label.uppercased() + " · Drag to the other corner", cells, end.frame, end.point, selection, false),
            ("Space · Release · Screenshot taken", [], nil, nil, nil, true),
        ]
        var frames: [CGImage] = []
        for (message, targets, selected, crosshair, region, taken) in steps {
            canvas.targets = targets; canvas.selected = selected; canvas.needsLayout = true
            screenshot.crosshair = crosshair; screenshot.selection = region; screenshot.thumbnail = taken ? selection : nil
            screenshot.needsDisplay = true
            hud.rootView = NavigationHUD(mode: .grid, status: message, prefix: "")
            if let frame = save(container, name: "", size: container.bounds.size) { frames.append(frame) }
        }
        writeGIF(frames, name: "screenshot-demo.gif")
        func writeGIF(_ frames: [CGImage], name: String) {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(name)
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { return }
            CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
            for frame in frames { CGImageDestinationAddImage(destination, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.6]] as CFDictionary) }
            CGImageDestinationFinalize(destination)
        }
    }
}

/// An illustration of the macOS screenshot selection (⇧⌘4) for documentation: crosshair, dimmed
/// surroundings, the selected region with its size, and the thumbnail shown after capture.
final class ScreenshotOverlay: NSView {
    var crosshair: CGPoint?
    var selection: CGRect?
    var thumbnail: CGRect?
    var snapshot: ((CGRect) -> NSImage?)?
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        if let selection, selection.width > 0 {
            let dim = NSBezierPath(rect: bounds); dim.append(NSBezierPath(rect: selection)); dim.windingRule = .evenOdd
            NSColor.black.withAlphaComponent(0.28).setFill(); dim.fill()
            NSColor.white.setStroke(); let border = NSBezierPath(rect: selection.insetBy(dx: 0.5, dy: 0.5)); border.lineWidth = 1; border.stroke()
        }
        if let point = crosshair {
            NSColor.black.withAlphaComponent(0.75).setStroke()
            let cross = NSBezierPath(); cross.lineWidth = 1.5
            cross.move(to: CGPoint(x: point.x - 11, y: point.y)); cross.line(to: CGPoint(x: point.x + 11, y: point.y))
            cross.move(to: CGPoint(x: point.x, y: point.y - 11)); cross.line(to: CGPoint(x: point.x, y: point.y + 11)); cross.stroke()
            let size = selection.map { "\(Int($0.width)) × \(Int($0.height))" } ?? "\(Int(point.x)) \(Int(point.y))"
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.white]
            let text = NSAttributedString(string: size, attributes: attributes), box = text.size()
            var label = CGRect(x: point.x + 10, y: point.y + 10, width: box.width + 10, height: box.height + 4)
            if label.maxX > bounds.maxX - 6 { label.origin.x = point.x - 10 - label.width }
            NSColor.black.withAlphaComponent(0.6).setFill(); NSBezierPath(roundedRect: label, xRadius: 4, yRadius: 4).fill()
            text.draw(at: CGPoint(x: label.minX + 5, y: label.minY + 2))
        }
        if let thumbnail, let image = snapshot?(thumbnail) {
            let width: CGFloat = 220, frame = CGRect(x: bounds.maxX - width - 28, y: bounds.maxY - width * thumbnail.height / thumbnail.width - 110, width: width, height: width * thumbnail.height / thumbnail.width)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow(); shadow.shadowBlurRadius = 14; shadow.shadowColor = NSColor.black.withAlphaComponent(0.35); shadow.set()
            NSColor.white.setFill(); NSBezierPath(roundedRect: frame.insetBy(dx: -4, dy: -4), xRadius: 8, yRadius: 8).fill()
            NSGraphicsContext.restoreGraphicsState()
            image.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }
}
/// A synthetic Finder-like window for documentation images: example names only, exact geometry,
/// and the targets, text, and icon frames a real scan would report. Coordinates are top-left.
final class DemoWindow: NSView {
    struct Item { let target: Target; let text: CGRect?; let icon: CGRect? }
    private(set) var items: [Item] = []
    private var drawing: [() -> Void] = []
    override var isFlipped: Bool { true }
    var targets: [Target] { items.map(\.target) }
    var texts: [CGRect] { items.compactMap(\.text) + extraTexts }
    var icons: [CGRect] { items.compactMap(\.icon) }
    private var extraTexts: [CGRect] = []
    private let body = NSFont.systemFont(ofSize: 13)
    override init(frame: NSRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    private func measure(_ text: String, _ font: NSFont) -> CGSize { (text as NSString).size(withAttributes: [.font: font]) }
    @discardableResult private func label(_ text: String, at point: CGPoint, font: NSFont? = nil, color: NSColor = .labelColor) -> CGRect {
        let font = font ?? body
        let size = measure(text, font)
        drawing.append { (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color]) }
        return CGRect(origin: point, size: size).insetBy(dx: 0, dy: 2)
    }
    private func symbol(_ name: String, in rect: CGRect, color: NSColor = .secondaryLabelColor) {
        drawing.append {
            guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: rect.height, weight: .regular).applying(.init(paletteColors: [color]))) else { return }
            image.draw(in: rect)
        }
    }
    private func add(_ id: String, _ frame: CGRect, role: String, title: String, text: CGRect? = nil, icon: CGRect? = nil) {
        items.append(Item(target: Target(id: "demo-\(id)", frame: frame, source: .accessibility, title: title, role: role), text: text, icon: icon))
    }
    private func build() {
        let window = CGRect(x: 40, y: 48, width: 1020, height: 600)
        // Toolbar.
        for (index, (name, title)) in [("chevron.left", "Back"), ("chevron.right", "Forward")].enumerated() {
            let frame = CGRect(x: 270 + CGFloat(index) * 32, y: 62, width: 28, height: 28)
            symbol(name, in: frame.insetBy(dx: 7, dy: 6)); add("nav-\(index)", frame, role: kAXButtonRole, title: title, icon: frame.insetBy(dx: 7, dy: 6))
        }
        extraTexts.append(label("Projects", at: CGPoint(x: 350, y: 66), font: .boldSystemFont(ofSize: 15)))
        for (index, (name, title)) in [("list.bullet", "List"), ("square.grid.2x2", "Icons"), ("square.and.arrow.up", "Share"), ("tag", "Tags")].enumerated() {
            let frame = CGRect(x: 700 + CGFloat(index) * 38, y: 62, width: 32, height: 28)
            symbol(name, in: frame.insetBy(dx: 8, dy: 6)); add("tool-\(index)", frame, role: kAXButtonRole, title: title, icon: frame.insetBy(dx: 8, dy: 6))
        }
        let search = CGRect(x: 870, y: 62, width: 170, height: 28)
        drawing.append { NSColor.quaternaryLabelColor.setFill(); NSBezierPath(roundedRect: search, xRadius: 7, yRadius: 7).fill() }
        symbol("magnifyingglass", in: CGRect(x: 878, y: 68, width: 16, height: 16))
        add("search", search, role: kAXTextFieldRole, title: "Search", text: label("Search", at: CGPoint(x: 900, y: 67), color: .secondaryLabelColor), icon: CGRect(x: 878, y: 68, width: 16, height: 16))
        // Sidebar.
        extraTexts.append(label("Favorites", at: CGPoint(x: 58, y: 108), font: .systemFont(ofSize: 11, weight: .semibold), color: .tertiaryLabelColor))
        let places = [("clock", "Recents"), ("folder", "Projects"), ("doc", "Documents"), ("arrow.down.circle", "Downloads"), ("menubar.dock.rectangle", "Desktop"), ("dot.radiowaves.left.and.right", "AirDrop")]
        for (index, (name, title)) in places.enumerated() {
            let row = CGRect(x: 48, y: 126 + CGFloat(index) * 32, width: 194, height: 30)
            if title == "Projects" { drawing.append { NSColor.quaternaryLabelColor.setFill(); NSBezierPath(roundedRect: row, xRadius: 7, yRadius: 7).fill() } }
            let icon = CGRect(x: 60, y: row.minY + 7, width: 16, height: 16)
            symbol(name, in: icon, color: .controlAccentColor)
            add("place-\(index)", row, role: kAXRowRole, title: title, text: label(title, at: CGPoint(x: 86, y: row.minY + 6)), icon: icon)
        }
        extraTexts.append(label("Tags", at: CGPoint(x: 58, y: 330), font: .systemFont(ofSize: 11, weight: .semibold), color: .tertiaryLabelColor))
        for (index, (color, title)) in [(NSColor.systemRed, "Urgent"), (.systemBlue, "Review"), (.systemGreen, "Done")].enumerated() {
            let row = CGRect(x: 48, y: 348 + CGFloat(index) * 32, width: 194, height: 30)
            let dot = CGRect(x: 63, y: row.minY + 10, width: 10, height: 10)
            drawing.append { color.setFill(); NSBezierPath(ovalIn: dot).fill() }
            add("tag-\(index)", row, role: kAXRowRole, title: title, text: label(title, at: CGPoint(x: 86, y: row.minY + 6)), icon: dot)
        }
        // File list.
        let small = NSFont.systemFont(ofSize: 11, weight: .medium)
        for (title, x) in [("Name", 300.0), ("Date Modified", 680.0), ("Size", 960.0)] { extraTexts.append(label(title, at: CGPoint(x: x, y: 108), font: small, color: .secondaryLabelColor)) }
        let files: [(String, Bool, String, String)] = [
            ("Brand Guidelines.pdf", false, "Today at 09:41", "4.2 MB"), ("Client Notes.md", false, "Today at 08:15", "12 KB"),
            ("Design System", true, "Yesterday at 17:02", "--"), ("Interview Transcripts", true, "2 Oct 2026 at 11:20", "--"),
            ("Launch Plan.key", false, "1 Oct 2026 at 16:45", "28.6 MB"), ("Moodboard.png", false, "30 Sep 2026 at 10:05", "3.1 MB"),
            ("Prototype.fig", false, "29 Sep 2026 at 14:30", "9.8 MB"), ("Quarterly Report.pdf", false, "28 Sep 2026 at 09:00", "1.6 MB"),
            ("Research", true, "25 Sep 2026 at 12:12", "--"), ("Roadmap.md", false, "24 Sep 2026 at 18:40", "8 KB"),
            ("Sketches", true, "22 Sep 2026 at 15:55", "--"), ("Team Offsite.jpg", false, "20 Sep 2026 at 13:10", "2.4 MB"),
            ("Wireframes.sketch", false, "18 Sep 2026 at 11:30", "14.2 MB"), ("Workshop Agenda.pages", false, "15 Sep 2026 at 09:25", "640 KB"),
        ]
        for (index, (name, folder, date, size)) in files.enumerated() {
            let row = CGRect(x: 258, y: 128 + CGFloat(index) * 26, width: 790, height: 26)
            if index % 2 == 1 { drawing.append { NSColor.labelColor.withAlphaComponent(0.035).setFill(); row.fill() } }
            if folder {
                let triangle = CGRect(x: 262, y: row.minY + 6, width: 12, height: 14)
                symbol("chevron.right", in: triangle.insetBy(dx: 2, dy: 2))
                add("open-\(index)", triangle, role: "AXDisclosureTriangle", title: "", icon: triangle.insetBy(dx: 2, dy: 2))
            }
            let icon = CGRect(x: 280, y: row.minY + 5, width: 16, height: 16)
            symbol(folder ? "folder.fill" : "doc.fill", in: icon, color: folder ? .systemCyan : .systemGray)
            extraTexts.append(label(date, at: CGPoint(x: 680, y: row.minY + 5), color: .secondaryLabelColor))
            extraTexts.append(label(size, at: CGPoint(x: 960, y: row.minY + 5), color: .secondaryLabelColor))
            add("file-\(index)", row, role: kAXRowRole, title: name, text: label(name, at: CGPoint(x: 302, y: row.minY + 5)), icon: icon)
        }
        let background = { () -> Void in
            let gradient = NSGradient(colors: [NSColor(srgbRed: 0.07, green: 0.24, blue: 0.28, alpha: 1), NSColor(srgbRed: 0.15, green: 0.47, blue: 0.49, alpha: 1), NSColor(srgbRed: 0.6, green: 0.74, blue: 0.69, alpha: 1)])
            gradient?.draw(in: CGRect(x: 0, y: 0, width: 1100, height: 700), angle: -35)
            NSColor.windowBackgroundColor.setFill(); NSBezierPath(roundedRect: window, xRadius: 14, yRadius: 14).fill()
            let sidebar = NSBezierPath(roundedRect: CGRect(x: window.minX, y: window.minY, width: 210, height: window.height), xRadius: 14, yRadius: 14)
            NSColor.underPageBackgroundColor.setFill(); sidebar.fill()
            for (index, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
                color.setFill(); NSBezierPath(ovalIn: CGRect(x: 58 + CGFloat(index) * 20, y: 64, width: 12, height: 12)).fill()
            }
            NSColor.separatorColor.setFill(); CGRect(x: 250, y: 124, width: 810, height: 1).fill()
        }
        drawing.insert(background, at: 0)
    }
    override func draw(_ dirtyRect: NSRect) { drawing.forEach { $0() } }
}
