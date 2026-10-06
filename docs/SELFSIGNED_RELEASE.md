This release is **signed with the project's own certificate and not notarized by Apple**. The same certificate signs every release, so macOS keeps Spray Can's Accessibility and Screen Recording permissions after updates (from 0.1.7 on; grant them once more after updating from an earlier version). If macOS blocks first launch, use System Settings → Privacy & Security → Open Anyway for the app you choose to trust.

Install through Homebrew:

```sh
brew install --cask kymer0615/tap/spray-can
```

Includes native Liquid Glass labels, color coding, adaptive placement beside each element's text, and private on-device text recognition. Compatibility varies across applications; see the README and docs/VALIDATION.md for verified results and remaining checks.
