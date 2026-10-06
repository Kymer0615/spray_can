# Changelog

## Spray Can 0.1.9

- Color schemes for color coding: Vivid (default), Pastel, Color-blind safe (Okabe–Ito based), Bold, and Neon. Each scheme's eight colors are chosen for large perceptual distances, and badge text switches between black and white for contrast.
- A cleaner Appearance page in sections: Labels, Color coding, Colors, and Grid. With color coding on, the label tint, OCR tint, and label text pickers move into a collapsed "Plain label colors (grid mode)" group, since only grid labels still use them; scheme and shading controls are hidden while color coding is off.
- Settings passed as command-line defaults (`-colorCodeTargets NO`, `-shadingOpacity 0.3`) now take effect; boolean and number settings previously ignored them.

Validation: 46 core tests (including per-scheme color separation and neighbor contrast) and a localization check passed. The Appearance page was rendered with color coding on and off, and a real Finder window was checked in all five schemes.

This release is signed with the project's own certificate and not notarized by Apple. If macOS blocks first launch, use System Settings → Privacy & Security → Open Anyway for the app you choose to trust.

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
```

## Spray Can 0.1.8

- Fix Return sometimes doing nothing in Chrome (and other Chromium browsers and Electron apps), so it no longer needs a second press. Before clicking, Spray Can checks that nothing covers the target. Chromium often answers that check with a container around the link instead of the link itself, or with the whole page on the first try, so more than half of the links on a typical page failed the first check and showed "Target disappeared". An ancestor now counts as a match, the check is asked again briefly, and a target is accepted when the answer comes from its own window. A different window or app on top still blocks the click.

Validation: on a live github.com page in Chrome, 39 of 40 links and buttons pass the check on the first Return (previously 19 of 40), and a link covered by another app's window is still refused.

This release is signed with the project's own certificate and not notarized by Apple. If macOS blocks first launch, use System Settings → Privacy & Security → Open Anyway for the app you choose to trust.

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
```

## Spray Can 0.1.7

- Keep permissions across updates: releases are now signed with the project's own long-lived certificate instead of an ad-hoc signature. macOS ties Accessibility and Screen Recording permission to the signing identity, so from this release on updates keep them. Grant them once more after updating to 0.1.7.

Validation: two different builds signed with the certificate have identical designated requirements, and a self-signed release packaged locally verifies with `codesign --verify --deep --strict`. Permission persistence across a real Homebrew upgrade is confirmed with the next release.

This release is signed with the project's own certificate and not notarized by Apple. If macOS blocks first launch, use System Settings → Privacy & Security → Open Anyway for the app you choose to trust.

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
```

## Spray Can 0.1.6

- Fix scroll direction with natural scrolling on: J now scrolls down and K up (and H/L, D/U, gg/G, and the scroll shortcuts in other modes follow suit). macOS applies the natural-scrolling setting to synthesized scroll events too, so Spray Can now follows it.
- Scroll in VS Code and other apps that expose no accessibility scroll areas: scroll mode scrolls under the pointer, and Tab moves to the app's content area.

Validation: 45 core tests (including scroll direction with natural scrolling on and off) and a localization check passed. A native scroll-view fixture confirmed J/K/H/L directions with natural scrolling on, and a VS Code editor scrolled down and back under the pointer. Scroll direction with natural scrolling off is covered by unit tests only; see docs/VALIDATION.md.

This release is ad-hoc signed and not notarized by Apple. If macOS blocks first launch, use System Settings → Privacy & Security → Open Anyway for the app you choose to trust.

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
```

## Spray Can 0.1.5

- Shade elements in their label's color, so each label and its element pair up at a glance. Choose Always (default), While typing, or Off in Appearance, and adjust the shading opacity.
- Nearby labels now get clearly different colors: each label takes the palette color most different from its neighbors' colors, with the nearest neighbors counting most (no more red next to orange).
- OCR labels are color-coded and shaded like element labels, with a dashed outline marking them as text locations.
- Color-coded badges are solid even with Liquid Glass, which washed their colors out.
- Typed letters on color-coded badges are dimmed instead of drawn in the highlight color, which could vanish on yellow or green badges.
- Folder rows keep their own label when they contain a disclosure triangle.
- README: new images showing labels beside text, color coding, and shading, rendered from a synthetic example window with default settings.

Validation: 44 core tests (including palette separation and nearest-neighbor contrast), a localization check, and a universal Release build passed. Shading was checked on a real Finder window and in the synthetic documentation scene, before and after typing. Glass rendering of solid color badges on macOS 14–15 remains to be validated; see docs/VALIDATION.md.

