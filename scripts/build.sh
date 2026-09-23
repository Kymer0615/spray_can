#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
# Keep Xcode's coordinated project reads outside cloud-managed Documents folders.
build_root="$PWD"
stage="$(mktemp -d /tmp/spraycan-xcode.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
for entry in Package.swift Sources Tests Resources SprayCan.xcodeproj; do ditto "$entry" "$stage/$entry"; done
xcodebuild -project "$stage/SprayCan.xcodeproj" -scheme SprayCan -configuration Release \
  -derivedDataPath "$build_root/build" -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build "$@"
app="$build_root/build/Build/Products/Release/Spray Can.app"
xattr -cr "$app"
codesign --force --options runtime --sign - "$app"
codesign --verify --deep --strict "$app"
