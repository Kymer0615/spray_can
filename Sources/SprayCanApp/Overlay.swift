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
    func render(targets: [Target], prefix: String, mode: NavigationMode, status: String, selected: CGRect? = nil, pointer: CGPoint? = nil, content: [CGRect] = [], icons: [CGRect] = []) {
        prepare()
        var avoid: [CGRect] = []
        for (panel, view) in zip(panels, views) {
            view.targets = targets; view.prefix = prefix; view.selected = selected; view.content = content; view.icons = icons
            view.layoutSubtreeIfNeeded(); avoid += view.occupied
            view.needsDisplay = true; panel.orderFrontRegardless()
        }
        if let selected { avoid.append(Geometry.cocoa(selected, primaryHeight: primaryHeight)) }
        let cursor = pointer.map { CGPoint(x: $0.x, y: primaryHeight - $0.y) }
        showHUD(mode: mode, status: status, prefix: prefix, avoid: avoid, pointer: cursor)
    }
    /// `avoid` and `pointer` use global Cocoa coordinates; the card moves to keep them visible.
    func showHUD(mode: NavigationMode, status: String, prefix: String = "", avoid: [CGRect] = [], pointer: CGPoint? = nil) {
        if hud == nil {
            let panel = OverlayPanel(contentRect: CGRect(x: 0, y: 0, width: 440, height: 76), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
            panel.level = .screenSaver; panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            hud = panel
        }
        let location = pointer ?? NSEvent.mouseLocation
        guard let hud, let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) ?? NSScreen.main else { return }
        hud.contentView = NSHostingView(rootView: NavigationHUD(mode: mode, status: status, prefix: prefix))
        let area = screen.visibleFrame, size = hud.frame.size
        let left = area.minX + 24, center = area.midX - size.width / 2, right = area.maxX - size.width - 24
        let bottom = area.minY + 24, top = area.maxY - size.height - 24
        // Bottom center is preferred; corners and the top keep the card off labels and the pointer.
        let spots = [(center, bottom), (center, top), (left, bottom), (right, bottom), (left, top), (right, top)]
            .map { CGRect(origin: CGPoint(x: $0.0, y: $0.1), size: size) }
        let frame = HUDPlacement.choose(spots, avoiding: avoid, pointer: pointer) ?? spots[0]
        hud.setFrameOrigin(frame.origin)
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
                Text("Spray Can · \(mode.localizedTitle)").font(.system(size: 13, weight: .semibold))
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
    /// The label's color group when color coding is on.
    var group: NSColor? = nil
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 5) }
    var body: some View {
        let tint = group.map { Color(nsColor: $0) } ?? settings.color(ocr ? .ocr : .label)
        // Glass would wash out a group color, so color-coded badges are always solid.
        if reduceTransparency || group != nil { shape.fill(tint) }
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
    /// Shared by the badge outline, connector, and element box when color coding is on.
    var color: NSColor?
}
private struct HintLayer: View {
    let hints: [PlacedHint]
    let prefix: String
    let height: CGFloat
    private var badges: some View {
        ZStack(alignment: .topLeading) {
            ForEach(hints) { hint in
                HintBackground(ocr: hint.target.source == .text, group: hint.color)
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
            let ink = hint.color.map(Settings.textColor(on:)) ?? settings.nsColor(.text)
            let text = NSMutableAttributedString(string: string, attributes: [.font: font, .foregroundColor: ink])
            let matched = min((prefix.uppercased() as NSString).length, text.length)
            // On color-coded badges the highlight color can vanish (mint on yellow); dim the typed part instead.
            let typed = hint.color == nil ? settings.nsColor(.highlight) : ink.withAlphaComponent(0.45)
            if matched > 0 { text.addAttribute(.foregroundColor, value: typed, range: NSRange(location: 0, length: matched)) }
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
    /// Detected text and icon rects (global Quartz) that labels must not cover.
    var content: [CGRect] = [] { didSet { if content != oldValue { needsLayout = true } } }
    var icons: [CGRect] = [] { didSet { if icons != oldValue { needsLayout = true } } }
    var screenOrigin = CGPoint.zero
    var primaryHeight: CGFloat = 0
    var preview = false
    private var preparingPreview = false
    private var previewTexts: [CGRect] = []
    private var placed: [PlacedHint] = []
    private var layoutItems: [HintLayoutItem] = []
    private var layoutBounds = CGRect.zero
    private var layoutStyle = HintPlacementStyle.centered
    private var layoutContent: [CGRect] = []
    private var layoutIcons: [CGRect] = []
    private var placements: [HintPlacement] = []
    private var colorGroups: [String: Int] = [:]
    private var layoutTime: TimeInterval = 0
    /// Counts for the readability snapshot harness.
    var snapshotSummary: String {
        let shown = Set(placed.map(\.id))
        let connectors = placements.filter { shown.contains($0.id) && $0.displaced }.count
        return "Labels: \(placed.count); connectors: \(connectors); layout: \(Int(layoutTime * 1000)) ms"
    }
    /// Visible labels and their elements in global Cocoa coordinates, for keeping the HUD clear.
    var occupied: [CGRect] {
        placed.flatMap { [$0.frame, local($0.target.frame)] }.map { $0.offsetBy(dx: screenOrigin.x, dy: screenOrigin.y) }
    }
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
            // A small list with text and a toolbar of icons, laid out like a real scan reports them.
            let font = NSFont.systemFont(ofSize: 12)
            var rows: [Target] = [], texts: [CGRect] = [], symbols: [CGRect] = []
            for (index, title) in ["Inbox", "Drafts", "Archive"].enumerated() {
                let frame = CGRect(x: bounds.width * 0.08, y: bounds.height / 2 - 37 + CGFloat(index) * 26, width: 130, height: 22)
                rows.append(Target(id: "preview-\(index)", frame: frame, source: .accessibility, title: title))
                symbols.append(CGRect(x: frame.minX + 6, y: frame.minY + 5, width: 13, height: 12))
                let size = (title as NSString).size(withAttributes: [.font: font])
                texts.append(CGRect(x: frame.minX + 26, y: frame.midY - size.height / 2 + 2, width: size.width, height: size.height - 4))
            }
            for index in 0..<4 {
                let frame = CGRect(x: bounds.width * 0.58 + CGFloat(index) * 32, y: bounds.height / 2 - 12, width: 26, height: 24)
                rows.append(Target(id: "preview-\(index + 3)", frame: frame, source: .accessibility, title: "Tool"))
                symbols.append(frame.insetBy(dx: 7, dy: 6))
            }
            targets = zip(rows, ["as", "ad", "af", "ag", "ah", "aj", "ak"]).map { target, label in var target = target; target.label = label; return target }
            previewTexts = texts; content = texts; icons = symbols
            prefix = ""
        }
        let settings = Settings.shared
        let font = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .semibold)
        let visible = TargetCollection.unique(targets).filter { bounds.contains(CGPoint(x: local($0.frame).midX, y: local($0.frame).midY)) }
        let items = visible.map { target in
            let size = (target.label.uppercased() as NSString).size(withAttributes: [.font: font])
            return HintLayoutItem(id: target.id, target: local(target.frame), size: CGSize(width: size.width + 12, height: size.height + 6),
                                  fixed: target.source == .grid, titled: !target.title.isEmpty)
        }
        let style = settings.hintStyle
        let obstacles = content.map(local).filter { bounds.intersects($0) }
        let images = obstacles.isEmpty ? [] : icons.map(local).filter { bounds.intersects($0) }
        if items != layoutItems || bounds != layoutBounds || style != layoutStyle || obstacles != layoutContent || images != layoutIcons {
            layoutItems = items; layoutBounds = bounds; layoutStyle = style; layoutContent = obstacles; layoutIcons = images
            let started = ProcessInfo.processInfo.systemUptime
            placements = HintLayout.place(items, in: bounds, style: style, content: obstacles, icons: images)
            layoutTime = ProcessInfo.processInfo.systemUptime - started
            let fixed = Set(items.filter(\.fixed).map(\.id))
            colorGroups = HintLayout.colorGroups(placements.filter { !fixed.contains($0.id) })
        }
        let frames = Dictionary(placements.map { ($0.id, $0.frame) }, uniquingKeysWith: { first, _ in first })
        placed = visible.compactMap { target in
            guard settings.showLabels, target.label.hasPrefix(prefix), let frame = frames[target.id] else { return nil }
            let color = settings.colorCodeTargets && target.source != .text ? colorGroups[target.id].map { Settings.palette[$0] } : nil
            return PlacedHint(id: target.id, target: target, frame: frame, color: color)
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
                NSColor.secondaryLabelColor.withAlphaComponent(0.4).setStroke()
                let control = NSBezierPath(roundedRect: local(target.frame), xRadius: 5, yRadius: 5)
                control.lineWidth = 1; control.stroke()
            }
            NSColor.secondaryLabelColor.setFill()
            for icon in icons { NSBezierPath(roundedRect: local(icon), xRadius: 3, yRadius: 3).fill() }
            for (text, title) in zip(previewTexts, ["Inbox", "Drafts", "Archive"]) {
                (title as NSString).draw(at: CGPoint(x: local(text).minX, y: local(text).minY - 2), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor])
            }
        }
        for target in targets where target.source == .grid && settings.showLines {
            settings.nsColor(.grid).withAlphaComponent(0.45).setStroke()
            let border = NSBezierPath(rect: local(target.frame)); border.lineWidth = 0.5; border.stroke()
        }
        let shown = Dictionary(placed.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Shade each element in its label's color, under its outline, connector, and badge.
        let shade = settings.elementShading == .always || (settings.elementShading == .whileTyping && !prefix.isEmpty)
        for hint in placed where shade {
            guard let color = hint.color else { continue }
            let frame = local(hint.target.frame)
            // Large panes get a lighter tint so they don't wash out everything inside them.
            let opacity = settings.shadingOpacity * (frame.width * frame.height > 40_000 ? 0.6 : 1)
            color.withAlphaComponent(opacity).setFill()
            NSBezierPath(roundedRect: frame.insetBy(dx: -2, dy: -2), xRadius: 4, yRadius: 4).fill()
        }
        // While a label is being typed, outline the remaining elements in their label's color.
        for hint in placed where !prefix.isEmpty {
            guard let color = hint.color else { continue }
            color.setStroke()
            let box = NSBezierPath(roundedRect: local(hint.target.frame).insetBy(dx: -2, dy: -2), xRadius: 4, yRadius: 4)
            box.lineWidth = 1.5; box.stroke()
        }
        for hint in placements where hint.displaced {
            guard let visible = shown[hint.id] else { continue }
            let color = visible.color ?? settings.nsColor(.grid)
            color.withAlphaComponent(visible.color == nil ? 0.8 : 1).setStroke()
            let line = NSBezierPath(); line.move(to: hint.connectorStart); line.line(to: hint.anchor)
            line.lineWidth = visible.color == nil ? 1 : 1.5; line.stroke()
            color.setFill()
            NSBezierPath(ovalIn: CGRect(x: hint.anchor.x - 2, y: hint.anchor.y - 2, width: 4, height: 4)).fill()
        }
        if let selected {
            settings.nsColor(.highlight).setStroke()
            let ring = NSBezierPath(roundedRect: local(selected).insetBy(dx: -4, dy: -4), xRadius: 7, yRadius: 7)
            ring.lineWidth = 2; ring.stroke()
        }
    }
}