This release is ad-hoc signed and not notarized by Apple. If macOS blocks first launch, use System Settings → Privacy & Security → Open Anyway for the app you choose to trust.

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
```

## Spray Can 0.1.4

- Readable labels: each label now touches its element and sits right after the element's text, on the same line, instead of drifting away on a connector line. Labels may overlap an element's padding but never its text or icon. Text positions come from the accessibility tree and a fast on-device text pass over the target window; nothing is stored.
- One label per item: a row no longer gets separate labels for its cells, name field, and date column, and a sidebar row that only wraps a button shares that button's label.
- Color coding fills each badge with a color that differs from its neighbors. Outlines appear only while you type, around the elements that still match. OCR labels keep their own tint.
- Fix Space and = drags in the macOS screenshot tool and other apps that ignore a drag that jumps: held moves now glide to the destination, and Return or Space drops once the glide arrives.
- Fix text targeting on windows that span several displays.

Validation: 42 core tests and a localization check passed, along with a universal Release build. Real-window snapshots of System Settings, Finder, and Safari compared before and after: connectors dropped from 108 to 0, 245 to 2, and 11 to 8 (out of 112 labels), and layout takes 2–8 ms per window. A synthetic gliding drag captured a region with the macOS screenshot tool, where a single-jump drag did not. Pressing Space in a live ⇧⌘4 session and non-Latin text positions remain to be validated; see docs/VALIDATION.md.

This release is ad-hoc signed and not notarized by Apple. If macOS blocks first launch, use System Settings → Privacy & Security → Open Anyway for the app you choose to trust.

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
```

## Spray Can 0.1.3

- Stop labelling the same element twice: OCR text that an element label already marks (text inside a button, or a title right next to its icon) is skipped. Turn it off with General → Hide text labels on known elements.
- Keep connector lines from crossing each other or running through other labels, and keep moved labels close to their element: labels now try spots flush against every side of the element first, and briefly overlapping a neighboring element beats jumping far away.
- Color-code labels: each element label, its connector, and a box around its element share a color, and nearby labels always get different colors. Toggle it in Appearance → Color-code labels and target boxes.
- Space drags: after a label moves the pointer in Elements or Grid mode, press Space to hold the button, type another label to drag there, and press Space or Return to drop. Useful for screenshot selections.
- Move the status card out of the way: it picks the bottom center, top, or a corner, whichever does not cover labels, their elements, the selection, or the pointer.

Validation: 37 core tests (including OCR de-duplication, connector crossings in dense clusters, label distance, neighbor colors, HUD placement, and the Space binding), a localization consistency check, and a universal Release build with bundle verification passed. On an 800-target page fixture, layout takes about 0.55 s in a Release build with no connector conflicts (previously about 1 s and 942 conflicts). Live dragging with Space, OCR de-duplication, and HUD movement in third-party apps remain to be validated; see docs/VALIDATION.md.

This release is ad-hoc signed and not notarized by Apple. If macOS blocks first launch, use System Settings → Privacy & Security → Open Anyway for the app you choose to trust.

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
```

## Spray Can 0.1.2

- Follow the target window: switching tabs or windows, opening, moving, resizing, or closing a window, and switching apps (including ⌘Tab) re-scans and shows fresh labels instead of ending navigation. Partial labels are cleared; an in-progress drag is still cancelled.
- Recognize several OCR languages at the same time. Choose and order any languages Apple Vision supports; each writing system gets its own pass on the same screenshot, so English, Chinese, Japanese, and Korean text can be labelled in one scan.
- Place labels beside their element instead of on top of it. Choose left, right, above, below, or on the element, and tune horizontal and vertical offsets in Appearance.
- Localize the interface in 简体中文, 繁體中文, 日本語, 한국어, and Español, with an in-app language picker (General → Language).
- Add README translations with a language bar.
- Fix the Help & Shortcuts menu link.

Validation: 31 core tests (including window-refresh rules, OCR language grouping and merging, and label placement), a localization consistency check, a universal Release build with bundle verification, and a Vision smoke test on a mixed English/Chinese/Japanese/Korean image (all five strings found with multi-pass OCR; English-only and single combined requests miss some) passed. Live window-following across third-party apps, ⌘Tab behavior, and the translated interface on every macOS version remain to be validated; see docs/VALIDATION.md.

This release is ad-hoc signed and not notarized by Apple. If macOS blocks first launch, use System Settings → Privacy & Security → Open Anyway for the app you choose to trust.

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
```

## Spray Can 0.1.1

- Fix the Bilibili crash caused by duplicate accessibility target IDs; retain distinct elements even when their hashes collide.
- Activate Chrome tab-strip tabs through their accessibility action for ordinary left-clicks, with visibility and stale-target checks.
- Move the cursor after one completed label without requiring click-level hit testing; clicks still validate the target.
- Keep label text in a separate foreground layer so native glass cannot hide it.
- Add a saved Liquid Glass toggle and compact two-column color controls.
- Disable background opacity controls and shortcuts while glass or Reduce Transparency is enabled; preserve the setting for plain backgrounds.
- Replace the redundant Input Monitoring setup with actual keyboard-capture status. Accessibility enables navigation; Screen Recording remains optional for OCR.

Validation: 18 core tests, 60 native click cycles, 12 single-entry cursor moves in a disposable Bilibili window, and Bilibili accessibility/OCR layout checks passed. A Chrome tab-selection check passed; broader tab edge cases and cross-version compatibility remain documented in docs/VALIDATION.md.

This release is ad-hoc signed and not notarized by Apple. If macOS blocks first launch, use System Settings → Privacy & Security → Open Anyway for the app you choose to trust.

```sh
brew update
brew upgrade --cask kymer0615/tap/spray-can
```
