"""Check version/tag consistency without loading repository code or secrets."""
import os
import re
from pathlib import Path

version = re.search(r'^version:\s*(\S+)\s*$', Path('pubspec.yaml').read_text(), re.M).group(1)
tag = os.environ['RELEASE_TAG']
if tag != f'v{version}':
    raise SystemExit(f'Tag {tag} does not match pubspec version {version}')
header = re.search(rf'^##\s+{re.escape(version)}(?:\s|$).*$', Path('CHANGELOG.md').read_text(), re.M)
if not header:
    raise SystemExit(f'CHANGELOG.md has no entry for {version}')
if 'unreleased' in header.group(0).lower():
    raise SystemExit('Mark the changelog entry released after completing release validation')
print(f'Release version verified: {version}')
