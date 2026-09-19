#!/usr/bin/env bash
# Draw the demo library's pictures: four covers, six pages and an avatar.
#
#   ./tool/gen_demo_library.sh
#
# These are what the store screenshots show instead of somebody else's art.
# Every pixel here is generated from the app's own palette and its own bundled
# face, so a screenshot of the app pointed at `tool/demo_server.dart` carries no
# third party's rights at all — and the store gets a picture of the *app*,
# which is what it is for.
#
# Nothing is hand-drawn and nothing is fetched: re-running this is how the
# pictures change, the same contract as `tool/gen_app_icons.sh`.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT=store/demo
FONT=assets/fonts/SpaceGrotesk-Variable.ttf
SERIF=assets/fonts/Literata-Variable.ttf
BG='#111722'        # patraBg
SURFACE='#1C293E'   # patraSurface
SURFACE_HI='#26354B'
ACCENT='#D7B976'    # patraAccent — identity, never decoration
INK='#F3EEE3'       # patraText
MUTED='#AFB8C7'     # patraTextMuted

command -v convert >/dev/null || { echo "ImageMagick (convert) is required" >&2; exit 1; }
[ -f "$FONT" ] || { echo "$FONT is missing — the pictures are drawn in the app's own face" >&2; exit 1; }
[ -f "$SERIF" ] || { echo "$SERIF is missing — the pictures are drawn in the app's own serif" >&2; exit 1; }
mkdir -p "$OUT"

# The four series the demo server serves. Titles are invented and belong to
# nobody: a store screenshot needs something to read, not something to license.
SERIES=( "Nine Rivers" "Paper Moon" "Static Bloom" "The Lantern Keeper" )

# The one place these names live: the covers are drawn from this array, and
# `tool/demo_server.dart` reads this file back so the shelf, the series screen
# and the artwork cannot disagree about what a series is called.
printf '%s\n' "${SERIES[@]}" > "$OUT/titles.txt"

# ---- covers: 2:3, the ratio every cover in the app is drawn at -------------
i=0
for title in "${SERIES[@]}"; do
  i=$((i + 1))
  # A title long enough to need it gets its break spelled out: `-annotate`
  # does not wrap, and a cover that runs off its own edge looks broken.
  wrapped="$title"
  [ "$title" = "The Lantern Keeper" ] && wrapped="The Lantern
Keeper"

  convert -size 400x600 gradient:"$SURFACE-$SURFACE_HI" \
    -font "$FONT" -pointsize 34 -fill "$INK" -gravity center \
    -annotate +0-20 "$wrapped" \
    -fill "$ACCENT" -draw "rectangle 176,332 224,336" \
    -font "$FONT" -pointsize 16 -fill "$MUTED" -annotate +0+60 "DEMO LIBRARY" \
    -strip PNG24:"$OUT/cover-$i.png"
done

# ---- pages: 2:3, six of them, reused across every chapter ------------------
#
# Six and not one per chapter: the reader is what is being photographed, not
# the art, and a page that says which page it is tells a screenshot reader
# more than eighty unique drawings would.
for p in 1 2 3 4 5 6; do
  convert -size 1000x1500 xc:"$INK" \
    -fill "$BG" -draw "rectangle 0,0 1000,90" \
    -font "$FONT" -pointsize 30 -fill "$INK" -gravity north -annotate +0+28 "Demo Library" \
    -font "$SERIF" -pointsize 200 -fill "$BG" -gravity center -annotate +0-40 "$p" \
    -font "$FONT" -pointsize 26 -fill "$MUTED" -gravity south -annotate +0+60 "page $p of 6" \
    -stroke "$MUTED" -strokewidth 3 -fill none \
    -draw "rectangle 60,170 470,660" -draw "rectangle 530,170 940,520" \
    -draw "rectangle 60,700 470,1330" -draw "rectangle 530,560 940,1330" \
    -strip PNG24:"$OUT/page-$p.png"
done

# ---- the account's avatar, drawn by the picker before any session exists ---
convert -size 256x256 xc:"$SURFACE_HI" \
  -fill "$ACCENT" -draw "circle 128,128 128,24" \
  -font "$SERIF" -pointsize 120 -fill "$BG" -gravity center -annotate +0-6 "R" \
  -strip PNG24:"$OUT/avatar.png"

echo "Drew the demo library in $OUT:"
identify -format '  %f  %wx%h\n' "$OUT"/*.png