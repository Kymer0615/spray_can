#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app='build/Build/Products/Release/Spray Can.app'
if [[ ! -d "$app" ]]; then scripts/build.sh; fi
mkdir -p "$HOME/Applications"
destination="$HOME/Applications/Spray Can.app"
if [[ -d "$destination" ]]; then
  echo 'An app already exists at ~/Applications/Spray Can.app. Quit it and move it aside before installing this build.' >&2
  exit 1
fi
ditto --norsrc --noextattr "$app" "$destination"
xattr -cr "$destination"
codesign --verify --deep --strict "$destination"
open "$destination"
