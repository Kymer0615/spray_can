# Architecture and reference research

## References inspected

- Scoot `AppDelegate.swift`, `Accessibility.swift`, `KeyboardInputWindow.swift`, `KeyboardInputWindow+Keyboard.swift`, and README at commit `80beb3a787932c7714a4da1691760a487c722d2e`.
- Vimac `GlobalEventTap.swift`, `ModeCoordinator.swift`, `HintModeQueryService.swift`, generic element traversal, manual, and non-native support notes from its master branch.

Scoot enumerates focused-window accessibility before activating its keyboard-input window and queues key-window activation asynchronously. Its label branch requires empty modifiers. These are plausible contributors to the reported lost-input behavior, not a reproduced diagnosis on the user's system. Its current source maps Shift–Return to a modified click despite conflicting prose in the README.

Vimac demonstrates focus-independent event capture, separate system-UI discovery, and visible-row traversal. Its historical non-native-support notes describe side effects of global VoiceOver emulation. Spray Can uses an independent implementation, without copying either project's source or assets.

## Responsibilities

- **SprayCanCore:** value types, generation-scoped session reducer, deterministic fixed-length prefix-free labels, key mapping, coordinate conversion, OCR deduplication.
- **KeyboardCapture:** session event tap on a dedicated run loop. A lock protects only capture state; handlers enqueue main-thread work. Carbon registration detects shortcut conflicts. Idle events pass through without storage. Matching key-up events are swallowed for consumed keys.
- **AppController:** serial UI/session coordination, early-input queue, click sequencing, cancellation, and stale-result guards.
- **AccessibilityProvider:** cancellable generation-scoped scans with an 850 ms initial scan budget and one bounded 2 s retry for a cold/incomplete accessibility server, per-app messaging timeouts, cycle/depth/node limits, clipping, and action/role discovery. Reads are batched; closed menu trees are skipped. Cursor-layer windows are excluded from occlusion checks. System roots include menu bar, Dock, and Control Center. Partial results remain usable.
- **OCRProvider:** optional ScreenCaptureKit snapshots and local Apple Vision recognition, cancellable between operations. Screen images are not persisted. OCR hints (indigo by default, customizable) represent text, not verified controls.
- **OverlayManager:** nonactivating click-through panels in each display's Cocoa coordinates. Target data stays in global Quartz points until drawing. A compact SwiftUI HUD uses Liquid Glass when available.
- **MouseDriver:** synthesized pointer, drag, click, and pixel-scroll events.

Accessibility changes in the active application trigger a refresh when no label prefix is in progress. Relevant changes during typing/dragging cancel the session to avoid retargeting. Selected accessibility elements are hit-tested before selecting/clicking; changed or obscured elements require a refresh. Grid targets are explicit coordinates.

## Input ordering

Activation arms capture synchronously in the event callback. Subsequent input is delivered in order to the main queue and buffered until discovery is ready. Labels are immutable after the first character, including after a complete selection. Selection validation serializes subsequent commands so an immediately following Return cannot race the pointer move. Session cancellation increments a generation; all asynchronous completions check it.

Inherited activation modifiers are tracked until released. They are ignored for label matching only. Click modifiers are preserved intentionally. A physical Latin label alphabet avoids silently changing a user's input method; customizable character-layout label mapping is not yet implemented.

## Privacy and boundaries

No network clients or analytics SDKs are linked by the app. Opening documentation is an explicit browser action. All OCR is local. The event callback neither logs nor retains idle keystrokes. Diagnostics contain timings, target counts, and bounded-scan status, not content.

Secure Input and macOS permissions can block input capture. Recovery reports unavailability and may require a new activation. System-wide semantic recognition is not promised: inaccessible icons, custom canvases, protected content, and remote UI may need the grid.

## Official API references

- [Apple: ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [Apple: recognizing text in images](https://developer.apple.com/documentation/vision/recognizing-text-in-images)
- [Apple: Liquid Glass modifier](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- [Apple: event tap disabled by timeout](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout)

## Adaptive hint placement

`HintLayout` is a pure geometry helper in the core package. It receives target rectangles and measured badge sizes in display-local coordinates and returns badge frames, unchanged target anchors, and connector endpoints. Candidate positions are constrained to a four-point display inset before scoring overlaps, connector crossings, preferred cluster axis, and distance. Stable IDs break ties. Search is bounded to three badge-sized steps; impossible density retains every target with a best-effort placement.

The overlay receives the full session target set and caches placements by geometry and badge size. Prefix filtering affects visibility only, so surviving hints do not move while typing. Grid hints remain centered, and selection/click coordinates continue to come from the original target. Native glass badges sit above the canvas-drawn connectors and endpoint dots.
