# Changelog

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
