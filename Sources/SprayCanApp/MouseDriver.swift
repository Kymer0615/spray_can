import AppKit
import SprayCanCore

final class MouseDriver {
    private let source = CGEventSource(stateID: .hidSystemState)
    private(set) var holding = false
    private var postedPoint: CGPoint?
    private var pendingRelease: (() -> Void)?
    private var clickGeneration = 0
    // Quartz delivery is asynchronous. Return must use the just-posted destination.
    var point: CGPoint { postedPoint ?? CGEvent(source: nil)?.location ?? .zero }
    func resetPosition() { postedPoint = nil }
    func move(to point: CGPoint) {
        postedPoint = point
        CGEvent(mouseEventSource: source, mouseType: holding ? .leftMouseDragged : .mouseMoved,
                mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }
    func hold() { guard !holding else { return }; holding = true; post(.leftMouseDown, button: .left, modifiers: []) }
    func release() {
        clickGeneration += 1
        pendingRelease?(); pendingRelease = nil
        guard holding else { return }
        post(.leftMouseUp, button: .left, modifiers: []); holding = false
    }
    func click(button number: Int, modifiers: KeyModifiers, count: Int = 1, completion: @escaping () -> Void) {
        if holding { release(); completion(); return }
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
    func scroll(x: Int, y: Int) {
        CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: Int32(-y), wheel2: Int32(-x), wheel3: 0)?.post(tap: .cghidEventTap)
    }
    private func post(_ type: CGEventType, button: CGMouseButton, modifiers: KeyModifiers, count: Int = 1, at location: CGPoint? = nil) {
        let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location ?? point, mouseButton: button)
        event?.flags = modifiers.cgFlags
        event?.setIntegerValueField(.mouseEventClickState, value: Int64(count))
        event?.post(tap: .cghidEventTap)
    }
}
