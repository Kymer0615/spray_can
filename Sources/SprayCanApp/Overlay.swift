import AppKit
import SwiftUI
import Combine
import SprayCanCore

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class OverlayManager {
    private var panels: [OverlayPanel] = []
    private var views: [HintCanvas] = []
    private var hud: OverlayPanel?
    var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }
    var quartzScreens: [CGRect] { NSScreen.screens.map { Geometry.cocoa($0.frame, primaryHeight: primaryHeight) } }
    func rebuild() { hide(); panels = []; views = [] }
    private func prepare() {
        guard panels.isEmpty else { return }
        for screen in NSScreen.screens {
            let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
            panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            let view = HintCanvas(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.screenOrigin = screen.frame.origin; view.primaryHeight = primaryHeight
            panel.contentView = view; panels.append(panel); views.append(view)
        }
    }
    func render(targets: [Target], prefix: String, mode: NavigationMode, status: String, selected: CGRect? = nil) {
        prepare()
        for (panel, view) in zip(panels, views) {
            view.targets = targets; view.prefix = prefix; view.selected = selected
            view.needsDisplay = true; panel.orderFrontRegardless()
        }
        showHUD(mode: mode, status: status, prefix: prefix)
    }
    func showHUD(mode: NavigationMode, status: String, prefix: String = "") {
        if hud == nil {
            let panel = OverlayPanel(contentRect: CGRect(x: 0, y: 0, width: 440, height: 76), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
            panel.level = .screenSaver; panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            hud = panel
        }
        guard let hud, let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        hud.contentView = NSHostingView(rootView: NavigationHUD(mode: mode, status: status, prefix: prefix))
        hud.setFrameOrigin(CGPoint(x: screen.visibleFrame.midX - 220, y: screen.visibleFrame.minY + 24))
        hud.orderFrontRegardless()
    }
    func hide() { panels.forEach { $0.orderOut(nil) }; hud?.orderOut(nil) }
}

struct GlassSurface: ViewModifier {
    @ObservedObject private var settings = Settings.shared
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency || !settings.glassEnabled {
            content.background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 22))
        } else if #available(macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 22))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.3)))
        }
    }
}
struct NavigationHUD: View {
    let mode: NavigationMode
    let status: String
    let prefix: String
    var body: some View {
        HStack(spacing: 12) {
            SprayCanMark().stroke(.primary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)).frame(width: 22, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text("Spray Can · \(mode.title)").font(.system(size: 13, weight: .semibold))
                Text(status).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(prefix.isEmpty ? "esc" : prefix.uppercased()).font(.system(size: 12, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 5).background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
        }.padding(.horizontal, 18).padding(.vertical, 14).modifier(GlassSurface()).padding(6)
    }
}

struct SprayCanMark: Shape {
    func path(in r: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        var path = Path()
        path.addRoundedRect(in: CGRect(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.28, width: r.width * 0.60, height: r.height * 0.68), cornerSize: CGSize(width: r.width * 0.12, height: r.width * 0.12))
        path.move(to: p(0.31, 0.28)); path.addLine(to: p(0.31, 0.18)); path.addLine(to: p(0.69, 0.18)); path.addLine(to: p(0.69, 0.28))
        path.move(to: p(0.4, 0.18)); path.addLine(to: p(0.4, 0.04)); path.addLine(to: p(0.65, 0.04)); path.addLine(to: p(0.65, 0.18))
        path.move(to: p(0.2, 0.43)); path.addLine(to: p(0.8, 0.43))
        path.move(to: p(0.2, 0.79)); path.addLine(to: p(0.8, 0.79))
        path.move(to: p(0.76, 0.10)); path.addLine(to: p(0.98, 0.06))
        return path
    }
}

struct HintBackground: View {
    @ObservedObject private var settings = Settings.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let ocr: Bool
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 5) }
    var body: some View {
        let tint = settings.color(ocr ? .ocr : .label)
        if reduceTransparency { shape.fill(tint) }
        else { surface(tint: tint).opacity(settings.glassEnabled ? 1 : settings.contrast) }
    }
    @ViewBuilder private func surface(tint: Color) -> some View {
        if !settings.glassEnabled { shape.fill(tint) }
        else if #available(macOS 26, *) {
            shape.fill(.clear).glassEffect(.regular.tint(tint), in: shape)
                .overlay(shape.stroke(tint, lineWidth: 1))
        } else {
            shape.fill(tint.opacity(0.6)).background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.3), lineWidth: 0.75))
        }
    }
}

private struct PlacedHint: Identifiable {
    let id: String
    let target: Target
    let frame: CGRect
}
private struct HintLayer: View {
    let hints: [PlacedHint]
    let prefix: String
    let height: CGFloat
    private var badges: some View {
        ZStack(alignment: .topLeading) {
            ForEach(hints) { hint in
                HintBackground(ocr: hint.target.source == .text)
                    .frame(width: hint.frame.width, height: hint.frame.height)
                    .position(x: hint.frame.midX, y: height - hint.frame.midY)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    var body: some View {
        Group {
            if #available(macOS 26, *) {
                GlassEffectContainer(spacing: 0) { badges }
            } else { badges }
        }.environment(\.controlActiveState, .active).allowsHitTesting(false)
    }
}

/// Keep glyphs outside SwiftUI's glass container and above every material layer.
private final class HintTextCanvas: NSView {
    var hints: [PlacedHint] = []
    var prefix = ""
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        let settings = Settings.shared
        let font = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .semibold)
        for hint in hints {
            let string = hint.target.label.uppercased()
            let text = NSMutableAttributedString(string: string, attributes: [.font: font, .foregroundColor: settings.nsColor(.text)])
            let matched = min((prefix.uppercased() as NSString).length, text.length)
            if matched > 0 { text.addAttribute(.foregroundColor, value: settings.nsColor(.highlight), range: NSRange(location: 0, length: matched)) }
            let size = text.size()
            text.draw(at: CGPoint(x: hint.frame.midX - size.width / 2, y: hint.frame.midY - size.height / 2))
        }
    }
}

