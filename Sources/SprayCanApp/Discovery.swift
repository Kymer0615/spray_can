import AppKit
import ApplicationServices
import ScreenCaptureKit
import Vision
import SprayCanCore

struct DiscoveryContext {
    let pid: pid_t
    let screens: [CGRect]
    let allWindows: Bool
    let generation: Int
}
struct DiscoveryResult {
    var targets: [Target] = []
    var scrollAreas: [Target] = []
    var elements: [String: AXUIElement] = [:]
    var captureRects: [CGRect] = []
    var timedOut = false
    var needsRetry = false
}
protocol TargetProvider {
    func discover(_ context: DiscoveryContext, completion: @escaping (DiscoveryResult) -> Void)
}

func axValue<T>(_ element: AXUIElement, _ attribute: String) -> T? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value as? T
}
func axFrame(_ element: AXUIElement) -> CGRect? {
    guard let position: AXValue = axValue(element, kAXPositionAttribute),
          let size: AXValue = axValue(element, kAXSizeAttribute),
          AXValueGetType(position) == .cgPoint, AXValueGetType(size) == .cgSize else { return nil }
    var point = CGPoint.zero; var dimensions = CGSize.zero
    guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &dimensions) else { return nil }
    let rect = CGRect(origin: point, size: dimensions)
    return rect.isInfinite || rect.isNull ? nil : rect
}

