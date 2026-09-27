#!/usr/bin/env python3
"""Check interface translations against English.

Every language must have exactly the English keys, the same format
placeholders, and no empty values. With --stringsdata DIR (a build folder
compiled with SWIFT_EMIT_LOC_STRINGS), every string the compiler extracted
from the app must also exist in English.
"""
import glob
import json
import re
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
resources = root / 'Resources'
placeholder = re.compile(r'%(?:\d+\$)?(?:ll|l|h)?[@dDuUxXoOfeEgGcCsSpaAF%]')


def load(path):
    output = subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)])
    return json.loads(output)


def placeholders(text):
    # Positional placeholders may be reordered; compare as multisets without positions.
    return sorted(re.sub(r'\d+\$', '', match) for match in placeholder.findall(text) if match != '%%')


errors = []
english = load(resources / 'en.lproj/Localizable.strings')
languages = sorted(p.parent.stem for p in resources.glob('*.lproj/Localizable.strings'))
for language in languages:
    if language == 'en':
        continue
    table = load(resources / f'{language}.lproj/Localizable.strings')
    for key in sorted(set(english) - set(table)):
        errors.append(f'{language}: missing {key!r}')
    for key in sorted(set(table) - set(english)):
        errors.append(f'{language}: unknown key {key!r}')
    for key, value in table.items():
        if key in english and not value.strip():
            errors.append(f'{language}: empty value for {key!r}')
        elif key in english and placeholders(value) != placeholders(english[key]):
            errors.append(f'{language}: placeholders differ for {key!r}')

if '--stringsdata' in sys.argv:
    folder = sys.argv[sys.argv.index('--stringsdata') + 1]
    extracted = set()
    for path in glob.glob(f'{folder}/**/*.stringsdata', recursive=True):
        for entries in json.load(open(path)).get('tables', {}).values():
            extracted.update(entry['key'] for entry in entries)
    if not extracted:
        errors.append(f'No .stringsdata found under {folder}')
    for key in sorted(extracted - set(english)):
        errors.append(f'en: string used in the app but missing from Localizable.strings: {key!r}')

if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print(f'Localizations verified: {", ".join(languages)} ({len(english)} strings each).')
