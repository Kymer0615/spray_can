import AppKit
import Combine
import Carbon
import SprayCanCore
import os

final class AppController: ObservableObject {
    let settings = Settings.shared
    let keyboard = KeyboardCapture()
    let overlay = OverlayManager()
    let mouse = MouseDriver()
    let accessibility = AccessibilityProvider()
    let ocr = OCRProvider()
    let accessibilityChanges = AccessibilityChanges()
    private lazy var prescan: TextPrescanner = TextPrescanner(
        frontWindow: { [weak self] (pid: pid_t) -> CGRect? in self?.frontWindow(of: pid) },
        screens: { [weak self] () -> [CGRect] in self?.overlay.quartzScreens ?? [] })
    /// Text read ahead for the target window: nil until known, empty when unusable.
    private var prescanned: [Target]?
    private var prescanPending = false
    @Published var status: String = String(localized: "Ready when you are")
    @Published var active = false
    @Published var shortcutIssues: [String] = []
    var openSettings: (() -> Void)?
    var stateChanged: (() -> Void)?
    private var session = NavigationSession()
    var integrationTargets: [Target] { session.phase == .ready ? session.targets : [] }
    private var result = DiscoveryResult()
    /// Text detected in the target window; nil until known, so labels fall back to estimates.
    private var detectedText: [CGRect]?
    private var targetPID: pid_t = 0
    private var deferred: [CapturedKey] = []
    private var selecting = false
    private var selectedTarget: Target?
    private var selectedFrame: CGRect?
    private var scrollIndex = 0
    /// Scroll mode in an app without accessible scroll areas (VS Code, other Electron apps):
    /// scroll wherever the pointer is until Tab moves it to a content area.
    private var scrollUnderPointer = false
    /// Where the last Return click landed, for a second Return that double-clicks.
    private var lastClickPoint: CGPoint?
    /// A Return waiting to learn whether it is a tap (click) or a long press (right-click).
    private var pendingReturn: (down: TimeInterval, work: DispatchWorkItem)?
    private var lastReturnUp: TimeInterval = 0
    private var scrollFraction: Double? { ScrollAnimation.fraction(smoothness: settings.scrollSmoothness) }
    /// Where the pointer was before scroll mode moved it; put back when the session ends.
    private var pointerBeforeScroll: CGPoint?
    private var previousG = false
    private var centerIndex = 0
    private var subscriptions = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var refreshWork: DispatchWorkItem?
    private var lastScan: TimeInterval = 0
    /// Set after the target window changed, so the status explains the refresh.
    private var windowChanged = false
    /// The mode to resume after an app switch that paused the session (⌘Tab, ⌘`).
    private var followMode: NavigationMode?
    private var followExpiry: DispatchWorkItem?
    private let log = Logger(subsystem: "io.github.Kymer0615.SprayCan", category: "sessions")

