#!/usr/bin/env bash
# Build the book the device golden opens: a small EPUB nobody else owns.
#
#   ./tool/gen_golden_book.sh
#
# The golden (`integration_test/golden/README.md`) photographs a page of a
# book in the web engine that ships, and a page is only worth comparing if it
# is the same page every time and holds the three things a page of a book is
# made of: a heading, prose, and a picture. A book from somewhere else would
# do that by accident, if at all; this one does it on purpose, on its first
# page. Every word here was written for it and every pixel is drawn from the
# app's own palette, so it carries no third party's rights — the same contract
# as `tool/gen_demo_library.sh`.
#
# Its language is declared (`en`), because a book whose language is known is
# one the engine justifies and hyphenates (#130), and that is exactly the
# composition a test binding cannot draw.
#
# The archive is deterministic — fixed timestamps, fixed order, `mimetype`
# first and stored — so re-running this without changing it changes nothing
# git can see, given the same ImageMagick, fonts and zip. Changing the book
# means recording what Kavita makes of it again and then the references
# (`./tool/device_golden.sh --record`; integration_test/golden/README.md).
set -euo pipefail

cd "$(dirname "$0")/.."

OUT=integration_test/golden
BOOK="$OUT/golden-book.epub"
FONT=assets/fonts/SpaceGrotesk-Variable.ttf
SERIF=assets/fonts/Literata-Variable.ttf
BG='#111722'        # patraBg
SURFACE='#1C293E'   # patraSurface
SURFACE_HI='#26354B'
ACCENT='#D7B976'    # patraAccent
INK='#F3EEE3'       # patraText
OFFLINE='#8EACD8'   # patraOffline

