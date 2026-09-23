#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
stage="$(mktemp -d /tmp/spraycan-integration.XXXXXX)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Fixture.app/Contents/MacOS"
xcrun swiftc scripts/NavigationFixture.swift -o "$stage/Fixture.app/Contents/MacOS/Fixture"
cat > "$stage/Fixture.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>io.github.Kymer0615.SprayCan.TestFixture</string><key>CFBundleExecutable</key><string>Fixture</string><key>CFBundleName</key><string>Navigation Fixture</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
export SPRAYCAN_FIXTURE_STATE="$stage/state.json"
export SPRAYCAN_FIXTURE_EXECUTABLE="$stage/Fixture.app/Contents/MacOS/Fixture"
swift build --build-system native
.build/debug/SprayCan --integration-test
