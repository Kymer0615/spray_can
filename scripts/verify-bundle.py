#!/usr/bin/env python3
import plistlib
import subprocess
import sys
from pathlib import Path
app = Path(sys.argv[1])
with (app / 'Contents/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
binary = app / 'Contents/MacOS' / info['CFBundleExecutable']
architectures = set(subprocess.check_output(['/usr/bin/lipo', '-archs', str(binary)], text=True).split())
assert {'arm64', 'x86_64'} <= architectures, f'Missing architectures: {architectures}'
assert info['LSMinimumSystemVersion'] == '14.0'
assert info['CFBundleIdentifier'] == 'io.github.Kymer0615.SprayCan'
resources = app / 'Contents/Resources'
localizations = sorted(p.stem for p in resources.glob('*.lproj') if (p / 'Localizable.strings').exists())
expected = {'en', 'es', 'ja', 'ko', 'zh-Hans', 'zh-Hant'}
assert expected <= set(localizations), f'Missing localizations: {expected - set(localizations)}'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
print(f'Bundle verified: arm64 + x86_64, macOS 14+, localizations {", ".join(localizations)}, signature intact.')
