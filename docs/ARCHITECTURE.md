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
- **OCR merging:** `Geometry.mergeText` (default, toggleable) drops OCR text that is mostly inside an element, centered on an element not much larger than the text, or beside an element with the same title; `Geometry.merge` keeps only the overlap rule.
- **OCRProvider:** optional ScreenCaptureKit snapshots and local Apple Vision recognition, cancellable between operations. Selected recognition languages are grouped by `OCRLanguages` into passes (Latin/Cyrillic together, each other script separately with English) that run on the same capture; overlapping results keep the most confident reading, because one mixed-script request drops scripts after the first. Screen images are not persisted. OCR hints (indigo by default, customizable) represent text, not verified controls.
- **OverlayManager:** nonactivating click-through panels in each display's Cocoa coordinates. Target data stays in global Quartz points until drawing. A compact SwiftUI HUD uses Liquid Glass when available.
- **MouseDriver:** synthesized pointer, drag, click, and pixel-scroll events.

Target changes follow `RefreshPolicy`: in Elements and Scroll modes, a focused/main-window change, a new window, a move, resize, or close, or activating another app (including ⌘Tab / ⌘`, which pass through to macOS and resume once Command is released) re-scans the frontmost window after a 0.25 s debounce, clearing any partial label. Title-only changes (e.g. browser tabs) refresh only when nothing is being typed and at most once per second, so ticking titles cannot loop. An in-progress drag cancels; clicks in flight finish first; Grid and Freestyle ignore window changes. Per-window observers are re-armed on the newly focused window and start before discovery. Selected accessibility elements are hit-tested before selecting/clicking; changed or obscured elements require a refresh. Grid targets are explicit coordinates.

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

## Target identity and browser tabs

Accessibility hashes are used only by equality-aware collections, never as target IDs. Each scan assigns unique IDs scoped to its generation and retains the exact AX element for selection. Duplicate provider IDs are removed defensively before label assignment and rendering. Discovery uses a strict position/ID ordering.

Chrome tab-strip radio buttons inside a tab group can use AXPress for unmodified single left-clicks. Before activation, the tab must remain enabled, visible, and in Chrome's focused foreground window; stale generations are rejected. Close buttons and web-page radio controls do not enter this path. Other mouse actions retain pointer-event delivery. No fallback click is posted after an accessibility action attempt.

The label background is rendered independently of its text. Glyphs are drawn by an AppKit sibling view above the SwiftUI material host, outside the glass container. Background opacity affects only the plain tinted surface; native glass uses system-managed appearance and disables the opacity control and shortcuts. Reduce Transparency overrides opacity with an opaque surface. The status HUD follows the glass preference but not label background opacity.

Keyboard capture uses an active `.defaultTap`; the UI reports actual event-tap readiness instead of interpreting listen-only permission preflight as an independent Input Monitoring requirement. [Apple event-tap documentation](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)). Pointer-only selection validates geometry, while activation retains strict hit testing.

## Label placement and localization

`HintLayout` places each label at a preferred spot beside its element (left by default; right, above, below, or centered are options) plus user offsets in screen points, then resolves collisions. Candidates are tried nearest first: flush against each side of the element, slid along it, then half-label rings out to three labels. Label overlap and connector conflicts (a connector crossing another or passing through a label) are hard constraints; covering the label's own element, covering other elements (weighted lower), and distance form a soft cost, with a steep penalty past three label heights. Comparisons are limited to labels whose label-plus-element box can interact, and the search stops once no farther candidate can win. A swap pass exchanges same-sized labels whose connectors conflict, and a refinement pass re-places labels that still conflict once all others are known. Grid labels stay centered in their cells.

`HintLayout.colorGroups` greedily colors a neighbor graph (labels whose label-and-element areas lie within two label sizes) from an eight-hue palette, so nearby labels never share a color unless the palette is exhausted locally. When color coding is on, the overlay draws the badge outline, connector, and a box around the element in that color.

`HUDPlacement.choose` keeps the status card off visible labels, their elements, the selection, and the pointer by trying bottom center, top center, then the corners of the pointer's display.

Interface strings are English-keyed `Localizable.strings` tables in `Resources/<language>.lproj`. The in-app language choice writes `AppleLanguages` to Spray Can's own preference domain only and applies after a relaunch.
