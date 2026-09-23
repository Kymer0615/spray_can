#!/usr/bin/env python3
import hashlib, re, sys
from pathlib import Path
version, archive = sys.argv[1:3]
channel = sys.argv[3] if len(sys.argv) > 3 else "adhoc"
assert channel in ("adhoc", "signed"), "Invalid signing mode"
caveats = "" if channel == "signed" else """
  caveats <<~EOS
    This app is ad hoc signed and is not notarized by Apple.
    If macOS blocks the first launch, allow it in System Settings >
    Privacy & Security > Open Anyway, then open it again.
  EOS
"""
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

  depends_on macos: :sonoma

  app "Spray Can.app"

  uninstall quit: "io.github.Kymer0615.SprayCan"

  zap trash: [
    "~/Library/Preferences/io.github.Kymer0615.SprayCan.plist",
    "~/Library/Saved Application State/io.github.Kymer0615.SprayCan.savedState",
  ]
{caveats}end
''')