final class AccessibilityProvider: TargetProvider {
    private let queue = DispatchQueue(label: "SprayCan.accessibility", qos: .userInitiated)
    private let generationLock = NSLock()
    private var latestGeneration = 0
    func invalidate(_ generation: Int) { generationLock.lock(); latestGeneration = generation; generationLock.unlock() }
    private func current(_ generation: Int) -> Bool {
        generationLock.lock(); defer { generationLock.unlock() }; return latestGeneration == generation
    }
    func discover(_ context: DiscoveryContext, completion: @escaping (DiscoveryResult) -> Void) {
        invalidate(context.generation)
        queue.async {
            var result = self.scan(context, budget: 0.85)
            if (result.needsRetry || result.timedOut || result.targets.isEmpty), self.current(context.generation) {
                // Cold accessibility servers can initialize after the first request.
                // Retry within the same activation, while keyboard input stays buffered.
                Thread.sleep(forTimeInterval: 0.05)
                let retry = self.scan(context, budget: 2.0)
                if !retry.targets.isEmpty || result.targets.isEmpty { result = retry }
            }
            let completed = result
            DispatchQueue.main.async { completion(completed) }
        }
    }
    /// Chrome exposes tab-strip tabs as radio buttons inside a tab group.
    private func tabWindow(_ element: AXUIElement) -> AXUIElement? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success,
              NSRunningApplication(processIdentifier: pid)?.bundleIdentifier?.hasPrefix("com.google.Chrome") == true,
              ["AXRadioButton", "AXTab"].contains(axValue(element, kAXRoleAttribute) as String? ?? "") else { return nil }
        var node: AXUIElement? = element
        var group = false
        for _ in 0..<20 {
            guard let current = node else { return nil }
            let role: String = axValue(current, kAXRoleAttribute) ?? ""
            if role == "AXWebArea" { return nil }
            if role == "AXTabGroup" { group = true }
            if role == kAXWindowRole { return group ? current : nil }
            node = axValue(current, kAXParentAttribute)
        }
        return nil
    }
    private func visibleTab(_ element: AXUIElement, frame: CGRect) -> Bool {
        guard let window = tabWindow(element),
              !(axValue(element, "AXHidden") as Bool? ?? false),
              axValue(element, kAXEnabledAttribute) as Bool? ?? true else { return false }
        var pid: pid_t = 0; AXUIElementGetPid(element, &pid)
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let focused: AXUIElement = axValue(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute), CFEqual(window, focused),
              let windowFrame = axFrame(window), windowFrame.contains(CGPoint(x: frame.midX, y: frame.midY)) else { return false }
        // A tab must still belong to the visible tab strip (including scroll clipping).
        var node: AXUIElement? = element
        for _ in 0..<20 {
            guard let current = node else { return false }
            if CFEqual(current, window) { break }
            if axValue(current, "AXHidden") as Bool? == true { return false }
            if axValue(current, kAXRoleAttribute) as String? == kAXScrollAreaRole,
               let clip = axFrame(current), !clip.contains(CGPoint(x: frame.midX, y: frame.midY)) { return false }
            node = axValue(current, kAXParentAttribute)
        }
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(frame.midX), Float(frame.midY), &hit) == .success else { return false }
        // Accept Chrome's container hit-test result only in the same focused window.
        for _ in 0..<24 {
            guard let current = hit else { return false }
            if CFEqual(current, window) { return true }
            hit = axValue(current, kAXParentAttribute)
        }
        return false
    }
    /// nil means this isn't an actionable browser tab; false means validation/action failed.
    func pressTab(_ element: AXUIElement, within original: CGRect, generation: Int, completion: @escaping (Bool?) -> Void) {
        queue.async {
            guard self.current(generation) else { DispatchQueue.main.async { completion(false) }; return }
            guard self.tabWindow(element) != nil else { DispatchQueue.main.async { completion(nil) }; return }
            var actions: CFArray?
            AXUIElementCopyActionNames(element, &actions)
            guard (actions as? [String] ?? []).contains(kAXPressAction) else { DispatchQueue.main.async { completion(nil) }; return }
            guard let frame = axFrame(element), original.contains(CGPoint(x: frame.midX, y: frame.midY)), self.visibleTab(element, frame: frame), self.current(generation) else {
                DispatchQueue.main.async { completion(false) }; return
            }
            let success = AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
            DispatchQueue.main.async { completion(success) }
        }
    }
    func validate(_ element: AXUIElement, within original: CGRect, hitTest: Bool = true, completion: @escaping (CGRect?) -> Void) {
        queue.async {
            let enabled: Bool = axValue(element, kAXEnabledAttribute) ?? true
            var frame = enabled ? axFrame(element) : nil
            if let current = frame {
                // Preserve the visible portion of partially clipped controls; reject relocated targets.
                let clipped = current.intersection(original)
                if clipped.isNull || clipped.width < 2 || clipped.height < 2 { frame = nil }
                else if !hitTest {
                    // Moving the pointer is not an activation. Dynamic browser descendants
                    // can fail hit testing until hovered; enforce hit testing when clicking.
                    frame = clipped
                } else {
                    frame = clipped
                    let system = AXUIElementCreateSystemWide()
                    AXUIElementSetMessagingTimeout(system, 0.06)
                    var hit: AXUIElement?
                    let error = AXUIElementCopyElementAtPosition(system, Float(clipped.midX), Float(clipped.midY), &hit)
                    var matches = false
                    if error == .success {
                        for _ in 0..<12 {
                            guard let node = hit else { break }
                            if CFEqual(node, element) { matches = true; break }
                            hit = axValue(node, kAXParentAttribute)
                        }
                    }
                    if !matches && !self.visibleTab(element, frame: clipped) { frame = nil }
                }
            }
            DispatchQueue.main.async { completion(frame) }
        }
    }
    private func scan(_ context: DiscoveryContext, budget: TimeInterval) -> DiscoveryResult {
        var result = DiscoveryResult()
        let started = ProcessInfo.processInfo.systemUptime
        let deadline = started + budget
        let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []).filter {
            ($0[kCGWindowOwnerPID as String] as? Int32) != getpid() &&
            ($0[kCGWindowAlpha as String] as? Double ?? 1) > 0 &&
            // WindowServer exposes the cursor as a window; it never occludes a control.
            ($0[kCGWindowLayer as String] as? Int ?? 0) < Int(CGWindowLevelForKey(.cursorWindow))
        }
        func topOwner(at point: CGPoint) -> pid_t? {
            for window in windows {
                guard let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                      let rect = CGRect(dictionaryRepresentation: bounds), rect.contains(point) else { continue }
                return window[kCGWindowOwnerPID as String] as? pid_t
            }
            return nil
        }
        var seen = Set<AXUIElement>()
        var identities = DiscoveryIdentity<AXUIElement>(namespace: "ax-\(context.generation)")
        var count = 0
        let actionable: Set<String> = [kAXButtonRole, kAXCheckBoxRole, kAXRadioButtonRole, kAXPopUpButtonRole, kAXMenuButtonRole, kAXMenuItemRole, kAXTextFieldRole, kAXTextAreaRole, kAXSliderRole, kAXIncrementorRole, "AXLink", kAXCellRole, kAXRowRole, "AXTab", "AXDockItem", "AXDisclosureTriangle", "AXHandle"]
        func traverse(_ root: AXUIElement, pid: pid_t, clip: CGRect?, system: Bool, depth: Int = 0) {
            guard self.current(context.generation), ProcessInfo.processInfo.systemUptime < deadline, count < 6000 else { result.timedOut = true; return }
            guard depth < 80, seen.insert(root).inserted else { return }
            count += 1
            let attributes = [kAXRoleAttribute, kAXPositionAttribute, kAXSizeAttribute,
                              "AXHidden", kAXEnabledAttribute, kAXTitleAttribute,
                              kAXDescriptionAttribute, kAXChildrenAttribute, kAXVisibleRowsAttribute]
            var raw: CFArray?
            guard AXUIElementCopyMultipleAttributeValues(root, attributes as CFArray, [], &raw) == .success,
                  let values = raw as? [Any], values.count == attributes.count else { result.needsRetry = true; return }
            let role = values[0] as? String ?? ""
            if role.isEmpty { result.needsRetry = true }
            let hidden = values[3] as? Bool ?? false
            guard !hidden else { return }
            var batchedFrame: CGRect?
            if CFGetTypeID(values[1] as CFTypeRef) == AXValueGetTypeID(), CFGetTypeID(values[2] as CFTypeRef) == AXValueGetTypeID() {
                let position = values[1] as! AXValue, size = values[2] as! AXValue
                var point = CGPoint.zero, dimensions = CGSize.zero
                if AXValueGetType(position) == .cgPoint, AXValueGetType(size) == .cgSize,
                   AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &dimensions) {
                    batchedFrame = CGRect(origin: point, size: dimensions)
                }
            }
            let frame = batchedFrame
            // Closed menu trees can contain thousands of invisible items.
            // Their zero-sized root is not a frame-less layout wrapper.
            if role == kAXMenuRole, frame == nil || frame!.isEmpty { return }
            var childClip = clip
            if let frame, frame.width > 1, frame.height > 1 {
                let clipped = clip.map { frame.intersection($0) } ?? frame
                // Frame-less/zero-sized wrappers still have useful children.
                if clipped.isNull { return }
                if role == kAXScrollAreaRole || role == kAXWindowRole { childClip = clipped }
                let onScreen = context.screens.contains { $0.intersects(clipped) }
                let visible = onScreen && (system || topOwner(at: CGPoint(x: clipped.midX, y: clipped.midY)) == pid)
                let enabled = values[4] as? Bool ?? true
                if visible && enabled {
                    var actions: CFArray?
                    if !actionable.contains(role) { AXUIElementCopyActionNames(root, &actions) }
                    let names = actions as? [String] ?? []
                    let title = values[5] as? String ?? values[6] as? String ?? ""
                    let id = identities.id(for: root)
                    let target = Target(id: id, frame: clipped, source: .accessibility, title: title, role: role)
                    if role == kAXScrollAreaRole { result.scrollAreas.append(target) }
                    if actionable.contains(role) || names.contains(kAXPressAction) || names.contains(kAXPickAction) {
                        // Don't drop overlapping parent/child controls solely to make labels prettier.
                        result.targets.append(target); result.elements[id] = root
                    }
                }
            }
            let children: [AXUIElement] = ((role == kAXTableRole || role == kAXOutlineRole) ? values[8] as? [AXUIElement] : nil) ?? values[7] as? [AXUIElement] ?? []
            for child in children { traverse(child, pid: pid, clip: childClip, system: system, depth: depth + 1) }
        }
        let activeApp = AXUIElementCreateApplication(context.pid)
        AXUIElementSetMessagingTimeout(activeApp, 0.20)
        // Reading role wakes Chromium's basic accessibility support without global VoiceOver emulation.
        let _: String? = axValue(activeApp, kAXRoleAttribute)
        let focused: AXUIElement? = axValue(activeApp, kAXFocusedWindowAttribute) ?? axValue(activeApp, kAXMainWindowAttribute) ?? (axValue(activeApp, kAXWindowsAttribute) as [AXUIElement]?)?.first
        if focused == nil { result.needsRetry = true }
        if let focused {
            if let rect = axFrame(focused) { result.captureRects.append(rect) }
            traverse(focused, pid: context.pid, clip: axFrame(focused), system: false)
        }
        if let menu: AXUIElement = axValue(activeApp, kAXMenuBarAttribute) { traverse(menu, pid: context.pid, clip: nil, system: true) }
        // Active menus can be attached to the app, outside its focused-window subtree.
        let appChildren: [AXUIElement] = axValue(activeApp, kAXChildrenAttribute) ?? []
        for child in appChildren {
            let role: String = axValue(child, kAXRoleAttribute) ?? ""
            if role == kAXMenuRole || role == kAXSheetRole || role == "AXPopover" { traverse(child, pid: context.pid, clip: nil, system: true) }
        }
        let apps = NSWorkspace.shared.runningApplications
        for app in apps where app.processIdentifier != getpid() {
            let isSystem = ["com.apple.dock", "com.apple.systemuiserver", "com.apple.controlcenter"].contains(app.bundleIdentifier ?? "")
            guard isSystem || context.allWindows else { continue }
            if !self.current(context.generation) || ProcessInfo.processInfo.systemUptime > deadline { result.timedOut = true; break }
            let root = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(root, 0.04)
            if isSystem { traverse(root, pid: app.processIdentifier, clip: nil, system: true) }
            else {
                let appWindows: [AXUIElement] = axValue(root, kAXWindowsAttribute) ?? []
                for window in appWindows {
                    let minimized: Bool = axValue(window, kAXMinimizedAttribute) ?? false
                    guard !minimized else { continue }
                    traverse(window, pid: app.processIdentifier, clip: axFrame(window), system: false)
                    if let frame = axFrame(window) { result.captureRects.append(frame) }
                }
            }
        }
        result.targets = TargetCollection.ordered(result.targets)
        return result
    }
}

