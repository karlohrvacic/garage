#!/usr/bin/env python3
"""Fails when the web build's first download outgrows scripts/web_budget.json.

Sizes are Brotli at quality 11, a floor rather than what a browser is sent:
for the live build on 27 September 2026, Cloudflare sent Chrome zstd about a
third larger. Raw bytes would overstate every file three to four times. A
pattern with `*` adds up every file it matches.

    python3 scripts/web_budget.py build/web
"""
import json
import pathlib
import sys

try:
    import brotli
except ImportError:
    sys.exit('web_budget.py needs the Brotli module: pip install brotli==1.1.0')

# The budget is read from beside this file and the default build is the
# repository's, so it runs from any directory; a build directory given is
# taken as typed, relative to where this was called from.
script = pathlib.Path(__file__).resolve()
build = (pathlib.Path(sys.argv[1]) if len(sys.argv) > 1
         else script.parent.parent / 'build' / 'web')
budget = json.loads(script.with_name('web_budget.json').read_text())

over = []
for pattern, limit in budget['files'].items():
    paths = sorted(build.glob(pattern))
    if not paths:
        over.append(f'{pattern}: nothing in {build} matches it')
        continue
    size = sum(len(brotli.compress(p.read_bytes(), quality=11)) for p in paths)
    kb = round(size / 1024)
    print(f'{pattern:40} {kb:6} KB of {limit:6} KB')
    if kb > limit:
        over.append(f'{pattern}: {kb} KB, over its {limit} KB')

for line in over:
    print(f'::error::{line}')
sys.exit(1 if over else 0)
