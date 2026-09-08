import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// What a cover is drawn as where there is no picture of it — not yet, or
/// not at all.
///
/// Covers live in the image cache, which the device owns, is capped by the
/// budget in Settings and swept oldest-first, and which the OS may reclaim
/// outright. A stored series list therefore routinely outlives the pictures
/// of it, and a cover is deliberately never pinned (ADR-0005). So this is not
/// an error state: it is the ordinary look of a series the device remembers
/// and cannot picture, and it is honest about exactly that.
///
/// It is the prototype's own cover vocabulary — a 45° hatch in two near-black
/// tones, dark and low-contrast on purpose so it never competes with the real
/// artwork beside it, and different per series so a shelf of them stays
/// tellable apart. The tones are *derived* from the series id rather than
/// authored, which is what makes a tile the same tile between sessions.
///
/// In the middle, the series' initial in the serif. That is the app's
/// existing answer to "there is no picture of this thing" — the picker draws
/// a profile's initial on the profile's own colour — so it is one idea used
/// twice rather than a new one, and the serif because a series title is the
/// title of a work, which is the one thing the serif is for. Not the frond:
/// the frond is the app's identity, and stamping it on sixty tiles of
/// somebody's library says *Patra* where the tile should say *this series*.
class CoverPlaceholder extends StatelessWidget {
  const CoverPlaceholder({
    super.key,
    required this.seriesId,
    required this.seriesName,
  });

  /// Seeds the hatch — and it is the *series* even where the picture would
  /// have been a volume's or a chapter's. A column of chapter rows then reads
  /// as one series rather than as a stack of unrelated colours, and a series'
  /// tile on Home is recognisably the same tile as its hero on the series
  /// screen; the rows are told apart by their own numbering, two lines to the
  /// right of the cover.
  final int seriesId;

  /// Drawn as its first letter. A name that is empty draws none — the hatch
  /// alone still identifies the tile, where a placeholder glyph would only
  /// say something has gone wrong.
  final String seriesName;

  @override
  Widget build(BuildContext context) {
    final initial = seriesName.trim();
    return CustomPaint(
      painter: _Hatch(coverPlaceholderTones(seriesId)),
      // The letter is a widget rather than one more stroke in the painter so
      // that its size can be read off the box: the same drawing is asked for
      // at 46pt on a chapter row and at 152pt on a tablet's shelf.
      child: initial.isEmpty
          ? null
          : LayoutBuilder(
              builder: (context, constraints) => Center(
                child: Text(
                  // `characters`, not `substring(0, 1)`: a title starting on
                  // an astral character would otherwise be cut in half and
                  // drawn as a replacement glyph.
                  initial.characters.first.toUpperCase(),
                  style: PatraText.serifTitle(
                    size: constraints.biggest.shortestSide * _initialShare,
                    // Muted, and the token for it: [patraTextMuted] is tuned
                    // against a flat dark panel, which is what the hatch is.
                    color: patraTextMuted,
                  ),
                ),
              ),
            ),
    );
  }
}

/// The two tones one series' hatch is drawn in: near-black, a couple of
/// points apart, and the same pair every session.
///
/// The palette is the handoff's own, read off the four pairs it authors by
/// hand (`#26262c`/`#202026`, `#252a22`/`#20241d`, `#2c2222`/`#261d1d`,
/// `#34342a`/`#2d2d24`): a tenth of full saturation, lightness between .150
/// and .185, and the second tone .025 below the first. These colours are
/// this file's own and are deliberately not tokens — the same carve-out the
/// frond's parchment has, for the same reason: they are the mark of a
/// missing picture and must never appear in the UI as colours.
///
/// **What that palette can hold is 24 tiles, not 360.** At this darkness the
/// whole pair spans about eight units of each channel, so hue on its own
/// buys almost nothing: a tenth of the wheel apart still comes out two units
/// apart, which is to say identical. So the seed picks one of **six hue
/// sectors** — the wheel at 60°, which is where the handoff's own blue,
/// green, red and olive already sit — and one of **four brightness steps**
/// across its range. Twenty-four pairs a person can actually tell apart
/// beats three hundred they cannot, and it is why a library of sixty series
/// draws each tone two or three times rather than each series its own.
///
/// Nothing it returns can be read as [patraAccent] or [patraOffline], both
/// of which are spoken for: at a tenth of full saturation these are shades
/// of near-black that happen to lean, not colours.
({Color light, Color dark}) coverPlaceholderTones(int seriesId) {
  final choice = _mix(seriesId) % (_sectors * _steps);
  final hue = (choice % _sectors) * (360 / _sectors);
  final lightness = _dimmest + _brighter * (choice ~/ _sectors);
  return (
    light: HSLColor.fromAHSL(1, hue, _saturation, lightness).toColor(),
    dark: HSLColor.fromAHSL(1, hue, _saturation, lightness - _apart).toColor(),
  );
}

const _sectors = 6;
const _steps = 4;
const _saturation = .10;
const _dimmest = .150;
const _brighter = .0117; // .150 up to .185 in four, the handoff's range
const _apart = .025;

/// A series id mixed into a number.
///
/// Not `hashCode`, and not the id itself: series ids arrive consecutive — a
/// library numbers its series in a row — and an integer's hash is near enough
/// the integer, so neighbours would land in the same sector and every shelf
/// would be one colour. This is a bit-mixing hash, so they scatter. It is
/// written down here rather than borrowed from the platform because the tile
/// has to be the same tile after an upgrade, not merely within one run —
/// which is what `test/cover_placeholder_test.dart` pins by value.
int _mix(int seriesId) {
  var x = seriesId & 0xFFFFFFFF;
  x = ((x ^ (x >> 16)) * 0x7FEB352D) & 0xFFFFFFFF;
  x = ((x ^ (x >> 15)) * 0x846CA68B) & 0xFFFFFFFF;
  return x ^ (x >> 16);
}

/// The prototype draws a chapter row's numeral at 13pt on its 46pt cover,
/// and the letter takes that same share of whatever box it is given. Written
/// out rather than divided by [rowCoverWidth]: the two numbers agree today,
/// but resizing a row's cover is a layout decision and must not silently
/// rescale the letter on a tablet's shelf.
const _initialShare = .28;

/// The band, across the stripes, on a cover whose shorter side is [across]
/// — which on a 2:3 cover is its width.
///
/// The handoff hand-authors one per surface — 8pt on the 38 and 46pt covers
/// of its rows, 10pt on the 92pt cover of its hero and the ~124pt cover of
/// its grid — and a single widget has to answer for all of them. A fixed
/// number of points gives a row's cover five bands and a tablet's shelf tile
/// nineteen; a fixed share of the box shrinks the row's bands to 3.7pt of
/// noise. So it grows, and slowly: the **fourth root** of the box lands
/// within 0.7pt of all four numbers above.
double _bandFor(double across) => 10 * math.sqrt(math.sqrt(across / 124));

class _Hatch extends CustomPainter {
  const _Hatch(this.tones);

  final ({Color light, Color dark}) tones;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = tones.dark);
    // Bands measured across the stripes, as the CSS they come from measures
    // them: turn the canvas 45° and lay them down flat, so a band is its own
    // width whatever the shape of the box.
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(math.pi / 4);
    final band = _bandFor(size.shortestSide);
    final reach = size.width + size.height;
    final paint = Paint()..color = tones.light;
    for (var y = -reach; y < reach; y += band * 2) {
      canvas.drawRect(Rect.fromLTWH(-reach, y, reach * 2, band), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Hatch old) => old.tones != tones;
}
