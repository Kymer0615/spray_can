#!/bin/bash
# Render README images from synthetic example data. Every setting is passed as a command-line
# default (volatile, never saved), so images show factory settings, not this Mac's preferences.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/build.sh
SPRAYCAN_DOCS_DIR="$PWD/docs/images" 'build/Build/Products/Release/Spray Can.app/Contents/MacOS/SprayCan' --render-docs \
  -AppleLanguages '(en)' -glassEnabled YES -vision NO -allWindows NO -instantClick NO -vi NO \
  -cellSize 100 -fontSize 13 -contrast 0.85 -ocrLanguages '("en-US")' -hintPosition leading \
  -hintOffsetX 0 -hintOffsetY 0 -appearanceColors '{}' -shortcuts '' -dedupeOCR YES \
  -colorCodeTargets YES -elementShading always -shadingOpacity 0.16 -colorScheme vivid -scrollSmoothness 0.75 -scrollPointer stay -passSystemShortcuts YES -returnTwiceDoubleClicks YES -holdReturnRightClicks YES -prescanText NO
