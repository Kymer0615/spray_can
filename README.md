<p align="center">
  <img src="docs/images/icon.png" width="112" alt="Spray Can app icon">
</p>

<h1 align="center">Spray Can</h1>

<p align="center">
  <strong>Click anything on your Mac without touching the mouse.</strong><br>
  Labels for every control, a grid for everywhere else, and private on-device OCR for the text in between.
</p>

<p align="center">
  macOS 14+ · Apple Silicon & Intel · Free & open source (MIT) · 100% on-device
</p>

<p align="center">
  🌐 <strong>English</strong> · <a href="README.zh-Hans.md">简体中文</a> · <a href="README.zh-Hant.md">繁體中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a>
</p>

```sh
brew install --cask kymer0615/tap/spray-can
```

![Spray Can labelling a window and clicking a file](docs/images/element-demo.gif)

## How it works

1. Press **⇧⌘J**. Every button, link, row, and field gets a short label right next to its text.
2. Type the label. The pointer jumps there.
3. Press **Return** to click — press it **twice** to double-click, or **hold** it to right-click.

No mouse, no trackpad, no hunting for the cursor.

## Highlights

<table>
<tr>
<td width="50%" valign="top">

### Labels that stay out of the way
Each label sits beside its element's text, never on top of the text or icon you're about to click. One label per item, even in dense lists and toolbars.

<img src="docs/images/elements.png" alt="Labels beside each item in a file window">

</td>
<td width="50%" valign="top">

### Color coding
Nearby labels get clearly different colors, and each element is shaded to match, so every label pairs with its element at a glance. Type one letter and only the matches remain. Five color schemes, including a color-blind safe one.

<img src="docs/images/color-coding.png" alt="Color-coded labels before and after typing a letter">

</td>
</tr>
<tr>
<td width="50%" valign="top">

### A grid for everything else
Canvases, games, remote desktops, unlabelled icons: press **⇧⌘K** and reach any point on any display.

<img src="docs/images/grid.png" alt="Grid labels covering the screen">

</td>
<td width="50%" valign="top">

### Drag and take screenshots
Press **Space** to hold the button, type a second label to drag there, and press **Space** again to drop. It even drives the macOS screenshot tool (⇧⌘4).

<img src="docs/images/screenshot-demo.gif" alt="Taking a screenshot with grid labels and Space">

</td>
</tr>
</table>

And more:

- **Sees what Accessibility misses.** Optional Apple Vision OCR labels visible text in apps that don't expose their controls, in several languages at once.
- **Smooth scroll mode.** **⌃J**, then **HJKL** or the arrows, with adjustable smoothness; any other key exits and reaches the app. It works in VS Code and other Electron apps too.
- **Keeps your shortcuts.** ⌘C, ⌘V, ⌘W, Spotlight, and other shortcuts Spray Can doesn't use keep working while labels are up.
- **Follows you.** Switch tabs, windows, or apps (even with ⌘Tab) and fresh labels appear.
- **Native.** Swift and AppKit, Liquid Glass on macOS 26, and an interface in six languages.

## Four modes

| Mode | Shortcut | Use it for |
| --- | --- | --- |
| **Elements** | ⇧⌘J | Buttons, links, rows, fields, and OCR text |
| **Grid** | ⇧⌘K | Any point on any display |
| **Freestyle** | ⇧⌘L | Moving the pointer in small or full-cell steps |
| **Scroll** | ⌃J | HJKL scrolling, half pages, top and bottom |

All global shortcuts can be changed in Settings.

## Cheat sheet

