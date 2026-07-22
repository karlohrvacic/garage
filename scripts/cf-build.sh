#!/usr/bin/env bash
# Cloudflare Workers Build command for the Flutter web app.
#
# Cloudflare's build image has no Flutter SDK, so this fetches a pinned version,
# then builds build/web. Set as the project's Build command:
#     bash scripts/cf-build.sh
# Supabase values come from Build variables (SUPABASE_URL, SUPABASE_ANON_KEY).
set -euo pipefail

FLUTTER_VERSION="3.44.6"
FLUTTER_DIR="$HOME/flutter"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "→ Fetching Flutter $FLUTTER_VERSION…"
  git clone https://github.com/flutter/flutter.git --depth 1 \
    -b "$FLUTTER_VERSION" "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
# CI checkouts can trip Git's ownership check on the SDK dir.
git config --global --add safe.directory "$FLUTTER_DIR" || true

flutter --version
flutter pub get

echo "→ Building web…"
flutter build web --release \
  --base-href "/" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

echo "✓ build/web ready"
