import AppKit
import SwiftUI
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
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency {
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

final class HintCanvas: NSView {
    var targets: [Target] = []
    var prefix = ""
    var selected: CGRect?
    var screenOrigin = CGPoint.zero
    var primaryHeight: CGFloat = 0
    override var isFlipped: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        let settings = Settings.shared
        var placed: [CGRect] = []
        let font = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        func local(_ rect: CGRect) -> CGRect {
            Geometry.cocoa(rect, primaryHeight: primaryHeight).offsetBy(dx: -screenOrigin.x, dy: -screenOrigin.y)
        }
        for target in targets {
            let rect = local(target.frame)
            guard bounds.intersects(rect) else { continue }
            if target.source == .grid && settings.showLines {
                NSColor.systemTeal.withAlphaComponent(0.20).setStroke()
                let border = NSBezierPath(rect: rect); border.lineWidth = 0.5; border.stroke()
            }
            guard settings.showLabels else { continue }
            let text = target.label.uppercased() as NSString
            let size = text.size(withAttributes: attrs)
            var badge = CGRect(x: rect.midX - size.width / 2 - 6, y: rect.midY - size.height / 2 - 3, width: size.width + 12, height: size.height + 6)
            if target.source != .grid {
                for _ in 0..<7 where placed.contains(where: { $0.intersects(badge.insetBy(dx: -2, dy: -2)) }) { badge.origin.y += badge.height + 2 }
            }
            badge.origin.x = min(max(2, badge.minX), bounds.width - badge.width - 2)
            badge.origin.y = min(max(2, badge.minY), bounds.height - badge.height - 2)
            placed.append(badge)
            if abs(badge.midY - rect.midY) > 15 {
                NSColor.systemTeal.withAlphaComponent(0.55).setStroke()
                let line = NSBezierPath(); line.move(to: CGPoint(x: rect.midX, y: rect.midY)); line.line(to: CGPoint(x: badge.midX, y: badge.midY)); line.lineWidth = 1; line.stroke()
            }
            let shape = NSBezierPath(roundedRect: badge, xRadius: 5, yRadius: 5)
            let alpha = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : settings.contrast
            (target.source == .text ? NSColor.systemIndigo : NSColor(calibratedRed: 0.03, green: 0.26, blue: 0.29, alpha: 1)).withAlphaComponent(alpha).setFill(); shape.fill()
            NSColor.white.withAlphaComponent(0.6).setStroke(); shape.lineWidth = 0.75; shape.stroke()
            text.draw(at: CGPoint(x: badge.minX + 6, y: badge.minY + 3), withAttributes: attrs)
            if !prefix.isEmpty {
                let matched = String(target.label.prefix(prefix.count)).uppercased() as NSString
                matched.draw(at: CGPoint(x: badge.minX + 6, y: badge.minY + 3), withAttributes: [.font: font, .foregroundColor: NSColor.systemMint])
            }
        }
        if let selected {
            NSColor.systemMint.setStroke()
            let ring = NSBezierPath(roundedRect: local(selected).insetBy(dx: -4, dy: -4), xRadius: 7, yRadius: 7)
            ring.lineWidth = 2; ring.stroke()
        }
    }
}
