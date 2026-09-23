# Validation status

Tested on 2026-09-23 using macOS 27.0 (26A428), Apple Silicon, Xcode 27.0 (27A266a), with a macOS 14 deployment target. Preview status is intentional: build compatibility is broader than the runtime environments verified here.

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
| Extracted preview ZIP signature | Ad-hoc signature verified with `codesign --verify --deep --strict` |
| OCR fixture | All four expected strings found: Projects, Research, Personal, Documents |
| Documentation views | Settings, element/grid overlays, and illustrated workflow GIFs rendered and inspected |

The core stress test exercises buffered labels and stale generations independently of macOS. The live harness activates the real event tap, reads current element labels, injects mouse events, and checks a separate native fixture process's click counter. For grid cycles, it injects the known deterministic label immediately after activation, before waiting for the overlay. It aborts if focus leaves the fixture and restores settings afterward.

The first cold OCR smoke run took approximately 63 seconds in this environment, including Vision initialization; it is **not** evidence of interactive OCR performance. OCR is optional and asynchronous, and never blocks accessibility/grid input. Measure warm performance on target machines before treating OCR latency as validated.

## Reproduce

```sh
scripts/test.sh
scripts/integration-test.sh
swift scripts/ocr-smoke.swift
scripts/release.sh 0.1.0-preview.1 preview
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

A preview may carry the above limitations explicitly. Before a stable release, complete the runtime matrix, verify capture permissions and warm OCR latency, test real drag/drop and modified/right/middle/double clicks, exercise cancellation during drag, and run installation/uninstallation on a clean Mac. No universal clickable-element coverage claim is made.
