#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${1:?Usage: scripts/release.sh VERSION [preview|signed]}"
channel="${2:-preview}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.-]+)?$ ]]; then
  echo 'Version must be a semantic version without a leading v.' >&2; exit 1
fi
if [[ "$channel" != preview && "$channel" != signed ]]; then echo 'Unknown channel' >&2; exit 1; fi
if [[ "$channel" == preview && "$version" != *-* ]]; then
  echo 'Unsigned previews require a prerelease suffix, e.g. 0.1.0-preview.1.' >&2; exit 1
fi
if [[ "$channel" == signed ]]; then
  : "${SPRAYCAN_SIGN_IDENTITY:?Developer ID Application identity required}"
  : "${SPRAYCAN_NOTARY_PROFILE:?notarytool keychain profile required}"
fi
scripts/build.sh
mkdir -p dist
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
ditto --norsrc --noextattr 'build/Build/Products/Release/Spray Can.app' "$stage/Spray Can.app"
app="$stage/Spray Can.app"
xattr -cr "$app"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version%%-*}" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${GITHUB_RUN_NUMBER:-1}" "$app/Contents/Info.plist"
if [[ "$channel" == signed ]]; then
  codesign --force --options runtime --timestamp --sign "$SPRAYCAN_SIGN_IDENTITY" "$app"
  ditto -c -k --sequesterRsrc --keepParent "$app" "$stage/notary.zip"
  notary_args=()
  if [[ -n "${SPRAYCAN_NOTARY_KEYCHAIN:-}" ]]; then notary_args+=(--keychain "$SPRAYCAN_NOTARY_KEYCHAIN"); fi
  xcrun notarytool submit "$stage/notary.zip" --keychain-profile "$SPRAYCAN_NOTARY_PROFILE" "${notary_args[@]}" --wait
  xcrun stapler staple "$app"
  spctl --assess --type execute --verbose "$app"
else
  codesign --force --sign - "$app"
fi
codesign --verify --deep --strict "$app"
archive="SprayCan-${version}-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > "$archive.sha256")
python3 scripts/generate-cask.py "$version" "dist/$archive"
echo "Created dist/$archive ($channel)"