final class OCRProvider {
    private var task: Task<Void, Never>?
    func cancel() { task?.cancel(); task = nil }
    func discover(screens: [CGRect], regions: [CGRect], completion: @escaping ([Target], String?) -> Void) {
        cancel()
        guard CGPreflightScreenCaptureAccess() else { completion([], "Enable Screen Recording to use text targeting."); return }
        task = Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let ownApps = content.applications.filter { $0.processID == getpid() }
                var targets: [Target] = []
                for display in content.displays {
                    try Task.checkCancellation()
                    let bounds = CGDisplayBounds(display.displayID)
                    guard screens.contains(where: { $0.intersects(bounds) }) else { continue }
                    let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
                    let config = SCStreamConfiguration()
                    // OCR at native logical resolution keeps processing bounded on Retina displays.
                    config.width = Int(bounds.width); config.height = Int(bounds.height); config.showsCursor = false
                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.usesLanguageCorrection = false
                    try VNImageRequestHandler(cgImage: image).perform([request])
                    try Task.checkCancellation()
                    for (index, observation) in (request.results ?? []).enumerated() {
                        guard let text = observation.topCandidates(1).first, text.confidence >= 0.65 else { continue }
                        let b = observation.boundingBox
                        let rect = CGRect(x: bounds.minX + b.minX * bounds.width,
                                          y: bounds.minY + (1 - b.maxY) * bounds.height,
                                          width: b.width * bounds.width, height: b.height * bounds.height)
                        guard regions.contains(where: { $0.contains(CGPoint(x: rect.midX, y: rect.midY)) }) else { continue }
                        targets.append(Target(id: "text-\(display.displayID)-\(index)", frame: rect, source: .text, title: text.string))
                    }
                }
                let output = targets
                await MainActor.run { completion(output, nil) }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run { completion([], "Text targeting unavailable. Accessibility and grid navigation still work.") }
            }
        }
    }
}

/// Observe only the active target app; no global accessibility mutation.
final class AccessibilityChanges {
    private var observer: AXObserver?
    var changed: (() -> Void)?
    func stop() {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil
    }
    func start(pid: pid_t) {
        stop()
        var newObserver: AXObserver?
        guard AXObserverCreate(pid, { _, _, _, context in
            guard let context else { return }
            Unmanaged<AccessibilityChanges>.fromOpaque(context).takeUnretainedValue().changed?()
        }, &newObserver) == .success, let newObserver else { return }
        observer = newObserver
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.06)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for notification in [kAXFocusedWindowChangedNotification, kAXWindowCreatedNotification, kAXMenuOpenedNotification] {
            AXObserverAddNotification(newObserver, app, notification as CFString, context)
        }
        if let window: AXUIElement = axValue(app, kAXFocusedWindowAttribute) {
            for notification in [kAXMovedNotification, kAXResizedNotification, kAXUIElementDestroyedNotification] {
                AXObserverAddNotification(newObserver, window, notification as CFString, context)
            }
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
    }
    deinit { stop() }
}
