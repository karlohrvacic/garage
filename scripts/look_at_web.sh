#!/usr/bin/env bash
# Builds the web app the way the deploy does, serves it the way the Worker
# does, and screenshots each path at a desk's size:
#
#     scripts/look_at_web.sh / /sign-up
#
# Needs agent-browser (npm i -g agent-browser && agent-browser install) and
# env/local.json, and fonttools (pip install fonttools==4.60.2) to cut the
# fonts as the deploy does. A signed-in page needs the local Supabase
# (supabase start) and a sign-in by hand: open the printed address in Chrome
# instead, and press Ctrl-C when done.
set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-8811}"
OUT="build/web-look"
PATHS=("$@")
if [ ${#PATHS[@]} -eq 0 ]; then
  PATHS=(/)
fi

flutter build web --release --wasm --no-web-resources-cdn \
  --dart-define-from-file=env/local.json
if command -v pyftsubset > /dev/null; then
  bash scripts/subset_web_fonts.sh
else
  echo "fonts not cut: fonttools is not installed, so they are whole, unlike the deploy's"
fi
python3 scripts/serve_web.py build/web "$PORT" &
SERVER=$!
export AGENT_BROWSER_SESSION="look-at-web-$$"
# However the script ends, the browser goes with the server.
trap 'agent-browser close > /dev/null 2>&1 || true; kill "$SERVER"' EXIT
sleep 1

mkdir -p "$OUT"
agent-browser set viewport 1440 900
for path in "${PATHS[@]}"; do
  agent-browser open "http://127.0.0.1:$PORT$path"
  # A page that never draws is the one most worth a picture, so a missing
  # first frame is said and the screenshot is taken anyway.
  agent-browser wait --fn "window.__garageFirstFrame === true" ||
    echo "no first frame for $path"
  agent-browser wait 1500   # the page's own data, after the first frame
  name="$(printf '%s' "$path" | tr '/?=&' '____')"
  agent-browser screenshot "$OUT/${name:-_}.png"
  echo "→ $OUT/${name:-_}.png"
done
