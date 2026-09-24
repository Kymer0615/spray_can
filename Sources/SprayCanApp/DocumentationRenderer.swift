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
                configuration.width = Int(size.width); configuration.height = Int(size.height)
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
            let background = NSHostingView(rootView: DemoDesktop()); background.frame = container.bounds; container.addSubview(background)
            let canvas = HintCanvas(frame: container.bounds); canvas.primaryHeight = 700
            let fixture = [CGRect(x: 70, y: 119, width: 132, height: 32), CGRect(x: 70, y: 157, width: 132, height: 32), CGRect(x: 70, y: 195, width: 132, height: 32), CGRect(x: 280, y: 143, width: 180, height: 160), CGRect(x: 490, y: 143, width: 180, height: 160), CGRect(x: 700, y: 143, width: 180, height: 160), CGRect(x: 795, y: 96, width: 220, height: 34)]
            canvas.targets = HintLabels.assign(grid ? Geometry.grid(screens: [container.bounds], cellSize: 100) : fixture.enumerated().map { Target(id: "demo-\($0.offset)", frame: $0.element, source: .accessibility) })
            container.addSubview(canvas)
            let hud = NSHostingView(rootView: NavigationHUD(mode: grid ? .grid : .elements, status: "\(canvas.targets.count) targets · Type a label · Return clicks", prefix: ""))
            hud.frame = CGRect(x: 330, y: 20, width: 440, height: 76); container.addSubview(hud)
            let initial = save(container, name: grid ? "grid.png" : "elements.png", size: container.bounds.size)
            let targets = canvas.targets
            let destination = targets[grid ? min(26, targets.count - 1) : 3]
            var frames: [CGImage] = initial.map { [$0] } ?? []
            let steps: [(String, CGRect?)] = grid ? [
                ("⇧⌘K · Type " + targets[3].label.uppercased(), targets[3].frame),
                ("= · Hold the left mouse button", targets[3].frame),
                ("Type " + destination.label.uppercased() + " · Move while dragging", destination.frame),
                ("Return · Drop", destination.frame)
            ] : [
                ("⇧⌘J · Show element labels", nil),
                ("Type " + destination.label.uppercased() + " · Move to Projects", destination.frame),
                ("Return · Click", destination.frame)
            ]
            for (message, selection) in steps {
                canvas.selected = selection; canvas.needsDisplay = true
                hud.rootView = NavigationHUD(mode: grid ? .grid : .elements, status: message, prefix: "")
                if let frame = save(container, name: "", size: container.bounds.size) { frames.append(frame) }
            }
            let url = URL(fileURLWithPath: directory).appendingPathComponent(grid ? "drag-demo.gif" : "element-demo.gif")
            if let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) {
                CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
                for frame in frames { CGImageDestinationAddImage(destination, frame, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.4]] as CFDictionary) }
                CGImageDestinationFinalize(destination)
            }
        }
    }
}
private struct DemoDesktop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.24, blue: 0.28), Color(red: 0.15, green: 0.47, blue: 0.49), Color(red: 0.60, green: 0.74, blue: 0.69)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 0) {
                HStack { Image(systemName: "apple.logo"); Text("Finder").bold(); Text("File   Edit   View   Go   Window   Help"); Spacer(); Text("Spray Can demo") }.font(.system(size: 13)).padding(.horizontal, 20).frame(height: 28).background(.ultraThinMaterial)
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("FAVORITES").font(.caption).foregroundStyle(.secondary)
                        Label("Recents", systemImage: "clock")
                        Label("Documents", systemImage: "doc")
                        Label("Downloads", systemImage: "arrow.down.circle")
                        Spacer()
                    }.padding(24).frame(width: 205).background(.thinMaterial)
                    VStack(alignment: .leading, spacing: 35) {
                        HStack { Text("Documents").font(.title2.bold()); Spacer(); Label("Search", systemImage: "magnifyingglass").foregroundStyle(.secondary).frame(width: 200, alignment: .leading).padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 8)) }
                        HStack(spacing: 45) { folder("Projects"); folder("Research"); folder("Personal") }
                        Spacer()
                        Text("Example workspace · No personal files shown").font(.caption).foregroundStyle(.secondary)
                    }.padding(30).frame(maxWidth: .infinity).background(Color(nsColor: .windowBackgroundColor))
                }.frame(height: 460).clipShape(RoundedRectangle(cornerRadius: 14)).shadow(color: .black.opacity(0.2), radius: 25, y: 15).padding(40)
                Spacer()
            }
        }.frame(width: 1100, height: 700)
    }
    func folder(_ title: String) -> some View { VStack(spacing: 14) { Image(systemName: "folder.fill").font(.system(size: 84)).foregroundStyle(.cyan.gradient); Text(title).font(.system(size: 14)) }.frame(width: 160, height: 160) }
}