    init() {
        accessibilityChanges.changed = { [weak self] trigger in self?.targetChanged(trigger) }
        keyboard.onReady = { [weak self] in self?.status = String(localized: "Ready when you are") }
        keyboard.onActivate = { [weak self] mode in self?.activate(mode) }
        keyboard.onKey = { [weak self] key in self?.handle(key) }
        keyboard.onReturnUp = { [weak self] time in self?.returnReleased(at: time) }
        keyboard.onScrollExit = { [weak self] in
            guard let self, self.active, self.session.mode == .scroll else { return }
            self.cancel(); self.status = String(localized: "Ready when you are")
        }
        keyboard.onDoubleClick = { [weak self] in
            guard let self, let point = self.lastClickPoint, !self.active else { return }
            self.lastClickPoint = nil; self.mouse.clickAgain(at: point)
        }
        keyboard.onInterrupted = { [weak self] message in
            guard let self else { return }
            if self.active { self.cancel() }
            if !message.isEmpty { self.status = message }
        }
        // ⌘Tab and ⌘` pass through to macOS; follow wherever focus lands.
        keyboard.onAppSwitchStarted = { [weak self] in
            guard let self, self.active else { return }
            let mode = self.session.mode
            if RefreshPolicy.decide(.structural, mode: mode, holding: self.mouse.holding, selecting: self.selecting, typing: false, sinceLastScan: .infinity) == .refresh {
                self.cancel(); self.follow(mode)
            } else { self.cancel() }
        }
        keyboard.onAppSwitchEnded = { [weak self] in self?.resumeFollow(after: 0.15) }
        settings.$prescanText.combineLatest(settings.$vision, settings.$ocrLanguages).dropFirst().sink { [weak self] _ in
            // Published before the new value is stored; apply on the next turn.
            DispatchQueue.main.async { guard let self, !self.active else { return }; self.prescan.reset() }
        }.store(in: &subscriptions)
        DispatchQueue.main.async { [weak self] in self?.prescan.resume() }
        settings.$passSystemShortcuts.combineLatest(settings.$vi).sink { [weak self] pass, vi in
            self?.keyboard.setKeyRules(passThrough: pass, vi: vi)
        }.store(in: &subscriptions)
        settings.$shortcuts.dropFirst().debounce(for: .milliseconds(150), scheduler: RunLoop.main).sink { [weak self] bindings in
            self?.keyboard.configure(bindings); self?.shortcutIssues = self?.keyboard.conflicts ?? []
        }.store(in: &subscriptions)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.willSleepNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.cancel(); self?.overlay.rebuild() })
        }
        observers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let self, let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != getpid() else { return }
            if !self.active { self.prescan.resume() }
            if self.followMode != nil { self.resumeFollow(after: 0.15); return }
            guard self.active, app.processIdentifier != self.targetPID else { return }
            self.targetChanged(.structural)
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.cancel(); self?.overlay.rebuild() })
    }
    var accessibilityGranted: Bool { AXIsProcessTrusted() }
    var keyboardReady: Bool { accessibilityGranted && keyboard.isRunning && !IsSecureEventInputEnabled() }
    var screenGranted: Bool { CGPreflightScreenCaptureAccess() }
    func start() {
        guard accessibilityGranted else { status = String(localized: "Grant Accessibility to enable navigation."); return }
        keyboard.configure(settings.shortcuts); shortcutIssues = keyboard.conflicts
        keyboard.start(); status = keyboardReady ? String(localized: "Ready when you are") : String(localized: "Starting keyboard capture…")
    }
    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        if !accessibilityGranted { openPrivacyPane("Privacy_Accessibility") }
    }
    private func openPrivacyPane(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"), NSWorkspace.shared.open(url) else {
            status = String(localized: "Open System Settings → Privacy & Security to enable access."); return
        }
    }
    func requestScreen() {
        if !CGRequestScreenCaptureAccess() { openPrivacyPane("Privacy_ScreenCapture") }
    }
    func activate(_ mode: NavigationMode) {
        guard accessibilityGranted, !IsSecureEventInputEnabled() else {
            keyboard.setActive(false); status = String(localized: "Navigation unavailable. Check permissions or Secure Input."); openSettings?(); return
        }
        refreshWork?.cancel(); ocr.cancel(); accessibilityChanges.stop(); mouse.release(); mouse.resetPosition(); deferred = []; selecting = false; selectedTarget = nil; selectedFrame = nil
        // Leaving or refreshing scroll mode: put the pointer back before anything else uses it.
        if let point = pointerBeforeScroll { pointerBeforeScroll = nil; mouse.move(to: point); mouse.resetPosition() }
        clearFollow(); windowChanged = false
        targetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        guard targetPID != getpid(), targetPID != 0 else { keyboard.setActive(false); status = String(localized: "Switch to another app, then activate navigation."); return }
        active = true; keyboard.setActive(true); stateChanged?(); prescan.pause()
        keyboard.setScrollMode(mode == .scroll)
        let generation = session.begin(mode)
        lastScan = ProcessInfo.processInfo.systemUptime
        // Watch from the start, so changes during a scan are not missed.
        if mode == .elements || mode == .scroll { accessibilityChanges.start(pid: targetPID) }
        detectedText = nil; prescanned = nil; prescanPending = false
        if mode == .elements, settings.vision, let window = frontWindow(of: targetPID) {
            prescanPending = prescan.text(pid: targetPID, frame: window, languages: settings.ocrLanguages) { [weak self] text in
                guard let self, self.session.generation == generation else { return }
                self.prescanPending = false; self.prescanned = text ?? []
            }
        }
        if mode == .elements, let window = frontWindow(of: targetPID) {
            // Runs alongside the accessibility scan, so labels usually avoid real text from the start.
            ocr.detectText(in: window) { [weak self] rects in
                guard let self, self.active, self.session.generation == generation, let rects else { return }
                self.detectedText = rects; self.render()
            }
        }
        status = mode == .freestyle ? String(localized: "Move with arrows · Return to click") : String(localized: "Finding targets…")
        render()
        let started = ProcessInfo.processInfo.systemUptime
        if mode == .grid || mode == .freestyle {
            let targets = mode == .grid ? Geometry.grid(screens: overlay.quartzScreens, cellSize: settings.cellSize) : []
            _ = session.publish(targets, generation: generation, vi: settings.vi)
            updateReadyStatus(); render(); return
        }
        let context = DiscoveryContext(pid: targetPID, screens: overlay.quartzScreens, allWindows: settings.allWindows, generation: generation)
        accessibility.discover(context) { [weak self] discovered in
            guard let self, self.active, self.session.generation == generation else { return }
            self.whenPrescanKnown(generation, patience: 0.15) { self.finishDiscovery(discovered, mode: mode, context: context, generation: generation, started: started) }
        }
    }
    /// Text read ahead is usually confirmed before discovery ends; wait briefly rather than publish twice.
    private func whenPrescanKnown(_ generation: Int, patience: TimeInterval, then finish: @escaping () -> Void) {
        guard prescanPending, patience > 0 else { prescanPending = false; finish(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            guard let self, self.active, self.session.generation == generation else { return }
            self.whenPrescanKnown(generation, patience: patience - 0.03, then: finish)
        }
    }
    private func finishDiscovery(_ discovered: DiscoveryResult, mode: NavigationMode, context: DiscoveryContext, generation: Int, started: TimeInterval) {
        result = discovered
        scrollUnderPointer = false
        if mode == .scroll && discovered.scrollAreas.isEmpty, let window = discovered.captureRects.first {
            // No accessible scroll areas: fall back to web content areas (largest first), else the window,
            // and start by scrolling under the pointer when it is already over the window.
            let areas = discovered.webAreas.filter { $0.width > 40 && $0.height > 40 }.sorted { $0.width * $0.height > $1.width * $1.height }
            result.scrollAreas = (areas.isEmpty ? [window] : areas).enumerated().map { Target(id: "scroll-\($0.offset)", frame: $0.element, source: .accessibility, role: kAXScrollAreaRole) }
            scrollUnderPointer = window.contains(mouse.point)
        }
        // "Don't move" scrolls wherever the pointer already is; Tab still moves it into an area.
        if mode == .scroll && settings.scrollPointer == .stay && !result.scrollAreas.isEmpty { scrollUnderPointer = true }
        let text = mode == .elements && settings.vision ? prescanned.flatMap { $0.isEmpty ? nil : $0 } : nil
        let targets = mode == .scroll ? result.scrollAreas
            : text.map { settings.dedupeOCR ? Geometry.mergeText(discovered.targets, $0) : Geometry.merge(discovered.targets, $0) } ?? discovered.targets
        _ = session.publish(targets, generation: generation, vi: settings.vi)
        scrollIndex = 0
        updateReadyStatus()
        if mode == .scroll { focusScrollArea() }
        render(); drain()
        log.info("Discovery completed in \(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)) ms; targets: \(targets.count); bounded: \(discovered.timedOut)")
        if text != nil { log.info("Text labels reused from the pre-scan") }
        if mode == .elements && settings.vision && text == nil {
            let started = ProcessInfo.processInfo.systemUptime
            let regions = discovered.captureRects.isEmpty ? context.screens : discovered.captureRects
            ocr.discover(screens: context.screens, regions: regions, languages: settings.ocrLanguages) { [weak self] text, error in
                guard let self, self.active, self.session.generation == generation else { return }
                self.log.info("Text recognition completed in \(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)) ms; text: \(text.count)")
                if let error { self.status = error; self.render(); return }
                guard !self.session.hasTyped else { return }
                let merged = self.settings.dedupeOCR ? Geometry.mergeText(discovered.targets, text) : Geometry.merge(discovered.targets, text)
                _ = self.session.publish(merged, generation: generation, vi: self.settings.vi)
                self.updateReadyStatus(); self.render()
            }
        }
    }
    func cancel() {
        clearFollow(); windowChanged = false
        pendingReturn?.work.cancel(); pendingReturn = nil
        refreshWork?.cancel(); ocr.cancel(); accessibilityChanges.stop(); session.cancel(); accessibility.invalidate(session.generation)
        deferred = []; selecting = false; active = false; selectedTarget = nil; selectedFrame = nil
        mouse.release(); mouse.resetPosition(); keyboard.setActive(false); keyboard.setScrollMode(false); overlay.hide(); stateChanged?()
        prescan.resume()
        if let point = pointerBeforeScroll { pointerBeforeScroll = nil; mouse.move(to: point); mouse.resetPosition() }
    }
    private func frontWindow(of pid: pid_t) -> CGRect? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.first { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }
            .flatMap { ($0[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) } }
    }
    private func updateReadyStatus() {
        if session.mode == .freestyle { status = String(localized: "Move with arrows · Return to click") }
        else if session.mode == .scroll {
            status = result.scrollAreas.isEmpty ? String(localized: "No scroll areas · ⇧⌘L for pointer scrolling")
                : scrollUnderPointer ? String(localized: "Scrolling under the pointer · HJKL scroll · Tab moves to content")
                : String(localized: "HJKL scroll · Tab changes area · Esc exits")
        }
        else { status = session.targets.isEmpty ? String(localized: "No targets found · ⇧⌘K opens the grid") : String(localized: "\(session.targets.count) targets · Type a label · Return clicks") }
        if result.timedOut && session.mode == .elements { status += String(localized: " · Partial scan") }
        if windowChanged { status = String(localized: "Window changed · ") + status }
    }
    private func render() {
        guard active else { return }
        overlay.render(targets: session.mode == .scroll ? [] : session.targets, prefix: session.prefix, mode: session.mode, status: status, selected: selectedFrame, pointer: mouse.point,
                       content: HintLayout.textContent(detected: detectedText ?? [], exposed: result.texts), icons: result.icons)
    }
    func handle(_ key: CapturedKey) {
        guard active else { return }
        let isLetter = key.text.count == 1 && key.text.first?.isLetter == true
        let action = KeyMap.action(code: key.code, text: key.text, modifiers: isLetter ? key.labelModifiers : key.modifiers, vi: settings.vi)
        if action == .hide || action == .settings { cancel(); if action == .settings { openSettings?() }; return }
        if action == .escape {
            if !deferred.isEmpty { deferred = []; status = String(localized: "Input cleared"); render(); return }
            if session.escape() == .cancelled { cancel() } else { updateReadyStatus(); render() }
            return
        }
        if session.phase == .discovering || selecting {
            if deferred.count < 32 { deferred.append(key) } else { status = String(localized: "Input queue full · Esc clears"); render() }
            return
        }
        if session.mode == .scroll { handleScroll(key); return }
        // Inherited activation modifiers affect labels only, never modified click actions.
        let labelAction = KeyMap.action(code: key.code, text: key.text, modifiers: key.labelModifiers, vi: settings.vi)
        if session.mode != .freestyle, case .label(let character) = labelAction {
            if !key.repeatKey { apply(session.type(character)) }
            render(); return
        }
        switch action {
        case .click(let button):
            if ReturnPress.defers(code: key.code, modifiers: key.modifiers, holding: mouse.holding, enabled: settings.holdReturnRightClicks) {
                pressReturn(key)
            } else { performClick(button, modifiers: key.modifiers) }
        case .doubleClick: performClick(0, modifiers: key.modifiers, count: 2)
        case .hold:
            // Space or = presses and holds; labels stay, so the next label drags. Pressing again drops.
            if mouse.holding { performClick(0, modifiers: []) }
            else { mouse.hold(); status = String(localized: "Holding · Type a label to drag · Space or Return drops"); render() }
        case .backspace: session.backspace(); render()
        case .move(let x, let y, let full):
            let step = settings.cellSize / (full ? 1 : 6)
            move(CGPoint(x: mouse.point.x + CGFloat(x) * step, y: mouse.point.y + CGFloat(y) * step))
        case .edge(let x, let y):
            if let screen = screenAtPointer {
                move(CGPoint(x: x == 0 ? mouse.point.x : x < 0 ? screen.minX + 1 : screen.maxX - 1,
                             y: y == 0 ? mouse.point.y : y < 0 ? screen.minY + 1 : screen.maxY - 1))
            }
        case .center:
            if let screen = screenAtPointer {
                let points = [CGPoint(x: screen.midX, y: screen.midY), CGPoint(x: screen.minX + 1, y: screen.minY + 1), CGPoint(x: screen.maxX - 1, y: screen.minY + 1), CGPoint(x: screen.maxX - 1, y: screen.maxY - 1), CGPoint(x: screen.minX + 1, y: screen.maxY - 1)]
                move(points[centerIndex % points.count]); centerIndex += 1
            }
        case .scroll(let x, let y): mouse.scroll(x: x * 40, y: y * 40, fraction: scrollFraction); if session.mode == .elements { scheduleRefresh() }
        case .toggleLines: settings.showLines.toggle(); render()
        case .toggleLabels: settings.showLabels.toggle(); render()
        case .cellSize(let direction): settings.cellSize = min(240, max(32, settings.cellSize + Double(direction * 12))); rebuildGrid()
        case .contrast(let direction):
            if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
                status = String(localized: "Reduce Transparency keeps label backgrounds opaque.")
            } else if settings.glassEnabled {
                status = String(localized: "Turn off Use Liquid Glass in Appearance to adjust opacity.")
            } else { settings.contrast = min(1, max(0.4, settings.contrast + Double(direction) * 0.05)) }
            render()
        default: break
        }
    }
    private var screenAtPointer: CGRect? { overlay.quartzScreens.first { $0.contains(mouse.point) } ?? overlay.quartzScreens.first }
    private func move(_ point: CGPoint) {
        selectedTarget = nil; selectedFrame = nil
        let screens = overlay.quartzScreens
        let target: CGPoint
        if screens.contains(where: { $0.contains(point) }) { target = point }
        else if let screen = screenAtPointer { target = CGPoint(x: min(max(point.x, screen.minX), screen.maxX - 1), y: min(max(point.y, screen.minY), screen.maxY - 1)) }
        else { return }
        mouse.move(to: target); render()
    }
    private func apply(_ outcome: NavigationSession.Outcome) {
        switch outcome {
        case .selected(let target): select(target)
        case .invalid: status = String(localized: "No matching label · Esc clears your input")
        default: break
        }
    }
    private func select(_ target: Target) {
        let generation = session.generation
        let finish: (CGRect?) -> Void = { [weak self] frame in
            guard let self, self.active, self.session.generation == generation else { return }
            self.selecting = false
            guard let frame, frame.width > 1, frame.height > 1 else { self.deferred = []; self.status = String(localized: "Target changed · Activate again to refresh"); self.render(); return }
            self.selectedTarget = target; self.selectedFrame = frame
            self.mouse.move(to: CGPoint(x: frame.midX, y: frame.midY))
            if self.mouse.holding { self.status = String(localized: "Holding · Type a label to drag · Space or Return drops") }
            else { self.status = target.source == .text ? String(localized: "Text location · Return clicks here") : String(localized: "Target selected · Return clicks · = starts dragging") }
            self.render()
            if self.settings.instantClick && !self.mouse.holding { self.performClick(0, modifiers: []) }
            else { self.drain() }
        }
        if let element = result.elements[target.id], target.source == .accessibility {
            selecting = true; accessibility.validate(element, within: target.frame, hitTest: false, completion: finish)
        } else { finish(target.frame) }
    }
    /// Return clicks on release; held past the threshold it right-clicks without waiting for release.
    private func pressReturn(_ key: CapturedKey) {
        guard !key.repeatKey, pendingReturn == nil else { return }
        // Already released (the press was queued during discovery): decide from the measured hold.
        if lastReturnUp >= key.time { performClick(ReturnPress.button(heldFor: lastReturnUp - key.time), modifiers: []); return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.pendingReturn != nil else { return }
            self.pendingReturn = nil
            self.performClick(1, modifiers: [])
        }
        pendingReturn = (key.time, work)
        let remaining = max(0, ReturnPress.threshold - (ProcessInfo.processInfo.systemUptime - key.time))
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
    }
    private func returnReleased(at time: TimeInterval) {
        lastReturnUp = time
        guard let pending = pendingReturn else { return }
        pending.work.cancel(); pendingReturn = nil
        performClick(ReturnPress.button(heldFor: time - pending.down), modifiers: [])
    }
    private func performClick(_ button: Int, modifiers: KeyModifiers, count: Int = 1) {
        let generation = session.generation
        let click: (CGRect?) -> Void = { [weak self] frame in
            guard let self, self.active, self.session.generation == generation else { return }
            self.selecting = false
            if self.selectedTarget?.source == .accessibility && frame == nil { self.deferred = []; self.status = String(localized: "Target disappeared · Activate again to refresh"); self.render(); return }
            if let frame { self.mouse.move(to: CGPoint(x: frame.midX, y: frame.midY)) }
            // Order out click-through overlays before injecting mouse events; target app keeps focus.
            self.overlay.hide(); self.keyboard.setActive(false)
            self.selecting = true
            // A plain single left click (not a drop) can become a double-click with a second Return.
            let doubleable = button == 0 && modifiers.isEmpty && count == 1 && !self.mouse.holding && self.settings.returnTwiceDoubleClicks
            let point = self.mouse.point
            self.mouse.click(button: button, modifiers: modifiers, count: count) {
                guard self.session.generation == generation else { return }
                self.cancel(); self.status = String(localized: "Ready when you are")
                if doubleable { self.lastClickPoint = point; self.keyboard.armDoubleClick(interval: NSEvent.doubleClickInterval) }
            }
        }
        if let target = selectedTarget, let element = result.elements[target.id], !mouse.holding {
            selecting = true
            if button == 0 && modifiers.isEmpty && count == 1 {
                accessibility.pressTab(element, within: target.frame, generation: generation) { [weak self] pressed in
                    guard let self, self.active, self.session.generation == generation else { return }
                    if let pressed {
                        self.selecting = false
                        if pressed { self.cancel(); self.status = String(localized: "Ready when you are") }
                        else { self.deferred = []; self.status = String(localized: "Tab changed · Activate again to refresh"); self.render() }
                    } else { self.accessibility.validate(element, within: target.frame, completion: click) }
                }
            } else { accessibility.validate(element, within: target.frame, completion: click) }
        } else { click(nil) }
    }
    private func drain() {
        while active && !selecting && session.phase == .ready && !deferred.isEmpty {
            let key = deferred.removeFirst(); handle(key)
        }
    }
    private func rebuildGrid() {
        guard session.mode == .grid else { render(); return }
        let generation = session.begin(.grid)
        _ = session.publish(Geometry.grid(screens: overlay.quartzScreens, cellSize: settings.cellSize), generation: generation, vi: settings.vi)
        updateReadyStatus(); render()
    }
    /// The target window or app changed while a session was active.
    private func targetChanged(_ trigger: RefreshTrigger) {
        guard active else { return }
        let typing = !session.prefix.isEmpty || !deferred.isEmpty
        let since = ProcessInfo.processInfo.systemUptime - lastScan
        switch RefreshPolicy.decide(trigger, mode: session.mode, holding: mouse.holding, selecting: selecting, typing: typing, sinceLastScan: since) {
        case .refresh: windowChanged = true; scheduleRefresh(mode: session.mode)
        case .cancel: cancel(); status = String(localized: "The target window changed. Activate again to refresh.")
        case .ignore: break
        }
    }
    /// Debounced re-scan of the frontmost window; a partly typed label is discarded.
    private func scheduleRefresh(mode: NavigationMode = .elements, delay: TimeInterval = 0.25) {
        guard mode == .elements || mode == .scroll, !mouse.holding else { return }
        selectedTarget = nil; selectedFrame = nil
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.active, !self.selecting, !self.mouse.holding else { return }
            let notice = self.windowChanged
            self.activate(mode)
            self.windowChanged = notice
        }
        refreshWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    private func follow(_ mode: NavigationMode) {
        followMode = mode
        let expiry = DispatchWorkItem { [weak self] in self?.followMode = nil }
        followExpiry = expiry
        // Abandon the follow if no switch completes, so labels never appear unexpectedly later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: expiry)
    }
    private func clearFollow() { followMode = nil; followExpiry?.cancel(); followExpiry = nil }
    private func resumeFollow(after delay: TimeInterval) {
        guard let mode = followMode else { return }
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.followMode == mode, !self.active else { return }
            self.activate(mode)
            self.windowChanged = true
        }
        refreshWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
    private func focusScrollArea() {
        guard !result.scrollAreas.isEmpty else { return }
        if scrollUnderPointer { selectedFrame = nil; render(); return }
        let target = result.scrollAreas[scrollIndex % result.scrollAreas.count]
        // Wheel events go wherever the pointer is, so it must be inside the area to scroll it.
        let frame = target.frame
        selectedFrame = frame
        // Reached through Tab when the pointer otherwise stays put: move it to the right edge.
        let placement = settings.scrollPointer == .stay ? ScrollPointerPlacement.rightEdge : settings.scrollPointer
        if let point = placement.point(in: frame) {
            if pointerBeforeScroll == nil { pointerBeforeScroll = mouse.point }
            mouse.move(to: point)
        }
        render()
    }
    private func handleScroll(_ key: CapturedKey) {
        if key.text == "[" && key.modifiers == .control { cancel(); return }
        guard !result.scrollAreas.isEmpty else { return }
        if key.code == 48 {
            // The first Tab after scrolling under the pointer moves to the first area.
            if scrollUnderPointer { scrollUnderPointer = false; scrollIndex = 0 }
            else { scrollIndex = (scrollIndex + (key.modifiers.contains(.shift) ? result.scrollAreas.count - 1 : 1)) % result.scrollAreas.count }
            previousG = false; updateReadyStatus(); focusScrollArea(); return
        }
        let frame = result.scrollAreas[scrollIndex].frame
        // Arrows scroll like their HJKL equivalents.
        let c = ScrollKeys.letter(forArrow: key.code) ?? key.text
        let half = key.modifiers.contains(.shift)
        let dx = half ? Int(frame.width / 2) : 55
        let dy = half ? Int(frame.height / 2) : 55
        switch c {
        case "h": mouse.scroll(x: -dx, y: 0, fraction: scrollFraction)
        case "l": mouse.scroll(x: dx, y: 0, fraction: scrollFraction)
        case "j": mouse.scroll(x: 0, y: dy, fraction: scrollFraction)
        case "k": mouse.scroll(x: 0, y: -dy, fraction: scrollFraction)
        case "d": mouse.scroll(x: 0, y: Int(frame.height / 2), fraction: scrollFraction)
        case "u": mouse.scroll(x: 0, y: -Int(frame.height / 2), fraction: scrollFraction)
        case "g":
            if half { mouse.scroll(x: 0, y: 100000, instant: true) }
            else if previousG { mouse.scroll(x: 0, y: -100000, instant: true) }
            else { previousG = true; return }
        default: break
        }
        previousG = false
    }
}
