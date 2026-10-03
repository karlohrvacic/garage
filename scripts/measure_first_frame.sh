#!/usr/bin/env bash
# Plan 1's speed target, first paint under 2 s on a cold load, measured the
# same way every time: the live sign-in page, cold, on Lighthouse's desktop
# profile with applied throttling (10 Mbit/s, 40 ms), in Chromium with
# software WebGL so the wasm build runs. Prints first paint, which the splash
# makes meet the target, and the first frame (the `garage-first-frame` mark
# the bootstrap leaves), which is recorded as a measurement, not a target.
#
# The throttling is spelled out because the desktop preset leaves the applied
# kind unset (its 10 Mbit/s and 40 ms feed only the simulated kind), and a run
# without it measures whatever network it happens to be on. Needs Chrome, or
# CHROME_PATH naming one; agent-browser's Chrome for Testing will do.
set -euo pipefail
cd "$(dirname "$0")/.."

SITE="${1:-https://garage.hrva.cc/sign-in}"
OUT="build/lighthouse.json"
mkdir -p build
# A run that fails before writing must not be read as the last one's result.
rm -f "$OUT"

npx --yes lighthouse@12 "$SITE" \
  --preset=desktop --throttling-method=devtools \
  --throttling.requestLatencyMs=40 \
  --throttling.downloadThroughputKbps=10240 \
  --throttling.uploadThroughputKbps=10240 \
  --only-categories=performance --output=json --output-path="$OUT" --quiet \
  --chrome-flags="--headless=new --use-angle=swiftshader --enable-unsafe-swiftshader"

python3 - "$OUT" <<'EOF'
import json
import sys

report = json.load(open(sys.argv[1]))
audits = report.get('audits', {})
if report.get('runtimeError'):
    print(f"lighthouse: {report['runtimeError'].get('message', 'a runtime error')}")


def error_of(audit):
    """What went wrong with an audit that errored, or None when it ran."""
    if audit.get('scoreDisplayMode') != 'error':
        return None
    return audit.get('errorMessage') or 'no message'


paint = audits.get('first-contentful-paint', {})
if error_of(paint):
    print(f'first paint: the audit errored ({error_of(paint)})')
elif paint.get('numericValue') is None:
    print('first paint: not in the report')
else:
    print(f"first paint: {paint['numericValue'] / 1000:.2f} s")

timings = audits.get('user-timings', {})
marks = {
    item['name']: item['startTime']
    for item in (timings.get('details') or {}).get('items', [])
    if item.get('timingType') == 'Mark'
}
first = marks.get('garage-first-frame')
if first is not None:
    print(f'first frame: {first / 1000:.2f} s')
elif error_of(timings):
    print(f'first frame: the user-timings audit errored ({error_of(timings)})')
else:
    print('first frame: no garage-first-frame mark (is the splash deployed?)')
EOF
