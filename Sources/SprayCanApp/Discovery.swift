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
    /// Visible images, kept clear of labels along with text.
    var icons: [CGRect] = []
    /// Visible static text frames: exact where apps expose them, unlike visual text detection.
    var texts: [CGRect] = []
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
        // Inside a labelled row, only real controls get their own label; the row covers its cells and text.
        let rowControls: Set<String> = [kAXButtonRole, kAXCheckBoxRole, kAXRadioButtonRole, kAXPopUpButtonRole, kAXMenuButtonRole, kAXSliderRole, kAXIncrementorRole, "AXLink", "AXDisclosureTriangle"]
        func traverse(_ root: AXUIElement, pid: pid_t, clip: CGRect?, system: Bool, inRow: Bool = false, depth: Int = 0) {
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
            var childInRow = inRow
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
                    if role == kAXImageRole && clipped.width < 200 && clipped.height < 200 { result.icons.append(clipped) }
                    if role == kAXStaticTextRole { result.texts.append(clipped) }
                    if (actionable.contains(role) || names.contains(kAXPressAction) || names.contains(kAXPickAction)) && (!inRow || rowControls.contains(role)) {
                        result.targets.append(target); result.elements[id] = root
                        if role == kAXRowRole { childInRow = true }
                    }
                }
            }
            let children: [AXUIElement] = ((role == kAXTableRole || role == kAXOutlineRole) ? values[8] as? [AXUIElement] : nil) ?? values[7] as? [AXUIElement] ?? []
            for child in children { traverse(child, pid: pid, clip: childClip, system: system, inRow: childInRow, depth: depth + 1) }
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
        result.targets = TargetCollection.ordered(TargetCollection.collapsed(result.targets))
        return result
    }
}

final class OCRProvider {
    private var task: Task<Void, Never>?
    /// Languages this Mac's Vision revision can read, in Apple's order.
    static let supportedLanguages: [String] = {
        let request = VNRecognizeTextRequest()
        request.revision = VNRecognizeTextRequestRevision3
        request.recognitionLevel = .accurate
        return (try? request.supportedRecognitionLanguages()) ?? [OCRLanguages.fallback]
    }()
    /// Runs one request per language pass on the same image and keeps the most
    /// confident reading where passes overlap. Rects are normalized to the image.
    static func recognize(_ image: CGImage, languages: [String]) throws -> [OCRText] {
        var passes: [[OCRText]] = []
        for pass in OCRLanguages.passes(selected: languages, supported: supportedLanguages) {
            let request = VNRecognizeTextRequest()
            request.revision = VNRecognizeTextRequestRevision3
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = pass
            do { try VNImageRequestHandler(cgImage: image).perform([request]) }
            catch {
                // Fall back to the pass's primary language if Vision rejects the combination.
                guard pass.count > 1 else { continue }
                request.recognitionLanguages = [pass[0]]
                try VNImageRequestHandler(cgImage: image).perform([request])
            }
            passes.append((request.results ?? []).compactMap { observation in
                guard let text = observation.topCandidates(1).first else { return nil }
                return OCRText(frame: observation.boundingBox, text: text.string, confidence: text.confidence)
            })
        }
        return OCRLanguages.merge(passes)
    }
    private var detection: Task<Void, Never>?
    func cancel() { task?.cancel(); task = nil; detection?.cancel(); detection = nil }
    /// Where text is in a window, without reading it: fast enough for every scan.
    /// Calls back with nil when Screen Recording is unavailable or capture fails.
    func detectText(in region: CGRect, completion: @escaping ([CGRect]?) -> Void) {
        detection?.cancel()
        guard CGPreflightScreenCaptureAccess(), region.width > 1, region.height > 1 else { completion(nil); return }
        detection = Task {
            let rects = try? await Self.textRects(in: region)
            guard !Task.isCancelled else { return }
            await MainActor.run { completion(rects) }
        }
    }
    /// The display showing most of a window that may span several.
    static func mainDisplay(for region: CGRect, in displays: [SCDisplay]) -> SCDisplay? {
        func shown(_ display: SCDisplay) -> CGFloat {
            let part = CGDisplayBounds(display.displayID).intersection(region)
            return part.isNull ? 0 : part.width * part.height
        }
        return displays.filter { shown($0) > 0 }.max { shown($0) < shown($1) }
    }
    static func textRects(in region: CGRect) async throws -> [CGRect] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = mainDisplay(for: region, in: content.displays) else { return [] }
        let bounds = CGDisplayBounds(display.displayID)
        let area = region.intersection(bounds)
        let config = SCStreamConfiguration()
        config.sourceRect = area.offsetBy(dx: -bounds.minX, dy: -bounds.minY)
        config.width = Int(area.width * 2); config.height = Int(area.height * 2); config.showsCursor = false
        let filter = SCContentFilter(display: display, excludingApplications: content.applications.filter { $0.processID == getpid() }, exceptingWindows: [])
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        try Task.checkCancellation()
        // Fast recognition finds dim and small text more reliably than rectangle detection.
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast; request.usesLanguageCorrection = false
        let started = ProcessInfo.processInfo.systemUptime
        try VNImageRequestHandler(cgImage: image).perform([request])
        if ProcessInfo.processInfo.arguments.contains("--dump") { print("Text detection: \(Int((ProcessInfo.processInfo.systemUptime - started) * 1000)) ms") }
        return (request.results ?? []).map { observation in
            let b = observation.boundingBox
            return CGRect(x: area.minX + b.minX * area.width, y: area.minY + (1 - b.maxY) * area.height, width: b.width * area.width, height: b.height * area.height)
        }
    }
    func discover(screens: [CGRect], regions: [CGRect], languages: [String], completion: @escaping ([Target], String?) -> Void) {
        cancel()
        guard CGPreflightScreenCaptureAccess() else { completion([], String(localized: "Enable Screen Recording to use text targeting.")); return }
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
                    let recognized = try Self.recognize(image, languages: languages)
                    try Task.checkCancellation()
                    for (index, text) in recognized.enumerated() {
                        guard text.confidence >= 0.65 else { continue }
                        let b = text.frame
                        let rect = CGRect(x: bounds.minX + b.minX * bounds.width,
                                          y: bounds.minY + (1 - b.maxY) * bounds.height,
                                          width: b.width * bounds.width, height: b.height * bounds.height)
                        guard regions.contains(where: { $0.contains(CGPoint(x: rect.midX, y: rect.midY)) }) else { continue }
                        targets.append(Target(id: "text-\(display.displayID)-\(index)", frame: rect, source: .text, title: text.text))
                    }
                }
                let output = targets
                await MainActor.run { completion(output, nil) }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run { completion([], String(localized: "Text targeting unavailable. Accessibility and grid navigation still work.")) }
            }
        }
    }
}

