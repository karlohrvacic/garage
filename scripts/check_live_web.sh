#!/usr/bin/env bash
# After a deploy: the live site is cross-origin isolated on a real page and on
# a route only the app knows, and serves its renderer itself (decision 188). A
# Worker picks up a new version within seconds; this retries for a minute.
set -euo pipefail
SITE="${1:-https://garage.hrva.cc}"

# Each check reads the headers into a variable and greps that, rather than
# piping curl into `grep -q`: under pipefail, grep leaving early can fail curl
# with EPIPE and turn a match into a miss. A line from `curl -I` ends in CR, so
# a value is anchored allowing trailing space: `same-origin-allow-popups`,
# which does not isolate, must not pass for `same-origin`.
isolated() {
  local headers
  headers="$(curl -sSI "$SITE$1")"
  grep -qiE '^cross-origin-opener-policy:[[:space:]]*same-origin[[:space:]]*$' \
    <<<"$headers" &&
    grep -qiE '^cross-origin-embedder-policy:[[:space:]]*require-corp[[:space:]]*$' \
      <<<"$headers"
}

# The Worker answers a path that matches no file with index.html and a 200
# (`not_found_handling` in wrangler.jsonc), so the status proves nothing: the
# type is what tells the renderer from the page.
renderer() {
  local headers
  headers="$(curl -sSI "$SITE/canvaskit/skwasm.wasm")"
  grep -qiE '^content-type:[[:space:]]*application/wasm[[:space:]]*(;.*)?$' \
    <<<"$headers"
}

compressed() {
  local headers
  headers="$(curl -sSI -H 'Accept-Encoding: br' "$SITE/main.dart.wasm")"
  grep -qiE '^content-encoding:[[:space:]]*br[[:space:]]*$' <<<"$headers"
}

# What each address answered, for a failed run: the check passed from a
# laptop and failed from GitHub's runners twice, and "not isolated" alone could
# not say whether the headers were missing or the request never reached the
# site (a Cloudflare challenge answers a datacenter address with a 403).
report() {
  local path
  for path in / /company /canvaskit/skwasm.wasm; do
    echo "--- $SITE$path"
    curl -sSI "$SITE$path" |
      grep -iE '^(HTTP/|server:|cf-mitigated:|cf-cache-status:|content-type:|cross-origin-(opener|embedder)-policy:)' ||
      true
  done
}

for attempt in 1 2 3 4 5 6; do
  if isolated / && isolated /company && renderer; then
    break
  fi
  if [ "$attempt" -eq 6 ]; then
    report
    echo "::error::$SITE is not isolated, or does not serve canvaskit/skwasm.wasm"
    exit 1
  fi
  sleep 10
done

# A warning, not a failure: whether Cloudflare compresses application/wasm is
# its choice, and a site that works uncompressed should not be marked broken.
if ! compressed; then
  echo "::warning::main.dart.wasm is not sent Brotli-compressed"
fi
echo "✓ $SITE is isolated and serves its own renderer"
