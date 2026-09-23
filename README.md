<p align="center"><img src="docs/images/icon.png" width="112" alt="Spray Can app icon"></p>
<h1 align="center">Spray Can</h1>
<p align="center"><strong>Point. Type. Click.</strong><br>Keyboard-driven navigation, built for your Mac.</p>
<p align="center">macOS 14+ · Apple Silicon & Intel · Swift + AppKit · Local processing</p>

![Element navigation](docs/images/elements.png)

Spray Can lets you move, click, drag, and scroll without reaching for the mouse. Press **⇧⌘J**, type a label, then press **Return** to click. Familiar [Scoot](https://github.com/mjrusso/scoot) shortcuts meet a native interface, with Liquid Glass on macOS 26 and later.

**Preview software:** the navigation core is tested, including 1,000 rapid activation cycles. A live native fixture also passed 60 element/grid click cycles without missed clicks or leaked input. End-to-end compatibility across third-party apps is still being validated. See [validation status](docs/VALIDATION.md); this is not a claim that every macOS control is discoverable.

## Four ways to move

- **Elements · ⇧⌘J:** labels on accessible controls in the active window, menus, and system UI. Optionally include other visible windows.
- **Grid · ⇧⌘K:** target any location across connected displays, even in apps with no accessibility support.
- **Freestyle · ⇧⌘L:** nudge the pointer with keyboard commands without a grid.
- **Scroll · ⌃J:** HJKL scrolling, Tab to switch scroll areas, half-page and top/bottom movement, inspired by [Vimac](https://github.com/nchudleigh/vimac).

![Element workflow](docs/images/element-demo.gif)

*Documentation visuals render the application's actual hint and settings views over synthetic example content. Animations illustrate the key sequence; they are not recordings of third-party application tests.*

## Reliable activation by design

Keyboard capture does not depend on an overlay becoming the key window. A dedicated event tap starts the session immediately, queues early input while discovery runs, and tracks modifier releases. Old discovery results cannot overwrite a new session, and late OCR results cannot reassign labels after typing starts.

The target application keeps focus. Accessibility scans are bounded and run off the UI thread. Selected accessible controls are checked again before clicking. Input restrictions such as Secure Input and revoked permissions are reported rather than treated as working navigation.

## Accessibility + text recognition + grid

Accessibility is the primary source of targets. Traversal considers supported actions, visible rows, clipping, menus, fields, and other actionable roles. It does not globally enable VoiceOver emulation in every application.

Optional **on-device text recognition** uses ScreenCaptureKit and Apple Vision OCR. It adds purple text-location labels where accessibility has no matching target. OCR recognizes text; it does **not** determine whether text is clickable or detect every unlabeled icon. A dedicated learned UI detector is not included in this release. The grid is always available for unsupported content.

Screenshots are processed in memory and discarded. No analytics, cloud inference, or screenshot logs. Session diagnostics record timing and counts only.

## Install

Download the universal ZIP from [Releases](https://github.com/Kymer0615/spray_can/releases), extract it, and move **Spray Can.app** into Applications. Preview releases are ad-hoc signed, **not Developer ID signed or notarized**. If Gatekeeper blocks a preview you choose to trust, use System Settings → Privacy & Security → Open Anyway. Do not disable Gatekeeper globally.

Open Spray Can and enable:

1. **Accessibility:** discover controls and synthesize pointer actions.
2. **Input Monitoring:** capture navigation keys independently of window focus.
3. **Screen Recording (optional):** only for text recognition.

After changing permissions, click **Retry keyboard capture** in Settings → Permissions. macOS may require a relaunch. Quit Scoot or change its shortcuts before using the same bindings in Spray Can.

Homebrew publication is prepared but no public tap installation command is claimed yet. Every packaged release includes a generated cask with its real SHA-256 checksum. See [release instructions](docs/RELEASING.md).

## Shortcuts

Global shortcuts are configurable in Settings → Shortcuts. Labels use **physical US letter-key positions**, including while an IME is active; Spray Can does not change your input source. Vi mode reserves HJKL for movement.

| Action | Default |
| --- | --- |
| Element / grid / freestyle | ⇧⌘J / ⇧⌘K / ⇧⌘L |
| Scroll-area mode | ⌃J |
| Move to a target | Type its label |
| Left / middle / right click | Return / `[` / `]` |
| Double left click | `\` |
| Hold left button / drop | `=` / Return |
| Modified click | Modifier + Return, `[` or `]` |
| Clear prefix; otherwise exit | Esc, ⌘., or ⌃G |
| Remove last label character | Delete |
| Hide / settings | ⌘H / ⌘, |
| Small movement / full grid-cell movement | Arrows / ⌥ arrows |
| Move to screen edge | ⌘ arrows |
| Center, then cycle corners | ⌃L |
| Scroll at pointer | ⇧ arrows |
| Toggle grid lines / labels | ⌃= / ⌃⇧= |
| Increase / decrease cell size | ⇧⌘= / ⇧⌘− |
| Increase / decrease label opacity | ⌘= / ⌘− |

**Shift–Return is Shift-click**, matching Scoot's source implementation. Use backslash for a double-click. [Complete Emacs, vi, and scroll-mode bindings](docs/SHORTCUTS.md).

### Drag and drop

Press ⇧⌘K, type a source label, press `=`, type a destination label, and press Return. Esc/hide/interruption releases the held button. Reinvoking a global mode also ends an existing drag.

![Grid drag workflow](docs/images/drag-demo.gif)

## A native home

![Settings](docs/images/settings.png)

A spray-can menu bar icon shows whether navigation is active. Settings include launch-at-login, optional instant-click, target scope, OCR, vi bindings, label size, grid spacing, and contrast. The interface respects Reduce Transparency and uses no required animations.

## Build and test

Requires full **Xcode 26+**, Swift 5.9-compatible language mode, and a macOS SDK with Liquid Glass APIs. Deployment target is macOS 14; older systems use native translucent materials.

```sh
scripts/test.sh
scripts/build.sh
scripts/install-local.sh
```

The install script copies the app to `~/Applications` without filesystem-provider metadata that can invalidate bundle signatures. It refuses to overwrite an existing installation.

The build script stages project inputs in `/tmp` to avoid coordinated-file-read stalls observed in cloud-managed Documents folders, then places a universal ad-hoc-signed app in `build/Build/Products/Release/`.

Open `SprayCan.xcodeproj` for development. `SprayCanCore` is a local Swift package containing the session state machine, label generation, geometry, and shortcut mappings. `Sources/SprayCanApp` contains the native app, event capture, discovery providers, mouse driver, and overlays.

```sh
# Rebuild original artwork / deterministic Xcode project
swift scripts/generate-artwork.swift
python3 scripts/generate-project.py
# Render actual views with synthetic example content (requires a GUI login)
scripts/render-docs.sh
# Live keyboard/click test in an isolated fixture (requires permissions)
scripts/integration-test.sh
# Local OCR fixture check
swift scripts/ocr-smoke.swift
# Build a distributable preview and matching Homebrew cask
scripts/release.sh 0.1.0-preview.1 preview
```

## Coverage and limitations

- Native controls, browser content, and Electron accessibility trees vary by application. Scans may return partial results when an app is slow.
- OCR text targets can include noninteractive text. Custom canvases, remote desktops, and unlabeled icons may need grid mode.
- All-visible-windows targeting is optional; occlusion checks are conservative. An accessible target that moved or cannot be revalidated must be refreshed or reached by grid.
- Secure Input, protected content, system permission boundaries, and other event-tap tools can restrict operation.
- Cross-version, multiple-display, fullscreen, and third-party app acceptance checks are tracked in [VALIDATION.md](docs/VALIDATION.md).

## Credits and license

Original implementation and artwork under the [MIT License](LICENSE). Workflow research: [Scoot](https://github.com/mjrusso/scoot) and [Vimac](https://github.com/nchudleigh/vimac). No source code or visual assets from either project are bundled. See [architecture and research notes](docs/ARCHITECTURE.md).
