#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build.sh
SPRAYCAN_DOCS_DIR="$PWD/docs/images" 'build/Build/Products/Release/Spray Can.app/Contents/MacOS/SprayCan' --render-docs