struct AppearancePreview: NSViewRepresentable {
    func makeNSView(context: Context) -> HintCanvas {
        let canvas = HintCanvas()
        canvas.preview = true
        return canvas
    }
    func updateNSView(_ view: HintCanvas, context: Context) { view.needsLayout = true }
}

final class HintCanvas: NSView {
    var targets: [Target] = [] { didSet { if !preparingPreview { needsLayout = true; needsDisplay = true } } }
    var prefix = "" { didSet { if !preparingPreview { needsLayout = true } } }
    var selected: CGRect? { didSet { needsDisplay = true } }
    var screenOrigin = CGPoint.zero
    var primaryHeight: CGFloat = 0
    var preview = false
    private var preparingPreview = false
    private var placed: [PlacedHint] = []
    private var layoutItems: [HintLayoutItem] = []
    private var layoutBounds = CGRect.zero
    private var placements: [HintPlacement] = []
    private var appearanceChanges: AnyCancellable?
    private var accessibilityChanges: NSObjectProtocol?
    private let letters = HintTextCanvas()
    private let badges = NSHostingView(rootView: HintLayer(hints: [], prefix: "", height: 0))
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        addSubview(badges)
        letters.wantsLayer = true
        addSubview(letters, positioned: .above, relativeTo: badges)
        letters.layer?.zPosition = 1
        appearanceChanges = Settings.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.needsLayout = true; self?.needsDisplay = true }
        }
        accessibilityChanges = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.needsLayout = true; self?.needsDisplay = true
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    deinit { if let accessibilityChanges { NSWorkspace.shared.notificationCenter.removeObserver(accessibilityChanges) } }
    override var isFlipped: Bool { false }
    private func local(_ rect: CGRect) -> CGRect {
        Geometry.cocoa(rect, primaryHeight: primaryHeight).offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y)
    }
    override func layout() {
        super.layout()
        if preview {
            preparingPreview = true
            defer { preparingPreview = false }
            primaryHeight = bounds.height
            targets = (0..<6).map { index in
                let vertical = index < 3
                let x = vertical ? bounds.width * 0.2 : bounds.width * 0.67 + CGFloat(index - 3) * 18
                let y = vertical ? bounds.height / 2 - 14 + CGFloat(index) * 14 : bounds.height / 2
                return Target(id: "preview-\(index)", frame: CGRect(x: x - 5, y: y - 5, width: 10, height: 10), source: index == 1 ? .text : .accessibility, label: ["ab", "ac", "ad", "ae", "af", "ag"][index])
            }
            prefix = "a"
        }
        let settings = Settings.shared
        let font = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .semibold)
        let visible = TargetCollection.unique(targets).filter { bounds.contains(CGPoint(x: local($0.frame).midX, y: local($0.frame).midY)) }
        let items = visible.map { target in
            let size = (target.label.uppercased() as NSString).size(withAttributes: [.font: font])
            return HintLayoutItem(id: target.id, target: local(target.frame), size: CGSize(width: size.width + 12, height: size.height + 6), fixed: target.source == .grid)
        }
        if items != layoutItems || bounds != layoutBounds {
            layoutItems = items; layoutBounds = bounds
            placements = HintLayout.place(items, in: bounds)
        }
        let frames = Dictionary(placements.map { ($0.id, $0.frame) }, uniquingKeysWith: { first, _ in first })
        placed = visible.compactMap { target in
            guard settings.showLabels, target.label.hasPrefix(prefix), let frame = frames[target.id] else { return nil }
            return PlacedHint(id: target.id, target: target, frame: frame)
        }
        letters.frame = bounds
        letters.hints = placed; letters.prefix = prefix; letters.needsDisplay = true
        badges.frame = bounds
        badges.rootView = HintLayer(hints: placed, prefix: prefix, height: bounds.height)
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        let settings = Settings.shared
        if preview {
            for target in targets {
                NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
                let control = NSBezierPath(roundedRect: local(target.frame), xRadius: 2, yRadius: 2)
                control.lineWidth = 1; control.stroke()
            }
        }
        for target in targets where target.source == .grid && settings.showLines {
            settings.nsColor(.grid).withAlphaComponent(0.45).setStroke()
            let border = NSBezierPath(rect: local(target.frame)); border.lineWidth = 0.5; border.stroke()
        }
        let shown = Set(placed.map(\.id))
        for hint in placements where shown.contains(hint.id) && hint.displaced {
            settings.nsColor(.grid).withAlphaComponent(0.8).setStroke()
            let line = NSBezierPath(); line.move(to: hint.connectorStart); line.line(to: hint.anchor)
            line.lineWidth = 1; line.stroke()
            settings.nsColor(.grid).setFill()
            NSBezierPath(ovalIn: CGRect(x: hint.anchor.x - 2, y: hint.anchor.y - 2, width: 4, height: 4)).fill()
        }
        if let selected {
            settings.nsColor(.highlight).setStroke()
            let ring = NSBezierPath(roundedRect: local(selected).insetBy(dx: -4, dy: -4), xRadius: 7, yRadius: 7)
            ring.lineWidth = 2; ring.stroke()
        }
    }
}
