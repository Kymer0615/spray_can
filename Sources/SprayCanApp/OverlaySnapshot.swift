import AppKit
import ScreenCaptureKit
import SprayCanCore

/// Debug readability check: real discovery of one app's focused window, labels drawn over a
/// capture of that window, saved as a PNG. Run from a terminal that has Accessibility and
/// Screen Recording access: `SprayCan --render-overlay --app <bundle id> --out <png> [--prefix ab] [--ocr]`.
final class OverlaySnapshot {
    private let accessibility = AccessibilityProvider()
    private let ocr = OCRProvider()
    private let arguments = ProcessInfo.processInfo.arguments
    private func value(_ flag: String) -> String? {
        arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
    }
    func run() {
        guard let bundle = value("--app"), let output = value("--out"),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first else {
            finish("Usage: --render-overlay --app <running bundle id> --out <png> [--prefix ab] [--ocr]"); return
        }
        guard AXIsProcessTrusted() else { finish("Accessibility is required for the terminal running this command."); return }
        app.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.scan(app, output: output) }
    }
    private func scan(_ app: NSRunningApplication, output: String, attempt: Int = 1) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let screens = NSScreen.screens.map { Geometry.cocoa($0.frame, primaryHeight: primaryHeight) }
        let context = DiscoveryContext(pid: app.processIdentifier, screens: screens, allWindows: false, generation: 1)
        accessibility.discover(context) { result in
            // Right after activation the app may not report its focused window yet.
            guard let window = result.captureRects.first, !result.targets.isEmpty else {
                if attempt < 4 { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.scan(app, output: output, attempt: attempt + 1) } }
                else { self.finish("No focused window found.") }
                return
            }
            if self.arguments.contains("--dump") { for t in result.targets { print("TARGET", t.role, Int(t.frame.minX), Int(t.frame.minY), Int(t.frame.width), Int(t.frame.height), t.title) } }
            // Same inputs as a live session: detected text plus icons, unless --no-detect.
            self.ocr.detectText(in: self.arguments.contains("--no-detect") ? .zero : window) { rects in
                let content = HintLayout.textContent(detected: rects ?? [], exposed: result.texts)
                print("Content rects: \(content.count)")
                if self.arguments.contains("--dump") { for r in content { print("TEXT", Int(r.minX), Int(r.minY), Int(r.width), Int(r.height)) }; for r in result.icons { print("ICON", Int(r.minX), Int(r.minY), Int(r.width), Int(r.height)) } }
                let draw: ([Target]) -> Void = { targets in self.capture(window: window, targets: targets, content: content, icons: result.icons, output: output) }
                guard self.arguments.contains("--ocr") else { draw(result.targets); return }
                OCRProvider().discover(screens: screens, regions: [window], languages: Settings.shared.ocrLanguages) { text, error in
                    if let error { print(error) }
                    draw(Settings.shared.dedupeOCR ? Geometry.mergeText(result.targets, text) : Geometry.merge(result.targets, text))
                }
            }
        }
    }
    private func capture(window: CGRect, targets: [Target], content: [CGRect], icons: [CGRect], output: String) {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { shareable, _ in
            guard let display = OCRProvider.mainDisplay(for: window, in: shareable?.displays ?? []) else {
                DispatchQueue.main.async { self.finish("Screen Recording is required for the terminal running this command.") }; return
            }
            let bounds = CGDisplayBounds(display.displayID)
            let own = shareable?.applications.filter { $0.processID == getpid() } ?? []
            let configuration = SCStreamConfiguration()
            configuration.width = Int(bounds.width) * 2; configuration.height = Int(bounds.height) * 2
            configuration.showsCursor = false
            SCScreenshotManager.captureImage(contentFilter: SCContentFilter(display: display, excludingApplications: own, exceptingWindows: []), configuration: configuration) { image, _ in
                DispatchQueue.main.async {
                    guard let image else { self.finish("Capture failed."); return }
                    self.compose(image, display: bounds, window: window, targets: targets, content: content, icons: icons, output: output)
                }
            }
        }
    }
    private func compose(_ image: CGImage, display: CGRect, window: CGRect, targets: [Target], content: [CGRect], icons: [CGRect], output: String) {
        // Draw in a canvas covering just the window, in its own coordinates.
        let area = window.intersection(display)
        let view = NSView(frame: CGRect(origin: .zero, size: area.size))
        let scale = CGFloat(image.width) / display.width
        let crop = CGRect(x: (area.minX - display.minX) * scale, y: (area.minY - display.minY) * scale, width: area.width * scale, height: area.height * scale)
        guard let cropped = image.cropping(to: crop) else { finish("Crop failed."); return }
        let background = NSImageView(frame: view.bounds)
        background.image = NSImage(cgImage: cropped, size: area.size); background.imageScaling = .scaleAxesIndependently
        view.addSubview(background)
        let canvas = HintCanvas(frame: view.bounds)
        // HintCanvas converts global Quartz rects with these; map the window's top-left to the view origin.
        canvas.primaryHeight = area.maxY; canvas.screenOrigin = CGPoint(x: area.minX, y: 0)
        let settings = Settings.shared
        let glass = settings.glassEnabled, shading = settings.elementShading, opacity = settings.shadingOpacity
        settings.glassEnabled = false
        // One-run overrides: --shading off|whileTyping|always, --shading-opacity 0.3.
        if let mode = value("--shading").flatMap(ElementShading.init(rawValue:)) { settings.elementShading = mode }
        if let level = value("--shading-opacity").flatMap(Double.init) { settings.shadingOpacity = level }
        let scheme = settings.colorScheme
        if let id = value("--color-scheme") { settings.colorScheme = LabelColorScheme.named(id) }
        defer { settings.colorScheme = scheme }
        defer { settings.glassEnabled = glass; settings.elementShading = shading; settings.shadingOpacity = opacity }
        canvas.targets = HintLabels.assign(targets, vi: settings.vi)
        canvas.prefix = value("--prefix") ?? ""
        canvas.content = content; canvas.icons = icons
        view.addSubview(canvas)
        view.layoutSubtreeIfNeeded(); canvas.layoutSubtreeIfNeeded()
        // An offscreen window lets SwiftUI badges render into the cached bitmap.
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { finish("Render failed."); return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { finish("Encode failed."); return }
        do { try data.write(to: URL(fileURLWithPath: output)) } catch { finish("Write failed: \(error.localizedDescription)"); return }
        print(canvas.snapshotSummary)
        finish("Saved \(output)")
    }
    private func finish(_ message: String) { print(message); NSApp.terminate(nil) }
}
