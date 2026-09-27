# Changelog

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
