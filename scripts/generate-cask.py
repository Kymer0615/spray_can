#!/usr/bin/env python3
import hashlib, re, sys
from pathlib import Path
version, archive = sys.argv[1:]
assert re.fullmatch(r'\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?', version), 'Invalid version'
archive = Path(archive)
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(archive.parent / 'spray-can.rb').write_text(f'''cask "spray-can" do
  version "{version}"
  sha256 "{checksum}"

  url "https://github.com/Kymer0615/spray_can/releases/download/v#{{version}}/SprayCan-#{{version}}-universal.zip"
  name "Spray Can"
  desc "Keyboard-driven pointer and element navigation for macOS"
  homepage "https://github.com/Kymer0615/spray_can"

  depends_on macos: ">= :sonoma"
  app "Spray Can.app"

  zap trash: [
    "~/Library/Preferences/io.github.Kymer0615.SprayCan.plist",
    "~/Library/Saved Application State/io.github.Kymer0615.SprayCan.savedState",
  ]
end
''')
