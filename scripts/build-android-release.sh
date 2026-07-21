#!/usr/bin/env bash
# Build the signed Play release bundle.
#
# Prereqs (see RELEASE.md):
#   - env/prod.json           production Supabase URL + anon key (+ Google client id)
#   - android/key.properties  points at your upload keystore
#
# Usage:  ./scripts/build-android-release.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "✗ flutter not on PATH. Try: export PATH=\"/opt/homebrew/bin:\$PATH\"" >&2
  exit 1
fi

if [[ ! -f env/prod.json ]]; then
  echo "✗ env/prod.json missing. Create it (see RELEASE.md §3)." >&2
  exit 1
fi

if [[ ! -f android/key.properties ]]; then
  echo "✗ android/key.properties missing — the build would be signed with the" >&2
  echo "  debug key and Play would reject it. Create the upload keystore first" >&2
  echo "  (see RELEASE.md §4)." >&2
  exit 1
fi

echo "→ Building release app bundle…"
flutter build appbundle --dart-define-from-file=env/prod.json

echo
echo "✓ Done: build/app/outputs/bundle/release/app-release.aab"
echo "  Upload that file to Play Console → Testing → Internal testing."
