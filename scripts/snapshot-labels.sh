#!/bin/bash
# Render real labels over a capture of an app's focused window, for checking readability.
# Usage: scripts/snapshot-labels.sh <bundle id> <out.png> [--prefix ab] [--ocr] [--time-ocr]
# The terminal running this needs Accessibility and Screen Recording access.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
app="${1:?bundle id}"; out="${2:?output png}"; shift 2
swift build --build-system native >/dev/null
.build/debug/SprayCan --render-overlay --app "$app" --out "$out" "$@"
