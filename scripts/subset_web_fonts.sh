#!/usr/bin/env bash
# Cuts the web build's fonts to scripts/web_font_ranges.txt and drops their
# hinting, which a canvas renderer does not use (decision 189). Run after
# `flutter build web`, before deploying. Needs `pip install fonttools==4.60.2`.
# The fonts in fonts/ are left whole: Android draws with them too.
#
#     bash scripts/subset_web_fonts.sh [build dir, build/web by default]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# A build dir given relative is relative to where this was called from.
BUILD="${1:-$ROOT/build/web}"
case "$BUILD" in
  /*) ;;
  *) BUILD="$PWD/$BUILD" ;;
esac
cd "$ROOT"

shopt -s nullglob
fonts=("$BUILD"/assets/fonts/*.ttf)
if [ ${#fonts[@]} -eq 0 ]; then
  echo "No fonts to cut in $BUILD/assets/fonts: build the web app first, or name its build directory." >&2
  exit 1
fi

# Name IDs 13 and 14 are the licence notice and its address, which the OFL
# asks every copy to carry; pyftsubset keeps only 0 to 6 unless told.
for font in "${fonts[@]}"; do
  pyftsubset "$font" \
    --unicodes-file=scripts/web_font_ranges.txt \
    --layout-features='*' \
    --name-IDs+=13,14 \
    --no-hinting \
    --output-file="$font.subset"
  mv "$font.subset" "$font"
done
echo "✓ fonts in $BUILD cut to scripts/web_font_ranges.txt"
