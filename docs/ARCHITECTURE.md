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

`HintLayout` places each label touching its element without covering the element's text or icon; overlapping the element's padding is fine. Content to keep clear comes from three sources: accessibility `AXStaticText` and `AXImage` frames from the scan, fast on-device text recognition of the target window (run alongside the scan, about 0.1 s, only to find where text is), and estimates. `HintLayout.textContent` prefers tight detected boxes over accessibility frames padded to a column's width, and keeps accessibility frames where detection missed dim or small text. When no text is known inside an element, a compact titled control keeps its whole frame clear; anything else keeps an estimate (a left band for wide rows, the middle otherwise) clear. The space before an element's first text is treated as its icon.

Candidates are generated around the element's main text (right after it on the same line first), on its inner corners and edges, straddling its edges, flush outside it, and finally on half-label rings that need a connector. Hard constraints, in order: no overlap with other labels, no covering of text or icons, no connector conflicts. Then cost: distance from the element (anything within the 2 pt gap counts as touching), lightly penalized overlap with other elements, and the preferred side (Left, Right, Above, Below, On) as a tie-breaker. A label is displaced, and draws a connector, only when it does not touch its element. A swap pass exchanges same-sized labels whose connectors conflict, and a bounded refinement pass re-places conflicting labels once all others are known. Real windows lay out in a few milliseconds.

Before placement, `TargetCollection.collapsed` drops a wrapper that is visually the same control as a smaller one inside it, and a row that only wraps one control. Inside a labelled row, only real controls (buttons, checkboxes, pop-ups, links, disclosure triangles) get their own label.

`scripts/snapshot-labels.sh <bundle id> <out.png>` runs a real discovery of an app's focused window and renders the labels over a capture of it, for checking readability by eye; `--prefix ab` shows the state after typing and `--dump` prints targets and content rects. Grid labels stay centered in their cells.

`HintLayout.colorGroups` colors a neighbor graph (labels whose label-and-element areas lie within two label sizes) from an eight-hue palette. Labels with the most neighbors go first; each takes the color whose smallest CIELAB difference (ΔE) to its neighbors' colors is largest, where a neighbor's distance adds up to 20 to that difference, so the nearest neighbors get the most contrasting hues. With color coding on, each element badge is a solid fill in its color (glass would wash it out; text is black or white by luminance), connectors use it, elements are shaded in it (Always, While typing, or Off, at an adjustable opacity, lighter on large panes), and while a prefix is typed the remaining elements are outlined in it. Typed letters on colored badges are dimmed rather than highlighted. OCR badges keep their own tint.

`HUDPlacement.choose` keeps the status card off visible labels, their elements, the selection, and the pointer by trying bottom center, top center, then the corners of the pointer's display.

Interface strings are English-keyed `Localizable.strings` tables in `Resources/<language>.lproj`. The in-app language choice writes `AppleLanguages` to Spray Can's own preference domain only and applies after a relaunch.
