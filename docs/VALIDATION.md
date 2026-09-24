# Validation status

Tested on 2026-09-23 using macOS 27.0 (26A428), Apple Silicon, Xcode 27.0 (27A266a), with a macOS 14 deployment target. Build compatibility is broader than the runtime environments verified here.

## Automated and live results

| Check | Result |
| --- | --- |
| Core suite | 9 tests, zero failures |
| Immediate-input state-machine stress | 1,000 cycles, zero lost/duplicated selections |
| Real event-tap → accessibility → pointer → native button | 30 cycles passed |
| Real immediate grid shortcut + label + Return | 30 cycles passed |
| Leaked navigation characters in fixture field | Zero |
| Held activation modifiers | Alternated on every live cycle; passed |
| Cursor directly over selected control on next activation | Passed after excluding WindowServer cursor windows from occlusion |
| Universal application build | arm64 and x86_64 |
| Extracted release ZIP signature | Ad-hoc signature verified with `codesign --verify --deep --strict` |
| OCR fixture | All four expected strings found: Projects, Research, Personal, Documents |
| Documentation views | Settings, element/grid overlays, and illustrated workflow GIFs rendered and inspected |

The core stress test exercises buffered labels and stale generations independently of macOS. The live harness activates the real event tap, reads current element labels, injects mouse events, and checks a separate native fixture process's click counter. For grid cycles, it injects the known deterministic label immediately after activation, before waiting for the overlay. It aborts if focus leaves the fixture and restores settings afterward.

The first cold OCR smoke run took approximately 63 seconds in this environment, including Vision initialization; it is **not** evidence of interactive OCR performance. OCR is optional and asynchronous, and never blocks accessibility/grid input. Measure warm performance on target machines before treating OCR latency as validated.

## Reproduce

```sh
scripts/test.sh
scripts/integration-test.sh
swift scripts/ocr-smoke.swift
scripts/release.sh 0.1.0 adhoc
```

Live tests need an interactive desktop and Accessibility/Input Monitoring for the executing app/terminal. They create a temporary fixture with synthetic controls, inject input only while it is frontmost, then close it. They do not click personal documents or browser content.

## Still requires manual acceptance

These are unverified, not implied by a successful compile:

| Environment | Required scenarios | Status |
| --- | --- | --- |
| macOS 14 / 15 | Materials fallback, permissions, native controls | Pending |
| macOS 26 | Liquid Glass appearance and complete navigation | Pending |
| Intel Mac | Launch and full interaction | Pending; binary built |
| Finder | List/icon views, rename fields, context menus, real drag/drop | Pending |
| Safari / Chrome | Links, form controls, long pages, tabs | Pending |
| System Settings | Nested panes, toggles, sheets | Pending |
| VS Code | Editor/sidebar controls, Electron accessibility | Pending |
| Menus / Dock / Control Center | Open menus, status items, Dock targets | Pending |
| Displays and Spaces | Mixed scaling, negative origins, fullscreen, hot-plug | Geometry tests pass; live acceptance pending |
| OCR capture | Permission changes, screen capture, late-result behavior, warm latency | Core merge and offline recognition pass; capture acceptance pending |
| Lifecycle | Sleep/wake, Secure Input, tap disable/recovery, permission revocation | Recovery paths implemented; manual fault injection pending |
| Signed distribution | Developer ID, notarization, fresh-machine Gatekeeper | Pending credentials |

## Release gate

Version 0.1.0 ships with the limitations above explicitly documented. To broaden compatibility confidence, complete the runtime matrix, verify capture permissions and warm OCR latency, test real drag/drop and modified/right/middle/double clicks, exercise cancellation during drag, and run installation/uninstallation on a clean Mac. No universal clickable-element coverage claim is made.

## Appearance and community update — 2026-09-23

The universal build passed with native Liquid Glass hint views, five persistent sRGB color preferences, and the About support link. The core suite now contains 10 passing tests, including invalid/missing color defaults and sRGB normalization. A separate live run passed 30 element and 30 immediate grid click cycles with no leaked characters or duplicate clicks. An earlier run correctly aborted when a documentation window took focus; it was rerun without concurrent window rendering.

