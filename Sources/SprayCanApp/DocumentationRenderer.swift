import AppKit
import SwiftUI
import SprayCanCore
import ImageIO
import UniformTypeIdentifiers

/// Reproducible documentation images of real application views, using synthetic example data.
/// Does not capture the user's desktop or require Screen Recording.
enum DocumentationRenderer {
    static func render() {
        let directory = ProcessInfo.processInfo.environment["SPRAYCAN_DOCS_DIR"] ?? "docs/images"
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        @discardableResult func save(_ view: NSView, name: String, size: CGSize) -> CGImage? {
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = view; view.frame = CGRect(origin: .zero, size: size)
            window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            view.layoutSubtreeIfNeeded()
            view.displayIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            window.orderOut(nil)
            if !name.isEmpty, let data = bitmap.representation(using: .png, properties: [:]) { try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name)) }
            return bitmap.cgImage
        }
        save(NSHostingView(rootView: SettingsView(controller: AppController())), name: "settings.png", size: CGSize(width: 696, height: 540))
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
