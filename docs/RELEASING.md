# Releases and Homebrew

## Preview

```sh
scripts/test.sh
scripts/release.sh 0.1.0-preview.1 preview
```

Produces `dist/SprayCan-0.1.0-preview.1-universal.zip`, its SHA-256 sidecar, and `dist/spray-can.rb`. The bundle contains arm64 and x86_64 executables, original icons, and deployment metadata for macOS 14+. Previews use an ad-hoc signature and are explicitly unnotarized. Rebuilt ad-hoc apps may require macOS permissions to be granted again.

The release workflow runs on version tags. Tags with a prerelease suffix create unnotarized GitHub prereleases. Stable tags require signing credentials and fail if credentials or notarization are unavailable. Every release has immutable versioned filenames and a checksum; no `latest.zip` URL is used by the cask.

The repository can stay private while testing. Download URLs in a private repository require authentication and are not ready for general Homebrew distribution.

## Developer ID signing later

Configure these GitHub Actions secrets:

- `DEVELOPER_ID_P12_BASE64`, `DEVELOPER_ID_P12_PASSWORD`
- `SIGNING_KEYCHAIN_PASSWORD`
- `DEVELOPER_ID_IDENTITY` (the full Developer ID Application identity)
- `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`

The workflow imports the certificate into a temporary keychain, stores a notarytool profile, signs with hardened runtime and a timestamp, submits and waits, staples, verifies Gatekeeper assessment, packages, and removes temporary credentials. No signing keys belong in the repository.

For local signed packaging, set `SPRAYCAN_SIGN_IDENTITY` and `SPRAYCAN_NOTARY_PROFILE` (and `SPRAYCAN_NOTARY_KEYCHAIN` if using a non-default keychain), then run `scripts/release.sh 0.1.0 signed`.

[Apple notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Homebrew publication

1. Complete the compatibility checklist and provide a stable, signed/notarized release.
2. Make release downloads publicly accessible when ready for public distribution.
3. Copy the generated `spray-can.rb` into `Casks/` in a dedicated Homebrew tap.
4. Run `brew style` and `brew audit --cask` against the cask, and test install/uninstall on a fresh Mac.
5. Publish the tap. Consider a homebrew-cask submission separately, according to its current acceptance requirements.

The generator uses the actual ZIP checksum, a versioned GitHub URL, `Spray Can.app`, and a Sonoma minimum. It does not bypass quarantine or alter global security settings. [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook).