Documentation images now capture only synthetic windows through ScreenCaptureKit, because view bitmap caching omits WindowServer-composited glass. Appearance and About images were visually inspected. The built bundle's universal architectures and ad-hoc signature were verified. Older-macOS material fallback, Reduce Transparency, custom-color persistence across a full application relaunch, and mixed-display glass appearance still require manual acceptance. No new release was published.

## Adaptive label placement — 2026-09-23

The core suite now has 15 passing tests. New geometry coverage includes vertical/horizontal clusters, coincident targets, corners, translated display origins, fixed grid centers, connector endpoints, deterministic ordering, and best-effort handling of impossible density. Placement is cached for the full target set before prefix filtering. The universal build passed; the native live fixture again completed 30 element and 30 immediate grid click cycles without missed/duplicate clicks or leaked characters. The synthetic cluster image was rendered and visually inspected: vertical controls use side offsets, horizontal controls use above/below offsets, and connector dots identify the original target centers. Physical multi-display and arbitrary third-party dense-control acceptance remain pending.

## Browser and appearance fixes — 2026-09-24

- The crash report from September 23 identified `Dictionary.init(uniqueKeysWithValues:)` in `HintCanvas.layout()` as the fatal duplicate-key trap. Accessibility identity now uses equality-aware, generation-scoped unique IDs instead of `CFHash` values. Defensive deduplication precedes labels/rendering, and discovery sorting is transitive.
- All 18 core tests passed, including deliberate hash collisions, repeated IDs, and deterministic ordering. The universal app built successfully; a clean staged copy and the installed app passed architecture and ad-hoc signature verification.
- A disposable Chrome window passed discovery, tab revalidation, AXPress activation, and the selected-state assertion. A later repeat fixture failed to expose its named tab within the scan period; this is recorded rather than treated as a universal Chrome pass. Pinned/reordered/removed tabs, tab close buttons, and obscured/modified-click browser cases still need broader manual acceptance.
- Bilibili's homepage completed five accessibility discovery/layout cycles with 140 unique targets, then five further cycles with 139 unique targets. On-device OCR returned 198 unique text targets that also completed label assignment/layout. This verifies the previously failing identity/layout path, not every possible page state.
- The live native fixture passed 30 element and 30 immediate grid click cycles with no missed/duplicate clicks or leaked characters.
- Synthetic window captures at 40% and 100% background opacity were inspected with glass enabled and disabled. Text remains separate from the faded background. The opacity and glass preferences were read back through fresh Settings instances, and the runner restored the original values afterward. The two-column color controls and glass-off switch were visually inspected. System Reduce Transparency and cross-version appearance still require manual acceptance.

The local app was updated with a backup of the previous bundle. These changes have not been released or published to the Homebrew tap.

## Glass text, keyboard status, and first-entry movement — 2026-09-24

Label letters now render in a transparent AppKit foreground view above the native glass hosting view. Composited captures using the actual HintCanvas in a nonactivating panel show visible letters with glass enabled at 40% and 100% background opacity; the glyph layer never inherits material opacity. Glass-off behavior is retained.

The misleading Input Monitoring permission row and listen-access preflight gate were removed. Keyboard capture reports the actual active event tap, Accessibility state, and Secure Input availability. Accessibility and optional Screen Recording have separate request/open-settings actions. This app uses an active `.defaultTap`, not a passive listen-only tap. Fresh-install/revocation checks across older macOS versions remain manual.

Completing an element label now validates its bounds without requiring click-level hit testing. Actual clicks still revalidate the hit target. A disposable Bilibili window passed 12 cursor-movement checks, each with exactly one label entry and no clicks posted. The full 18-test suite and 60-cycle live keyboard/click harness passed. The universal build and installed app signature verified.

The ignored `build/Test/Spray Can.app` path now links to the installed app in `~/Applications`, avoiding FileProvider metadata that repeatedly invalidated signatures inside the project directory. Previous app copies were preserved outside the repository. No app bundle was staged or committed, and no release was published.

## Glass opacity policy — 2026-09-24

The background-opacity slider is now disabled whenever Use Liquid Glass or Reduce Transparency is enabled. Glass renders at its native material opacity, and opacity shortcuts explain the restriction instead of changing an ineffective saved value. Turning glass off restores the saved opacity for plain backgrounds. This supersedes the earlier attempt to fade native glass through an outer opacity modifier. The universal app build is used to validate this small UI change.