| Key | Action |
| --- | --- |
| Type a label | Move the pointer to it |
| **Return** | Click · twice quickly: double-click · hold: right-click |
| `]` / `[` / `\` | Right click / middle click / double-click |
| **Space** or `=` | Hold the button to drag; again to drop |
| Arrows · ⌥ arrows | Move the pointer a little · a full cell |
| ⇧ arrows | Scroll |
| **Esc** | Clear the typed letters, then exit |

The full list, including Emacs and vi bindings, is in [SHORTCUTS.md](docs/SHORTCUTS.md).

## Make it yours

![Appearance settings](docs/images/appearance.png)

- Label position, size, offsets, and Liquid Glass or plain backgrounds
- Color coding with five schemes, element shading, and shading opacity
- Scroll smoothness and where the pointer waits in scroll mode
- Click as soon as a label is complete, Return twice to double-click, and hold Return to right-click
- OCR on or off, and its recognition languages
- Every global shortcut, plus optional vi bindings

## Install

```sh
brew install --cask kymer0615/tap/spray-can
open "/Applications/Spray Can.app"
```

Update with `brew update && brew upgrade --cask kymer0615/tap/spray-can`; remove with `brew uninstall --cask spray-can` (preferences are kept). You can also download the universal ZIP from [Releases](https://github.com/Kymer0615/spray_can/releases) and move **Spray Can.app** into Applications.

Spray Can asks for:

1. **Accessibility**: to find controls, capture navigation keys, and move, click, drag, and scroll.
2. **Screen Recording** (optional): only for on-device OCR and finding text beside labels.

Releases are **signed with the project's own certificate and not notarized**. The same certificate signs every release, so macOS keeps Spray Can's permissions when you update (from 0.1.7 on). If macOS blocks the first launch, use **System Settings → Privacy & Security → Open Anyway**. Release archives and their SHA-256 checksums are versioned; see [release instructions](docs/RELEASING.md).

## Privacy

Everything runs on your Mac. OCR uses Apple Vision on-device; screenshots are processed in memory and discarded. There are no screenshot logs, no analytics, no cloud inference, and no account. If you turn on **Prepare text labels in advance**, Spray Can also reads the focused window about a second after you switch to it (only when connected to power), the same way, and keeps the result in memory only.

## OCR

OCR reads **several languages at the same time**. Choose and order them in **General → Text recognition languages**. Languages that share a writing system (English, French, Spanish…) are read together; each additional writing system (Chinese, Japanese, Korean…) adds a pass on the same screenshot, so scans take a little longer. By default Spray Can picks your Mac's preferred languages plus English. Recognition reads only the target window, and **General → Targets → Prepare text labels in advance** (off by default) can read it ahead of time so text labels appear at once.

OCR finds where text is, not whether it's clickable, so a text label may point at a heading. For unlabelled icons and custom canvases, use the grid. See [VALIDATION.md](docs/VALIDATION.md) for compatibility and testing status.

## Build from source

Requires **Xcode 26+**.

```sh
scripts/test.sh            # core tests + localization check
scripts/build.sh           # universal Release build
scripts/install-local.sh
```

More tools: `scripts/render-docs.sh` (README images), `scripts/snapshot-labels.sh` (labels over a real window), `scripts/integration-test.sh`, `swift scripts/ocr-smoke.swift`, `python3 scripts/check-localizations.py`. `SprayCanCore` holds the session state machine, label placement, and other pure logic; `Sources/SprayCanApp` holds the app, event capture, discovery, and overlays. See [AGENTS.md](AGENTS.md) and the [architecture notes](docs/ARCHITECTURE.md).

## Status

Spray Can 0.1.16 runs on macOS 14 and later. The navigation core has been stress-tested with 1,000 rapid activation cycles, and a native fixture completed 60 element/grid click cycles without missed clicks or leaked input. Third-party apps, multiple displays, full screen, and older macOS versions are still being validated; see [VALIDATION.md](docs/VALIDATION.md).

## Community

[Issues and feature ideas](https://github.com/Kymer0615/spray_can/issues), testing, and [contributions](https://github.com/Kymer0615/spray_can/pulls) are welcome, especially accessibility coverage, OCR validation, interaction design, documentation, and cross-app testing.

<p>
  <a href="https://buymeacoffee.com/ziyang"><img src="docs/images/buymeacoffee.png" width="28" alt="Buy me a coffee"></a>
  If Spray Can helps you, you can <a href="https://buymeacoffee.com/ziyang">buy me a coffee</a>. Support is optional and never unlocks features.
</p>

## Credits

Original implementation and artwork, released under the [MIT License](LICENSE). Workflow inspiration: [Scoot](https://github.com/mjrusso/scoot) · [Vimac](https://github.com/nchudleigh/vimac). No source code or visual assets from either project are bundled.
