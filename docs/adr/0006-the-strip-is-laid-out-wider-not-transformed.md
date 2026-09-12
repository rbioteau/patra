# ADR-0006 — The strip is zoomed by laying it out wider, not by transforming it

**Status:** accepted · **Date:** 2026-09-11

## Context

The vertical direction has no zoom at all. `_VerticalScrollView`
(`reader_screen.dart:886`) is a `ListView.builder` whose every item is a
`SizedBox` of `width / chapter.aspectRatioFor(page)` drawn `BoxFit.fitWidth`
— a gapless strip whose heights are known from
`/api/Reader/file-dimensions` before a single image decodes
(`reader_screen.dart:915`). Nothing on that path is zoomable: `_zoomable`
is called only by the paged `_PagedView` (`reader_screen.dart:663`), and the
one-finger magnifying gesture is masked off in vertical because that drag is
how the chapter advances (`reader_screen.dart:403`, ADR-0001).

Every continuous reader we inspected scales **the strip**, not the page.
Kavita's own web reader applies a persisted percentage **width override** to
every image of its infinite scroller. Mihon holds one scale above its webtoon
`RecyclerView`, clamped `0.5–3.0`. Neko's Compose viewer holds one
`LazyColumn` scale (`0.5–3.0`), leaves `translationY` at zero and gives
one-pointer pan to x alone. Kotatsu's `WebtoonScalingFrame` clamps `0.5–2.5`
and forwards residual vertical movement back into nested scrolling.

The obvious Flutter implementation of "zoom" is `InteractiveViewer`, in one of
two shapes: one per page, or one around the whole list. Both are wrong here.

## Decision

Zooming the strip changes **the width the layout is built at**, not a
transform painted over a finished one.

- One width factor for the whole strip, held by the reader. `1.0` is the
  screen's width — where a chapter opens today, and the only neutral default.
  Range `0.5–3.0`.
- Page heights follow it: `height = width × factor / aspectRatio`. The list's
  extent, its scrollbar and the last page stay reachable because the numbers
  the scrollable is built from are the numbers it is drawn at.
- Two fingers change the factor around the focal point; **the pinch writes
  nothing**. The value that is written is the one in the settings sheet, and
  it is a [[Profile]] preference — a chapter opens at it and the pinch is a
  live adjustment on top, as a direction is.
- Delivered in two stages: **`0.5–1.0` first**, `>1×` after. Below `1×` the
  strip is never wider than the screen, so there is no horizontal pan and no
  axis to arbitrate; the whole of the gesture risk lives above `1×`.
- The word is **width factor** (`CONTEXT.md`), never *scale*: a scale is a
  transform over a page already laid out, and naming this one that makes the
  rejected implementation sound right.

## Why

Flutter's `Transform` is applied **just before painting** and is not taken
into account when calculating how much space a widget consumes. A transform
around the list can therefore draw a longer strip while the list's
`maxScrollExtent` stays where it was — which is exactly the failure in
flutter#86531, where a scaled scrollable can no longer reach its ends.