/// Observe only the active target app; no global accessibility mutation.
/// Per-window notifications follow focus, so a newly focused window is watched too.
final class AccessibilityChanges {
    private var observer: AXObserver?
    private var app: AXUIElement?
    private var window: AXUIElement?
    private static let windowNotifications = [kAXMovedNotification, kAXResizedNotification, kAXUIElementDestroyedNotification, kAXTitleChangedNotification]
    var changed: ((RefreshTrigger) -> Void)?
    func stop() {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil; app = nil; window = nil
    }
    func start(pid: pid_t) {
        stop()
        var newObserver: AXObserver?
        guard AXObserverCreate(pid, { _, _, notification, context in
            guard let context else { return }
            Unmanaged<AccessibilityChanges>.fromOpaque(context).takeUnretainedValue().received(notification as String)
        }, &newObserver) == .success, let newObserver else { return }
        observer = newObserver
        let app = AXUIElementCreateApplication(pid)
        self.app = app
        AXUIElementSetMessagingTimeout(app, 0.06)
        for notification in [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification, kAXWindowCreatedNotification, kAXMenuOpenedNotification] {
            AXObserverAddNotification(newObserver, app, notification as CFString, context)
        }
        watchFocusedWindow()
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
    }
    private var context: UnsafeMutableRawPointer { Unmanaged.passUnretained(self).toOpaque() }
    private func watchFocusedWindow() {
        guard let observer, let app else { return }
        if let window { for notification in Self.windowNotifications { AXObserverRemoveNotification(observer, window, notification as CFString) } }
        window = axValue(app, kAXFocusedWindowAttribute)
        if let window { for notification in Self.windowNotifications { AXObserverAddNotification(observer, window, notification as CFString, context) } }
    }
    private func received(_ notification: String) {
        if notification == kAXFocusedWindowChangedNotification || notification == kAXMainWindowChangedNotification { watchFocusedWindow() }
        changed?(notification == kAXTitleChangedNotification ? .title : .structural)
    }
    deinit { stop() }
}
