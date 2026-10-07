import AppKit
import SprayCanCore

final class MouseDriver {
    private let source = CGEventSource(stateID: .hidSystemState)
    private(set) var holding = false
    private var postedPoint: CGPoint?
    private var pendingRelease: (() -> Void)?
    private var clickGeneration = 0
    /// Remaining points of a held-button glide, and work waiting for it to finish.
    private var dragSteps: [CGPoint] = []
    private var dragTimer: Timer?
    private var afterDrag: [() -> Void] = []
    // Quartz delivery is asynchronous. Return must use the just-posted destination.
    var point: CGPoint { postedPoint ?? CGEvent(source: nil)?.location ?? .zero }
    func resetPosition() { postedPoint = nil }
    func move(to point: CGPoint) {
        let start = dragSteps.last ?? lastDragPoint ?? self.point
        postedPoint = point
        guard holding else {
            CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
            return
        }
        // Some apps, including the macOS screenshot tool, ignore a drag that jumps in one event.
        // Glide to the destination in small steps instead.
        let count = max(4, min(24, Int(hypot(point.x - start.x, point.y - start.y) / 20)))
        dragSteps = (1...count).map { index in
            let f = CGFloat(index) / CGFloat(count)
            return CGPoint(x: start.x + (point.x - start.x) * f, y: start.y + (point.y - start.y) * f)
        }
        guard dragTimer == nil else { return }
        dragTimer = Timer.scheduledTimer(withTimeInterval: 0.012, repeats: true) { [weak self] _ in self?.stepDrag() }
    }
    private var lastDragPoint: CGPoint?
    private func stepDrag() {
        guard !dragSteps.isEmpty else {
            dragTimer?.invalidate(); dragTimer = nil
            let waiting = afterDrag; afterDrag = []
            waiting.forEach { $0() }
            return
        }
        let next = dragSteps.removeFirst()
        lastDragPoint = next
        CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: next, mouseButton: .left)?.post(tap: .cghidEventTap)
    }
    /// Runs once any held-button glide has reached its destination.
    private func whenSettled(_ action: @escaping () -> Void) {
        if dragTimer == nil { action() } else { afterDrag.append(action) }
    }
    func hold() {
        guard !holding else { return }
        holding = true; lastDragPoint = point
        post(.leftMouseDown, button: .left, modifiers: [])
    }
    /// Releases immediately (cancellation); a glide in progress jumps to its end first.
    func release() {
        cancelScroll()
        clickGeneration += 1
        pendingRelease?(); pendingRelease = nil
        dragTimer?.invalidate(); dragTimer = nil
        if let end = dragSteps.last { CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: end, mouseButton: .left)?.post(tap: .cghidEventTap) }
        dragSteps = []; afterDrag = []; lastDragPoint = nil
        guard holding else { return }
        post(.leftMouseUp, button: .left, modifiers: []); holding = false
    }
    func click(button number: Int, modifiers: KeyModifiers, count: Int = 1, completion: @escaping () -> Void) {
        // Drop where the glide ends, after a short pause so the target app registers the final position.
        if holding {
            whenSettled { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.release(); completion() } }
            return
        }
        let button: CGMouseButton = number == 1 ? .right : number == 2 ? .center : .left
        let down: CGEventType = number == 1 ? .rightMouseDown : number == 2 ? .otherMouseDown : .leftMouseDown
        let up: CGEventType = number == 1 ? .rightMouseUp : number == 2 ? .otherMouseUp : .leftMouseUp
        let destination = point
        clickGeneration += 1; let generation = clickGeneration
        func send(_ index: Int) {
            guard generation == clickGeneration else { return }
            post(down, button: button, modifiers: modifiers, count: index, at: destination)
            pendingRelease = { [weak self] in self?.post(up, button: button, modifiers: modifiers, count: index, at: destination) }
            // Give native controls a real press interval without blocking the input/main run loop.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                guard let self, generation == self.clickGeneration else { return }
                self.pendingRelease?(); self.pendingRelease = nil
                if index < count { DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { send(index + 1) } }
                else { completion() }
            }
        }
        send(1)
    }
    /// Positive `y` scrolls down (reveals content below), positive `x` scrolls right, whatever the
    /// natural-scrolling setting; it is read on every scroll so a change applies immediately.
    /// Scrolls smoothly: the distance is added to what is still pending and sent in eased steps at
    /// 120 Hz, so held keys glide continuously. `instant` sends it as one event (top and bottom jumps).
    /// The second click of a double-click, at the first click's point.
    func clickAgain(at location: CGPoint) {
        post(.leftMouseDown, button: .left, modifiers: [], count: 2, at: location)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.post(.leftMouseUp, button: .left, modifiers: [], count: 2, at: location)
        }
    }
    func scroll(x: Int, y: Int, instant: Bool = false, fraction: Double? = ScrollAnimation.fraction) {
        guard let fraction, !instant else { cancelScroll(); postScroll(x: x, y: y); return }
        scrollFraction = fraction
        pendingScroll.x += Double(x); pendingScroll.y += Double(y)
        guard scrollTimer == nil else { return }
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120, repeats: true) { [weak self] _ in self?.stepScroll() }
    }
    func cancelScroll() { scrollTimer?.invalidate(); scrollTimer = nil; pendingScroll = (0, 0) }
    private var pendingScroll: (x: Double, y: Double) = (0, 0)
    private var scrollFraction = ScrollAnimation.fraction
    private var scrollTimer: Timer?
    private func stepScroll() {
        let x = ScrollAnimation.next(remaining: pendingScroll.x, fraction: scrollFraction), y = ScrollAnimation.next(remaining: pendingScroll.y, fraction: scrollFraction)
        pendingScroll = (x.remaining, y.remaining)
        if x.step == 0 && y.step == 0 { cancelScroll(); return }
        postScroll(x: x.step, y: y.step)
    }
    private func postScroll(x: Int, y: Int) {
        let natural = UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
        let wheel = ScrollDirection.wheelDeltas(x: x, y: y, natural: natural)
        CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: wheel.vertical, wheel2: wheel.horizontal, wheel3: 0)?.post(tap: .cghidEventTap)
    }
    private func post(_ type: CGEventType, button: CGMouseButton, modifiers: KeyModifiers, count: Int = 1, at location: CGPoint? = nil) {
        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location ?? point, mouseButton: button)
        event?.flags = modifiers.cgFlags
        event?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
        event?.post(tap: .cghidEventTap)
    }
}