Two owners of one gesture are the other half of it. The gesture arena lets
only one competing recognizer win, and `InteractiveViewer` handles pan, scale
and rotate through the scale gesture, while the list needs the vertical drag.
The tracker has open reproductions for every flavour: scale on a `ListView`
sometimes not recognised (#65006), wheel or trackpad zooming and scrolling the
inner list at once (#70192), and the same scale-versus-scroll conflict inside
a paged scrollable (#68594). `Clip.none` does not rescue it — it lets the
child draw outside the viewer without extending where gestures are received.

One `InteractiveViewer` per page fails for a different reason: a pinch across
a seam between two pages has no owner, adjacent pages can settle at different
widths, and each matrix dies with the lazy lifecycle of the page that held it.

A custom sliver or render object would give complete control over focal
anchoring, culling and extent — and would mean reimplementing scrollable,
physics, restoration, semantics and accessibility. Nothing measured so far
says the page counts or the geometry need it.

## Considered options, and why not

1. **`InteractiveViewer` per page.** No coherent owner at a seam; per-page
   matrices that vanish on recycle; pages that drift apart.
2. **`InteractiveViewer` around the `ListView`.** Paint size is not scroll
   size; pan and scale compete with the vertical drag; wheel behaviour is
   ambiguous. Useful as a throwaway interaction mock and nothing more.
3. **Kavita-style width slider with no pinch.** Kept as the fallback if the
   gesture prototype does not hold: it needs no arbitration and its anchoring
   is trivial. We adopt its *shape of persistence* — a percentage width a
   person has chosen — but not as the only way in.
4. **A custom sliver / render object.** Reserved if the layout path fails
   measured performance or gesture acceptance criteria.

## Cost, accepted

- **Gesture arbitration is ours.** The framework offers no clean composition
  of scale and scroll, so a coordinator is written and tested against the
  transitions that actually break: first finger moving before the second
  lands, pinch during a fling, lifting one of two fingers, and returning to
  one-finger scrolling without a stuck recognizer. The prototype confirmed
  this is not optional — the stock composition fails the first of those
  outright.
- **Live relayout on every pinch update.** The alternative — a paint preview
  while two fingers are down, then one anchored commit on release — was
  measured against it and rejected: it saves about 0.6 ms of a ~1.2 ms pinch
  cost, which nothing can feel, and in the same run it was the *slower* of
  the two once its extra composited layer is counted. Neither dropped a frame.
  The conclusion is carried no further than `0.5–1.0`: it has to be
  re-measured above `1×`, on a device, with real pages.
- **Two enlargement mechanisms in one app** (the paged `InteractiveViewer` at
  5×, the strip's width factor at 3×). Assumed rather than unified: they are
  different objects, one a page under the finger and one a strip's width.
  Each row in the settings sheet says where it applies, which is the rule
  ADR-0001 already established for magnifying in vertical.
- **No pan below `1×`,** which is why the first stage stops there.

## Consequences

- **The decode width must follow the factor.** A page is currently decoded at
  its intrinsic size — only thumbnails are capped. At `0.5×` more pages are
  live in the same 250pt cache extent — measured at ~3 → ~5, because at these
  page heights the cache extent and not the viewport is what decides how many
  are built — so without a `cacheWidth` tied to the factor, zooming out
  multiplies decoded memory. With it the two effects pull against each other
  and memory stays near invariant. Since zooming out is the expected common
  case, this is on the critical path and not an optimisation to defer.
- **The strip cannot stay a `ListView.builder`.** `RenderSliverList` remembers
  where its first child was, in the old scale: change every height at once and
  the content shifts by roughly `offset × (1 − new/old)` — measured at ~58
  pages when zooming to `0.5×` at page 100 — and its `maxScrollExtent` is an
  average-based estimate, so the last page stops being reachable. That is the
  flutter#86531 failure arrived at without a transform. What works is
  `SliverVariedExtentList`, which is told every extent and derives offsets
  from them, so a change of every height is exact; it needs a
  `SliverChildDelegate` stating its own `estimateMaxScrollOffset`, which is
  what the thumbnail strip's `_StripDelegate` already does. The cost is a
  layout that is O(pages) — nothing at 200, worth watching at 2000.
- **At a document edge the anchor cannot be held** — there is no content left
  to put under the finger. It clamps and reports that it clamped (up to 189px
  at the last page) instead of quietly missing.
- **A rotation's correction is one frame late.** The new width is not known
  until layout, so the frame right after the resize is still drawn at the old
  offset.
- **The anchor is `(page, fraction within the page)`,** not a raw pixel
  offset: it survives heterogeneous page heights, a missing dimension, and a
  rotation. It is applied as one gagged transaction after the new heights
  exist — `jumpTo` from a layout callback is what this screen already died on.
- **The vertical rail is proportional to page height** because these offsets
  are already ours; where dimensions are missing every page shares the default
  ratio, and proportional collapses to uniform by itself.
- **Zoom cannot ask the server for more pixels.** `/api/Reader/image` takes
  `chapterId`, `page`, `apiKey` and `extractPdf` and nothing else; past `1:1`
  the strip upscales. Kavita's thumbnail endpoint serves 320×455, so an
  overview keeps using thumbnails and never full pages.
- **Order of work:** prototype the gesture and the anchor alone, then the
  layout, then the chrome. Zoom correctness is thereby independent of the
  navigation redesign, and every stage leaves something usable behind.

## Prototype

Both halves of the question were settled by a throwaway prototype kept on the
branch `prototype/reader-strip-width` (commit `838ffa4`), primary source
`lib/src/features/reader/prototype/strip_width/PROTOTYPE.md`: four variants
over a 200-page chapter, driven by synthetic pointers on the Linux desktop,
with the geometry read off the render tree rather than off the arithmetic that
asked for it. It chose live relayout over the paint preview, and it found the
sliver requirement above, which this ADR did not anticipate. Its frame times
are one run on one machine — the comparison *within* a run is the part that
carries, not the absolute numbers.

## Sources

- `docs/research/reader-vertical-zoom-and-navigation.md` — the survey this
  decision is drawn from, with permalinks to every reader inspected.
- `lib/src/features/reader/CLAUDE.md` — the layout hazards this screen has
  already hit, and the rule that a setting which does not apply says so.
- ADR-0001 — why the one-finger drag stays out of the vertical direction.
