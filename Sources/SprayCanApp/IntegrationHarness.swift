import AppKit
import SprayCanCore

/// Opt-in live runner. Injects events only while its own synthetic fixture is frontmost.
final class IntegrationHarness {
    private let controller: AppController
    private let fixture = Process()
    private var timer: Timer?
    private var cycle = 0
    private var phase = 0
    private var gridLabel = ""
    private var phaseStarted = Date()
    private var lastClicks = -1
    private var lastLeaks = -1
    private let statePath: String
    private let savedCellSize: Double
    private let savedInstantClick: Bool
    private let savedVision: Bool
    private let savedVi: Bool
    init(controller: AppController) {
        self.controller = controller
        savedCellSize = controller.settings.cellSize
        savedInstantClick = controller.settings.instantClick
        savedVision = controller.settings.vision
        savedVi = controller.settings.vi
        statePath = ProcessInfo.processInfo.environment["SPRAYCAN_FIXTURE_STATE"] ?? "/tmp/spraycan-fixture-state.json"
    }
    func start() {
        guard controller.accessibilityGranted, controller.keyboardGranted else { finish("Accessibility/Input Monitoring unavailable"); return }
        guard let executable = ProcessInfo.processInfo.environment["SPRAYCAN_FIXTURE_EXECUTABLE"] else { finish("Fixture executable missing"); return }
        controller.settings.cellSize = 32; controller.settings.instantClick = false
        controller.settings.vision = false; controller.settings.vi = false
        fixture.executableURL = URL(fileURLWithPath: executable)
        var environment = ProcessInfo.processInfo.environment; environment["SPRAYCAN_FIXTURE_STATE"] = statePath
        fixture.environment = environment
        do { try fixture.run() } catch { finish("Fixture launch failed"); return }
        controller.start(); phaseStarted = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in self?.tick() }
    }
    private func tick() {
        if Date().timeIntervalSince(phaseStarted) > 8 {
            finish("Phase \(phase) timeout, cycle \(cycle), clicks=\(lastClicks), leaks=\(lastLeaks): \(controller.status)"); return
        }
        guard fixture.isRunning else { finish("Fixture exited"); return }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == fixture.processIdentifier else {
            if phase == 0 { return }
            finish("Focus left test fixture; stopped injection"); return
        }
        switch phase {
        case 0:
            guard Date().timeIntervalSince(phaseStarted) > 0.5 else { return }
            activate(.elements); next(1)
        case 1:
            guard let target = controller.integrationTargets.first(where: { $0.title == "Test Click" }) else { return }
            // Element labels are read from the current session, exactly as a user sees them.
            if gridLabel.isEmpty {
                let grid = HintLabels.assign(Geometry.grid(screens: controller.overlay.quartzScreens, cellSize: 32))
                guard let cell = grid.first(where: { target.frame.insetBy(dx: 5, dy: 5).contains($0.point) }) else { finish("No grid center inside fixture button"); return }
                gridLabel = cell.label
            }
            typeAndClick(target.label); next(3)
        case 2:
            if cycle < 30 { activate(.elements); next(1) }
            else {
                // Grid geometry is deterministic: inject labels before the overlay is ready.
                activate(.grid); typeAndClick(gridLabel); next(3)
            }
        case 3:
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: statePath)), let state = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else { return }
            lastClicks = state["clicks", default: 0]; lastLeaks = state["leakedCharacters", default: 0]
            guard lastLeaks == 0 else { finish("Navigation input leaked into the fixture field"); return }
            if lastClicks > cycle + 1 { finish("Duplicated click"); return }
            guard lastClicks == cycle + 1 else { return }
            cycle += 1
            if cycle % 10 == 0 { print("Completed live cycle \(cycle)") }
            if cycle >= 60 { finish(nil); return }
            next(2)
        default: break
        }
    }
    private func next(_ phase: Int) { self.phase = phase; phaseStarted = Date() }
    private func activate(_ mode: NavigationMode) {
        guard let shortcut = controller.settings.shortcuts[mode] else { return }
        key(shortcut.keyCode, flags: shortcut.modifiers)
    }
    private func typeAndClick(_ label: String) {
        let residual: KeyModifiers = cycle % 2 == 0 ? [.shift, .command] : []
        for character in label {
            guard let code = physicalKeys.first(where: { $0.value == String(character) })?.key else { finish("Unknown label key"); return }
            key(code, flags: residual)
        }
        key(36, flags: [])
    }
    private func key(_ code: UInt16, flags: KeyModifiers) {
        let source = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
            event?.flags = flags.cgFlags; event?.post(tap: .cghidEventTap)
        }
    }
    private func finish(_ failure: String?) {
        timer?.invalidate(); controller.cancel()
        controller.settings.cellSize = savedCellSize; controller.settings.instantClick = savedInstantClick
        controller.settings.vision = savedVision; controller.settings.vi = savedVi
        if fixture.isRunning { fixture.terminate() }
        if let failure { print("INTEGRATION FAIL: \(failure)"); exit(1) }
        print("INTEGRATION PASS: 30 current-element clicks + 30 immediate grid activation/label/click cycles; zero leaked characters; alternating residual modifiers.")
        exit(0)
    }
}