for tool in convert zip; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done
[ -f "$SERIF" ] || { echo "$SERIF is missing — the cover is set in the app's serif" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/META-INF" "$WORK/OEBPS/images" "$OUT"

# ---- the pictures ----------------------------------------------------------
#
# The cover is what the library grid and the series screen draw; the plate is
# the picture on the first page, set between two paragraphs. The plate is
# wider than it is tall and has hard edges on purpose: a picture scaled or
# cropped wrongly by the engine shows at its borders first.
convert -size 600x900 gradient:"$SURFACE-$SURFACE_HI" \
  -font "$SERIF" -pointsize 58 -fill "$INK" -gravity center \
  -annotate +0-60 "The Lantern
Keeper" \
  -fill "$ACCENT" -draw "rectangle 270,470 330,475" \
  -font "$FONT" -pointsize 22 -fill "$INK" -annotate +0+120 "A GOLDEN BOOK" \
  -strip PNG24:"$WORK/OEBPS/images/cover.png"

convert -size 900x500 xc:"$BG" \
  -fill "$SURFACE" -draw "rectangle 0,330 900,500" \
  -fill "$SURFACE_HI" -draw "rectangle 0,360 900,500" \
  -fill "$OFFLINE" -draw "rectangle 0,420 900,426" \
  -fill "$ACCENT" -draw "circle 450,250 450,170" \
  -fill "$BG" -draw "circle 450,250 450,215" \
  -fill "$ACCENT" -draw "rectangle 444,330 456,420" \
  -stroke "$INK" -strokewidth 6 -fill none -draw "rectangle 3,3 896,496" \
  -strip PNG24:"$WORK/OEBPS/images/plate.png"

# ---- the words -------------------------------------------------------------

printf 'application/epub+zip' > "$WORK/mimetype"

cat > "$WORK/META-INF/container.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
EOF

cat > "$WORK/OEBPS/content.opf" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid" xml:lang="en">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">urn:uuid:9b1f3c52-6a1e-4f7e-9d63-132000000132</dc:identifier>
    <dc:title>The Lantern Keeper</dc:title>
    <dc:creator>Patra</dc:creator>
    <dc:language>en</dc:language>
    <dc:rights>Written and drawn for Patra's device golden; Apache-2.0, like the repository.</dc:rights>
    <meta property="dcterms:modified">2026-01-01T00:00:00Z</meta>
    <meta name="cover" content="cover"/>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="style" href="style.css" media-type="text/css"/>
    <item id="cover" href="images/cover.png" media-type="image/png" properties="cover-image"/>
    <item id="plate" href="images/plate.png" media-type="image/png"/>
    <item id="river" href="river.xhtml" media-type="application/xhtml+xml"/>
    <item id="night" href="night.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="river"/>
    <itemref idref="night"/>
  </spine>
</package>
EOF

cat > "$WORK/OEBPS/nav.xhtml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="en" xml:lang="en">
<head><title>Contents</title></head>
<body>
  <nav epub:type="toc">
    <ol>
      <li><a href="river.xhtml">The River</a></li>
      <li><a href="night.xhtml">The Night Shift</a></li>
    </ol>
  </nav>
</body>
</html>
EOF

cat > "$WORK/OEBPS/toc.ncx" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="urn:uuid:9b1f3c52-6a1e-4f7e-9d63-132000000132"/></head>
  <docTitle><text>The Lantern Keeper</text></docTitle>
  <navMap>
    <navPoint id="river" playOrder="1"><navLabel><text>The River</text></navLabel><content src="river.xhtml"/></navPoint>
    <navPoint id="night" playOrder="2"><navLabel><text>The Night Shift</text></navLabel><content src="night.xhtml"/></navPoint>
  </navMap>
</ncx>
EOF

# The book's own stylesheet: a few rules a publisher really writes, so the
# page is composed by its own CSS as well as the reader's layer — a centred
# figure, an italic caption, a heading with a rule under it. It says nothing
# about alignment or hyphens, which is what leaves those to the engine.
cat > "$WORK/OEBPS/style.css" <<'EOF'
h1 {
  font-size: 1.6em;
  margin: 0 0 1em 0;
  padding-bottom: 0.3em;
  border-bottom: 1px solid currentColor;
}
p {
  margin: 0;
  text-indent: 1.5em;
}
h1 + p, figure + p {
  text-indent: 0;
}
figure {
  margin: 1.2em 0;
  text-align: center;
}
figure img {
  width: 100%;
  height: auto;
}
figcaption {
  font-style: italic;
  font-size: 0.85em;
  margin-top: 0.4em;
}
EOF

cat > "$WORK/OEBPS/river.xhtml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
  <title>The River</title>
  <link rel="stylesheet" type="text/css" href="style.css"/>
</head>
<body>
  <h1>The River</h1>
  <p>Every evening, when the barges had tied up below the old customs house and the ferrymen had gone home to their suppers, Ilse climbed the iron ladder to the lantern room and wound the clockwork that turned the light. It was not a large light. It had never guided a steamship or saved a fishing fleet, and the harbourmaster privately considered it a municipal extravagance. But the river bent sharply there, around a bank of shingle that shifted with every flood, and the light showed the bend.</p>
  <p>Her grandmother had kept it before her, and had kept a ledger beside it: the hour of lighting, the state of the water, the boats that passed in the dark. Ilse kept the ledger too, in the same unhurried handwriting, although nobody had asked to read it in forty years.</p>
  <figure>
    <img src="images/plate.png" alt="A gold lantern above a dark river, with a blue line of water under it."/>
    <figcaption>The light at the bend, as the ledger&#8217;s first page drew it.</figcaption>
  </figure>
  <p>On clear nights she could see the reflection of the lamp reach almost to the far bank, a trembling ribbon of gold laid across the current. On foggy nights she could see nothing at all, and wound the clockwork anyway, because the whole point of a light is that it is there when you cannot see it.</p>
</body>
</html>
EOF

cat > "$WORK/OEBPS/night.xhtml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<head>
  <title>The Night Shift</title>
  <link rel="stylesheet" type="text/css" href="style.css"/>
</head>
<body>
  <h1>The Night Shift</h1>
  <p>The clockwork ran for six hours on a single winding, which meant that someone had to climb the ladder again at midnight. For most of her life that someone had been her grandmother, who claimed she slept better for the interruption.</p>
  <p>Ilse did not sleep better for it. She lay awake for an hour afterwards, listening to the water, and wrote in the ledger that the river was <em>high and quiet</em>, which it almost always was.</p>
</body>
</html>
EOF

# ---- the archive -----------------------------------------------------------
#
# `mimetype` first and stored, as the format requires; everything else in a
# fixed order with a fixed timestamp and no extra fields, so the bytes are the
# bytes whoever runs this and whenever.
find "$WORK" -exec touch -h -d '2026-01-01 00:00:00 UTC' {} +
rm -f "$BOOK"
BOOK_ABS="$(pwd)/$BOOK"
(
  cd "$WORK"
  TZ=UTC zip -X -0 -q "$BOOK_ABS" mimetype
  TZ=UTC zip -X -9 -q "$BOOK_ABS" \
    META-INF/container.xml \
    OEBPS/content.opf OEBPS/nav.xhtml OEBPS/toc.ncx OEBPS/style.css \
    OEBPS/river.xhtml OEBPS/night.xhtml \
    OEBPS/images/cover.png OEBPS/images/plate.png
)

echo "Built $BOOK:"
unzip -l "$BOOK" | sed 's/^/  /'
