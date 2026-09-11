# Continuous vertical reader: zoom and navigation research

**Status:** research and design recommendation  
**Researched:** 2026-09-11  
**Scope:** Patra's **vertical scrolling** reading direction only. Paged reading and its accepted one-finger **magnifying** gesture are context, not targets for redesign.

## Executive recommendation

Build zoom as **one coherent, layout-sized vertical strip**, not as an `InteractiveViewer` around each page or around the `ListView`.

- Keep `1.0` as fit-to-width. Let a two-finger pinch change one strip-wide width factor, provisionally `0.5–3.0`; center when narrower than the viewport and permit bounded horizontal pan when wider. Mihon and Neko use `0.5–3.0`, while Kotatsu uses `0.5–2.5`, so that is a reasonable prototype range rather than a novel convention. [Mihon implementation][Mihon-webtoon-rv] [Neko zoom implementation][Neko-compose-zoom] [Kotatsu scaling frame][Kotatsu-scale]
- Continue to give one-finger vertical movement to the chapter scroll. Do **not** extend Patra's momentary one-finger magnifying gesture to this direction: Patra deliberately excludes it because that drag is the only direct way to advance through the strip. [Patra ADR][P-adr] [Patra reader selection][P-reader-mode]
- Make scaled page width and page height real layout dimensions. Preserve the content beneath the pinch focal point as `(page, fraction within page)` whenever scale or viewport width changes. A paint-only transform does not contribute its transformed size to layout or the scroll extent. [Flutter Transform][F-transform]
- For vertical navigation, target a compact page counter plus a page slider/rail while chrome is visible, with thumbnails available in an on-demand overview. Do not permanently spend the bottom of a phone on the full accordion strip. Mihon exposes a page slider in horizontal or vertical form, Neko uses page text plus a slider, and Panels has added a side thumbnail panel specifically for vertical-scroll comics. [Mihon navigator][Mihon-nav] [Neko controls][Neko-controls] [Panels App Store][Panels-store]
- Keep Patra's current thumbnail strip unchanged for paged reading. During a first implementation, it is acceptable to keep that same strip in vertical scrolling as a safe migration step; the target is to retain visual seeking without retaining permanent vertical-reader chrome.
- Add no package initially. The surveyed packages solve image zoom, galleries, or list observation, not the combined contract of one zoom state, one vertical scroll position, variable page heights, focal-point anchoring, and cross-page continuity. [Package survey](#package-options)

This recommendation is intentionally not “wrap it in `InteractiveViewer`.” Flutter's own tracker still has open reports for unreliable scale recognition with `ListView`, simultaneous list scrolling during zoom, unreachable ends after scaling a scrollable, and the broader inability to cleanly combine scale and scroll recognizers. [Flutter #65006][F-65006] [Flutter #70192][F-70192] [Flutter #86531][F-86531] [Flutter #15011][F-15011]

## What “zoom” means here

The desired object is the chapter strip, not an individual image:

1. Adjacent pages remain adjacent at every scale.
2. A reader can pinch while a boundary between two pages is visible.
3. Releasing the pinch leaves a stable scale; ordinary one-finger vertical scrolling continues through every page.
4. Wider-than-screen content pans horizontally, but vertical movement remains chapter progress rather than a second, hidden pan coordinate.
5. A scale or orientation change keeps the same artwork in view instead of merely retaining the same raw scroll offset.

That differs from Patra's existing **magnifying** gesture, which is momentary, belongs to a paged screen, reaches 2.5× over a 400-logical-pixel one-finger drag, and returns on release. [Patra ADR][P-adr]

## Current Patra behavior

### Vertical scrolling

- `ReadingDirection.verticalScroll` selects `_VerticalScrollView`; the paged `_PagedView` is a separate branch. Landscape spreads are also limited to the paged branch. [Patra reader selection][P-reader-mode]
- `_VerticalScrollView` is a vertical `ListView.builder` with zero padding and one item per page. Every item is full viewport width, has a height calculated from server-provided page dimensions, and draws with `BoxFit.fitWidth`, producing a gapless fit-width strip. [Patra vertical view][P-vertical]
- Those dimensions are converted into complete `_heights` and cumulative `_offsets` arrays before images decode, so an initial or requested page can be jumped to exactly by page top. [Patra vertical geometry][P-vertical]
- The current page is the page under a probe at 30% of the viewport height. Scroll-originated changes save reading progress and precache the following page; a slider/thumbnail seek jumps to the requested page top. [Patra page tracking][P-vertical] [Patra progress][P-progress]
- Initial placement is deferred until after the first layout because offsets depend on viewport width; reporting is suppressed until placement, preventing an open at page 40 from being overwritten by the temporary offset-zero page. [Patra vertical placement][P-vertical]
- A tap anywhere over the vertical strip toggles Patra and system chrome. Unlike paged reading, there are no side tap zones in this direction. [Patra tap layer][P-reader-mode]

### Zoom and gestures

- The profile-scoped magnifying preference is explicitly masked off in vertical scrolling. Paged pages instead use the custom magnifying widget when enabled or `InteractiveViewer(maxScale: 5)` when it is not. [Patra zoom branch][P-reader-mode] [Patra paged zoom][P-paged]
- Consequently, vertical scrolling currently has no pinch zoom, double-tap zoom, persistent width control, or horizontal pan implementation. This is a direct reading of the only vertical-view branch and its item builder. [Patra vertical view][P-vertical]
- Patra's accepted ADR says why one-finger magnifying cannot simply be enabled here: it takes ownership of the same drag that advances a vertically scrolling chapter. [Patra ADR][P-adr]

### Navigation chrome

- Both reading branches currently share `_BottomChrome`: an accordion thumbnail per page, a discrete page slider, and a current/total page counter. A selected thumbnail or slider movement calls the same page-level seek. [Patra bottom chrome][P-bottom]
- The strip supports direct visual recognition, horizontal dragging/flicking, and tapping. It only draws the visible window and follows the slider's linear page position rather than centering the current thumbnail. [Patra thumbnail geometry][P-thumbs]
- Online thumbnails come from `/api/Reader/thumbnail`; offline thumbnails decode resized copies of saved full pages. Decode width is capped at 320 device pixels because Kavita's default thumbnail bounding size is 320×455. [Patra image provider][P-images] [Kavita thumbnail size][K-thumb-size]
- The chapter's thumbnails begin loading only after the strip has been opened, and the queue then fills visible pages before backfilling. The queue is owned by the reader so hiding chrome does not discard completed work. [Patra thumbnail queue][P-thumb-queue]

### Constraints already established in this repository

- Reading direction, magnifying, and other reader choices are Patra profile preferences and are not sent to Kavita; the repository vocabulary treats vertical scrolling as a reading direction, not a separate “webtoon mode.” [Patra context][P-context]
- The reader has already encountered layout-phase failures from rebuilding or commanding scroll positions under `LayoutBuilder`; reader-specific guidance says not to wrap the whole reader in a layout builder and not to reach back into reader state from lazy child construction. [Patra reader guidance][P-guidance]
- Patra currently has no zoom/gallery/list-observation dependency; its image path already uses Flutter `Image`, `ResizeImage`, and `cached_network_image`. [Patra dependencies][P-pubspec] [Patra image provider][P-images]

## Established-reader comparison

The open-source entries below were inspected at immutable commits listed in [Sources](#sources). Commercial entries are limited to behavior their publisher or App Store listing actually states; undocumented behavior is not inferred from screenshots or memory.

| Reader | Continuous strip and zoom | Navigation | Relevant defaults/settings | Takeaway for Patra |
|---|---|---|---|---|
| **Kavita Web** | `ReaderMode.Webtoon` is scrolling, while `UpDown` is a distinct paged vertical mode. Its infinite scroller renders block images and applies a persisted percentage width override to every image. [Kavita modes][K-modes] [Kavita scroller template][K-scroller-html] [Kavita width behavior][K-width] | Programmatic page changes call `scrollIntoView`; the width effect also moves the current image into view after resizing. [Kavita width behavior][K-width] [Kavita scroller][K-scroller] | Reading profiles persist reader mode, scaling option, automatic webtoon detection, nullable width override, and a breakpoint at which the override is disabled. [Kavita profile][K-profile] | Strong precedent for strip-wide **layout width**, but its resize restoration is only page-level: it scrolls the current image into view rather than preserving an intra-page focal point. [Kavita width behavior][K-width] |
| **Mihon** | Its webtoon `RecyclerView` carries one global scale, clamps it to `0.5–3.0`, supports pinch and 2× double-tap, and adjusts the containing view's height when zoomed below 1. [Mihon implementation][Mihon-webtoon-rv] | It has an optional page counter and a chapter navigator containing current/total plus a page slider; the navigator can be horizontal or a left/right vertical rail. [Mihon counter][Mihon-counter] [Mihon navigator][Mihon-nav] [Mihon navigator wiring][Mihon-nav-wire] | Double-tap zoom defaults on; crop borders defaults off; side padding defaults to 0; “disable zoom out” defaults off. [Mihon preferences][Mihon-prefs] | A single strip scale and axis-matched rail are useful precedent. Its custom Android view is not a drop-in model for Flutter gesture arbitration. |
| **TachiyomiSY** | The current fork retains Mihon's double-tap and zoom-out controls and adds webtoon smooth-scroll and page-transition controls in its settings surface. [SY webtoon settings][SY-settings] | It exposes the configurable vertical navigator by reading mode, side, and height. [SY navigator settings][SY-nav] | Its current webtoon zoom defaults match Mihon: double-tap on, side padding 0, crop off, zoom-out allowed. [SY preferences][SY-prefs] | Confirms these controls survive in a feature-heavy fork; it does not remove the need for a bespoke Flutter strip implementation. |
| **Kotatsu** | A `WebtoonScalingFrame` wraps the recycler, clamps `0.5–2.5`, handles pinch, double-tap, keys/Ctrl-wheel and horizontal/vertical transformed movement, and forwards pending vertical movement into nested scrolling. [Kotatsu scaling frame][Kotatsu-scale] | Its reader action bar has a page slider and a button that opens page thumbnails; zoom-in/out methods are also exposed by the webtoon fragment. [Kotatsu actions][Kotatsu-actions] [Kotatsu fragment][Kotatsu-fragment] | Webtoon zoom defaults on, zoom-out defaults to 0%, optional page gaps default off, and optional zoom buttons default off. [Kotatsu preferences][Kotatsu-prefs] | Best precedent for keeping visual page browsing on demand and for explicitly handing vertical motion back to the scrollable. It is also evidence that this coordination requires custom code. |
| **Neko** | Its Compose implementation uses one `LazyColumn` scale (`0.5–3.0`), consumes two-pointer zoom, permits one-pointer **horizontal** pan above 1×, leaves `translationY` at zero, and keeps the column vertically scrollable. [Neko layout][Neko-compose-layout] [Neko zoom implementation][Neko-compose-zoom] | Programmatic slider/TOC requests scroll the lazy list to an item; reader bottom controls carry page text and a page slider. [Neko initial/seek][Neko-compose-start] [Neko controls][Neko-controls] | Side padding, optional gaps, optional zoom-out, and page-layout settings are separate webtoon preferences. [Neko preferences][Neko-prefs] | Closest gesture policy to the recommendation: pinch owns two pointers, horizontal pan owns x, normal scrolling owns y. Its `graphicsLayer` remains paint-only, so Patra should improve on it by making vertical extents layout-real. [Neko layout][Neko-compose-layout] [Flutter Transform][F-transform] |
| **Panels** | The publisher advertises configurable reading modes, a one-finger zoom, and a dedicated vertical-scroll mode. It does not state on that page whether the one-finger zoom applies to the vertical mode. [Panels site][Panels-site] | App Store release notes describe a right-side panel for vertical-scroll comics whose thumbnails jump to a page and approximate vertical position. [Panels App Store][Panels-store] | The App Store description also advertises horizontal, vertical, and panel-by-panel reading presets. [Panels App Store][Panels-store] | Direct support for a vertical-specific, on-demand thumbnail surface; do not over-read the general zoom claim. |
| **YACReader iOS** | Its official App Store description states continuous vertical scroll for webtoon, several fit modes, margin trimming, configurable hot areas, automatic scroll, and guided panel zoom. It does **not** explicitly say that arbitrary pinch zoom operates across its continuous strip. [YACReader App Store][YAC-store] | The same official description establishes configurable hot areas; it does not document thumbnail scrubbing for the continuous mode. [YACReader App Store][YAC-store] | Mode-specific zoom persistence or scale limits are not stated in the official description reviewed. [YACReader App Store][YAC-store] | Confirms that fit/crop/tap controls commonly accompany continuous reading, but supplies no primary-source basis for copying a strip-zoom mechanic. |

### Consumer webtoon platforms: evidence boundary

The reviewed official WEBTOON, Tapas, and Manta listings describe their catalog and service but do not specify in-reader zoom, page sliders, or thumbnail navigation. Those products therefore are not evidence for a particular zoom/navigation behavior in this decision. Chunky's current listing documents single/two-page and right-to-left reading, but not a continuous vertical mode; a historical release note mentions a thumbnail while dragging its page slider, which is insufficient vertical-reader evidence. [WEBTOON App Store][WEBTOON-store] [Tapas App Store][Tapas-store] [Manta App Store][Manta-store] [Chunky App Store][Chunky-store]

### Comparison synthesis

1. **Scale belongs to the strip.** Kavita changes every image's width; Mihon, Kotatsu, and Neko hold one scale above the scrolling collection. None of the inspected implementations gives every page an independent remembered scale. [Kavita width behavior][K-width] [Mihon implementation][Mihon-webtoon-rv] [Kotatsu scaling frame][Kotatsu-scale] [Neko layout][Neko-compose-layout]
2. **Vertical motion remains navigation.** Neko restricts one-pointer zoomed pan to x, and Kotatsu explicitly forwards residual y movement to nested scroll. [Neko zoom implementation][Neko-compose-zoom] [Kotatsu scaling frame][Kotatsu-scale]
3. **Zoom-out and whitespace are legitimate controls.** Mihon/Neko permit a 0.5 minimum when enabled, Kotatsu offers a default zoom-out amount, and Kavita's percentage width override is a persisted narrower layout. [Mihon implementation][Mihon-webtoon-rv] [Neko zoom implementation][Neko-compose-zoom] [Kotatsu preferences][Kotatsu-prefs] [Kavita profile][K-profile]
4. **Navigation stays page-addressable even in a continuous strip.** All inspected open-source readers retain a current page and programmatic page jump; their chrome favors counters and sliders, while Kotatsu and Panels make visual page browsing a separate surface. [Kavita scroller][K-scroller] [Mihon navigator][Mihon-nav] [Kotatsu actions][Kotatsu-actions] [Neko controls][Neko-controls] [Panels App Store][Panels-store]
5. **No reliable commercial-source consensus exists for vertical pinch behavior.** Panels' one-finger claim is not mode-qualified, YACReader only explicitly ties zoom to guided panels, and the official platform listings omit the interaction. [Panels site][Panels-site] [YACReader App Store][YAC-store] [WEBTOON App Store][WEBTOON-store]

## Flutter gesture and layout mechanics

### Why `InteractiveViewer` is not the architecture

`InteractiveViewer` is a child pan/zoom viewport. Its defaults are `Clip.hardEdge`, zero boundary margin, `constrained: true`, pan and scale enabled, and a `0.8–2.5` scale range. `TransformationController` and interaction callbacks make the matrix observable and controllable. [Flutter InteractiveViewer source][F-iv]

That is useful for Patra's one-screen paged branch, but it has three mismatches with the continuous strip:

1. **Paint extent is not scroll extent.** Flutter's `Transform` documentation says the transform is applied just before painting and is not considered when calculating consumed space. A whole-list transform can therefore draw a longer strip without making the list's `maxScrollExtent` equally longer; this is the failure reported in Flutter #86531. [Flutter Transform][F-transform] [Flutter #86531][F-86531]
2. **Two scroll owners compete.** `InteractiveViewer` handles pan, scale, and rotate through the scale gesture; a one-pointer scale gesture is classified as pan. A nested `ListView` also needs the vertical drag. Flutter's gesture arena permits only one competing recognizer to win, and changing hit-test behavior does not make parent and child recognizers share the gesture. [Flutter InteractiveViewer gesture code][F-iv-gesture] [Flutter gesture arena][F-arena] [Flutter GestureDetector][F-gesture-detector]
3. **Clipping cannot repair geometry.** `Clip.none` allows drawing outside the viewer's original area but does not extend its gesture-receiving area, creating dead zones unless the viewer itself occupies the whole interactive area. [Flutter InteractiveViewer source][F-iv]

The official issue tracker demonstrates, rather than merely predicts, the edge cases: `ListView` scale is sometimes not recognized (#65006), wheel/trackpad input can zoom and scroll the inner list simultaneously (#70192), scaled scrollables can no longer reach their ends (#86531), and even `InteractiveViewer` nested in a paged scrollable has an unresolved scale/scroll report (#68594). All remain open in the inspected tracker state. [Flutter #65006][F-65006] [Flutter #70192][F-70192] [Flutter #86531][F-86531] [Flutter #68594][F-68594]

### Gesture policy to prototype

Proposed ownership:

| Input | At 1× or below | Above 1× |
|---|---|---|
| One-finger vertical drag / wheel | `ListView` scroll | `ListView` scroll |
| One-finger horizontal drag | no action | bounded horizontal pan |
| Two-finger pinch | change strip scale around focal point | change strip scale around focal point |
| Two-finger translation | update focal anchor; x may pan | update focal anchor; x may pan |
| Double tap | optional 2× around tap | reset to 1× |
| `+`, `-`, reset controls | accessible stepped zoom | accessible stepped zoom/reset |

A stock `GestureDetector.onScale*` is not automatically sufficient because scale is a superset of pan, and the framework explicitly disallows simultaneous pan and scale callbacks on the same detector. The implementation should prototype either coordinated custom recognizers (potentially a gesture-arena team plus a custom scroll recognizer) whose scale path activates on the second pointer, or raw-pointer observation plus deliberate scroll enable/disable while two pointers are active. `RawGestureDetector` and `Listener` are the framework's extension points for those approaches. [Flutter GestureDetector][F-gesture-detector]

Do not accept a prototype merely because pinch works from rest. It must also cover “first finger moved before second finger landed,” pinch during a list fling, lifting one of two fingers, and returning immediately to one-finger scrolling; Flutter #65006 and #15011 describe precisely this scale-plus-scroll transition problem. [Flutter #65006][F-65006] [Flutter #15011][F-15011]

### Layout and anchoring

For viewport width `V`, proposed width factor `z`, and page aspect ratio `a[i] = width / height`:

```text
contentWidth(z) = V × z
pageHeight(i, z) = contentWidth(z) / a[i]
pageTop(i, z) = sum(pageHeight(j, z), j < i)
```

The list item should have the real `pageHeight`; inside it, an overflow/clipped presentation can center a narrower image or translate a wider image horizontally. This keeps the vertical sliver geometry and scrollbar extent truthful while retaining lazy page widgets. The formula reuses the same page-dimension data Patra already turns into heights and offsets. [Patra vertical geometry][P-vertical]

Before a scale/viewport-width change, capture:

```text
anchorPage = page containing (scrollOffset + focalY)
withinPage = ((scrollOffset + focalY) - oldPageTop) / oldPageHeight
horizontalFraction = (focalX - oldContentLeft) / oldContentWidth
```

After relayout, target:

```text
newScrollOffset = newPageTop + withinPage × newPageHeight - focalY
newPanX = focalX - horizontalFraction × newContentWidth
          - centeredContentLeft(newContentWidth)
```

Clamp vertical offset to the list extent and horizontal pan to the artwork edges. The `(page, withinPage)` anchor is preferable to multiplying raw scroll pixels because it survives heterogeneous page aspect ratios, missing dimensions, and future page gaps.

Flutter's default scroll correction does not provide this semantic anchor: base `ScrollPhysics.adjustPositionForNewDimensions` returns the new position's existing pixel value, and the open scroll-anchoring request documents visible jumps when variable-height content above the viewport changes. [Flutter ScrollPhysics][F-scroll-physics] [Flutter #99158][F-99158]

In Patra, apply anchor correction as an explicit, gagged transaction after the new dimensions exist—analogous to `_placed` during initial vertical placement—not by calling `jumpTo` from a layout callback. Patra's reader guidance records why commanding layout from layout already failed in this screen. [Patra vertical placement][P-vertical] [Patra reader guidance][P-guidance]

### Image decode and performance implications

- Patra's reading image provider requests the full page and does not pass a decoder `cacheWidth`; only thumbnails are wrapped in `ResizeImage`. Zooming therefore needs no new Kavita resolution endpoint, but large source images still carry decode, texture, and cache cost. [Patra image provider][P-images]
- Updating real width can recalculate the numeric height/offset arrays in O(page count), while `ListView.builder` still limits built page widgets to its lazy window. Patra already computes one height and cumulative offset for every page when width changes. [Patra vertical geometry][P-vertical]
- A performance prototype should compare live relayout on every pinch update with a hybrid: paint-preview only while two fingers are down, then one anchored layout commit on release. The latter reduces relayout pressure but must not permit scrolling into temporarily unrepresented transformed extent.
- Keep page widgets keyed by page and avoid invalidating image providers when only geometry changes; otherwise zoom becomes network/cache churn rather than layout.

## Kavita image APIs and what they permit

The repository's pinned Kavita **0.9.0.0 OpenAPI** is the compatibility contract; the inspected Kavita implementation snapshot agrees with it for these routes. [Patra OpenAPI][P-openapi] [Kavita reader controller][K-reader-api]

### `/api/Reader/image`

Parameters are `chapterId`, `page`, `apiKey`, and `extractPdf`; there is no width, height, density, quality, crop, or resolution parameter. The server ensures/caches the chapter and returns the cached page path. [Patra OpenAPI image operation][P-openapi] [Kavita reader controller][K-reader-api]

**Consequence:** strip zoom cannot request a server-selected resolution. It should reuse the existing page provider and cached page. Adding a fictitious query parameter would at best be ignored and at worst break cache identity.

### `/api/Reader/thumbnail`

Parameters are `chapterId`, `pageNum`, and `apiKey`; there is no requested-size parameter. On first generation, the server writes thumbnails with `WriteCoverThumbnail`'s default `CoverImageSize.Default`, whose bounding dimensions are 320×455. [Patra OpenAPI thumbnail operation][P-openapi] [Kavita thumbnail generation][K-thumb-gen] [Kavita thumbnail size][K-thumb-size]

**Consequence:** thumbnails are appropriate for a navigator or overview, never as zoomed reading content. A visual overview should continue using Patra's current thumbnail endpoint and local decoder cap rather than fetching full online pages. [Patra image provider][P-images]

### `/api/Reader/file-dimensions` and chapter info

`/api/Reader/file-dimensions` returns the dimensions for all pages after ensuring the chapter cache; `chapter-info?includeDimensions=true` can also include cached page dimensions. [Patra OpenAPI dimensions operation][P-openapi] [Kavita reader controller][K-reader-dimensions]

**Consequence:** Patra can establish all page heights and anchor math before image decode, exactly as the current vertical view does. Unknown/invalid dimensions still need a fallback aspect ratio and a later anchor-preserving correction rather than a raw-height jump.

### Kavita reading-profile settings

Kavita persists a `WidthOverride` and `DisableWidthOverride` breakpoint in its reading profile, and the web client interprets positive values as percentages up to 100%. It also persists automatic webtoon detection and requires at least three page dimensions before its client-side detector can switch modes. [Kavita profile][K-profile] [Kavita profile UI][K-profile-ui] [Kavita detector][K-detector] [Kavita detector gate][K-detector-gate]

**Recommendation:** use this as design precedent, not as Patra's persistence API. Patra's established rule is that its reading preferences follow its own profile locally and are not sent to the server. [Patra context][P-context]

## Package options

Versions are the latest values returned by pub.dev on the research date; this is a capability check, not a claim that latest publication date alone measures project health.

| Package | Primary-source capability | Fit for this problem | Decision |
|---|---|---|---|
| [`photo_view` 0.15.0][Pkg-photo] | Gesture-sensitive zoomable widget plus gallery use cases. [pub.dev][Pkg-photo] | Good for a page/gallery; no strip-wide variable-height scroll/anchor contract is advertised. | Do not add. |
| [`extended_image` 10.1.0][Pkg-extended] | Network image states/cache plus zoom/pan, photo view, gallery, slide-out, crop/rotate/flip, and painting. [pub.dev][Pkg-extended] | Broadest image machinery, but much more surface than needed and no advertised single continuous-strip layout owner. | Do not add for phase 1. Revisit only if image decode/gesture features beyond zoom are separately required. |
| [`easy_image_viewer` 1.5.1][Pkg-easy] | Pinch/zoom, multi-image viewing, and a full-screen dialog. [pub.dev][Pkg-easy] | Its abstraction is an image viewer/gallery, not an already-visible continuous chapter. | Do not add. |
| [`scrollview_observer` 1.27.1][Pkg-observer] | Observes child widgets displayed in a `ScrollView` and supports locating list children. [pub.dev][Pkg-observer] | Could help identify/restore an anchor but does not implement zoom; Patra already has exact dimension-derived offsets and page tracking. | Do not add initially. Reconsider if variable unknown heights replace exact geometry. |

A native implementation is the smaller dependency boundary: keep `ListView`, `ScrollController`, existing dimension arrays, and image providers; add only strip geometry, horizontal pan state, and a narrowly tested gesture coordinator. Patra's dependency file confirms none of the surveyed packages is currently declared. [Patra dependencies][P-pubspec]

## Design options

### Option 1 — Kavita-style width control only

**Shape:** Add a settings slider that lays every page out at, for example, 50–100% viewport width; center the strip; no pinch and no width above fit-to-width. Kavita's web reader is the direct precedent. [Kavita width behavior][K-width]

**Advantages:** smallest implementation; no gesture-arena conflict; real heights and straightforward anchoring; useful on tablets and for pages intended to be narrower than the screen.

**Costs:** not zoom-in; poor discoverability during reading; cannot inspect text/detail beyond source fit; less useful on phones.

**Verdict:** safe fallback or phase-zero experiment, not a complete answer to zoom.

### Option 2 — one `InteractiveViewer` per page

**Shape:** Keep the `ListView`, wrap each image independently, and store a scale/matrix for every built page.

**Advantages:** trivial demo; preserves lazy list construction; uses a framework widget already used by Patra's paged reader. [Patra paged zoom][P-paged]

**Costs:** a pinch across a seam has no coherent owner; adjacent pages can have different widths/pans; vertical pan conflicts with list scroll; matrices disappear/reappear with lazy page lifecycle unless separately stored; cross-page continuity is lost. Flutter's gesture arena allows only one nested recognizer to win. [Flutter GestureDetector][F-gesture-detector]

**Verdict:** reject. It violates the definition of strip zoom.

### Option 3 — one `InteractiveViewer` around the `ListView`

**Shape:** Transform the entire scrolling list with one matrix.

**Advantages:** one apparent scale and one matrix; very small proof of concept.

**Costs:** transformed paint size is not layout size; list extent and boundaries disagree after zoom; inner scrolling and outer pan/scale compete; desktop wheel/trackpad behavior is ambiguous; Flutter has open reproductions of all three classes of failure. [Flutter Transform][F-transform] [Flutter #65006][F-65006] [Flutter #70192][F-70192] [Flutter #86531][F-86531]

**Verdict:** reject for production. It is useful only as a throwaway interaction mock.

### Option 4 — layout-scaled lazy strip with a custom gesture coordinator

**Shape:** Keep one vertical `ListView`; store one width factor and one horizontal pan; make every item height follow scaled width; route one-finger y to the list, two-finger scale to strip geometry, and zoomed one-finger x to bounded pan. Restore `(page, within-page fraction)` around the pinch focal point.

**Advantages:** coherent pages and seams; truthful scroll extent; exact pre-decode geometry from Kavita dimensions; preserves lazy image widgets and Patra's current progress model; matches the strongest cross-reader interaction precedent without copying Android/Compose paint-only geometry. [Patra vertical geometry][P-vertical] [Neko zoom implementation][Neko-compose-zoom] [Kotatsu scaling frame][Kotatsu-scale]

**Costs:** requires custom gesture arbitration and carefully phased anchor correction; live pinch can trigger frequent relayout; horizontal overflow/hit testing must be explicit; semantics and keyboard controls must be designed rather than inherited from `InteractiveViewer`.

**Verdict:** **recommend**, gated by a gesture/performance prototype.

### Option 5 — custom sliver/render-object “document canvas”

**Shape:** Own virtualized layout, hit testing, scale, scroll, and paint in a custom sliver or render object, conceptually similar to a purpose-built two-dimensional document viewport.

**Advantages:** complete control over focal anchoring, culling, scroll extent, gesture handoff, and paint-preview/commit behavior.

**Costs:** largest correctness and maintenance burden; reproduces substantial scrollable, semantics, restoration, physics, and accessibility behavior; no evidence that current page counts or geometry require abandoning `ListView`.

**Verdict:** reserve only if Option 4 fails measured performance or gesture acceptance criteria.

## Recommended design in detail

### 1. State model

Add vertical-reader state with:

- `widthFactor` — one chapter-wide value; prototype bounds `0.5–3.0`, default `1.0`.
- `panX` — ephemeral and reset/clamped when width is at or below viewport width.
- `anchor` — page index, fraction within that page, and viewport focal y during a geometry transaction.
- `isScaling` / pointer-count state — used to suspend conflicting motion and suppress progress churn.

Do not keep a matrix per page. Do not reuse the paged magnifying preference: its momentary one-finger contract and return-on-release behavior are intentionally different. [Patra ADR][P-adr]

Whether `widthFactor` persists across chapter opens is an open product question. If it does, it should be a Patra profile preference like reading direction; `panX` should never persist.

### 2. Layout

- Compute content width, page heights, and cumulative offsets from viewport width, factor, and `ChapterInfo.aspectRatioFor(page)`.
- Give each list item its scaled height. Paint the page at scaled width, centered for `widthFactor <= 1`, translated by bounded `panX` for `widthFactor > 1`, and clipped by the reader viewport.
- Apply one `panX` to the whole strip so seams line up.
- Keep zero page gaps initially to preserve current semantics. Make gaps a separate future preference, not an accidental artifact of zoom; Patra currently promises a gapless strip. [Patra vertical view][P-vertical]
- Preserve the current page plus intra-page fraction on pinch, rotation, window resize, and any late aspect-ratio correction.

### 3. Gestures and alternate controls

- Two fingers: pinch around focal point, with x translation included and y represented by scroll-anchor correction.
- One finger: vertical list scroll. Above 1×, predominantly horizontal movement pans x; use an axis-lock threshold so a slightly diagonal reading flick does not wobble the strip.
- Double tap: prototype reset-to-1× / 2× toggle around tap, but ship only after it coexists cleanly with Patra's single-tap chrome toggle.
- Chrome: expose `−`, percentage/reset, and `+` or an accessible slider so zoom does not require multitouch. Kotatsu exposes optional zoom controls and keyboard/Ctrl-wheel zoom in its custom frame, supporting the need for non-pinch paths. [Kotatsu preferences][Kotatsu-prefs] [Kotatsu scaling frame][Kotatsu-scale]
- Desktop: wheel scrolls vertically; Ctrl-wheel or trackpad pinch zooms. Do not use `InteractiveViewer`'s bare-wheel zoom behavior over a nested list because Flutter #70192 reports simultaneous zoom and list scroll. [Flutter #70192][F-70192]

### 4. Current-page and progress stability

Retain Patra's upper-third current-page rule during ordinary scrolling. During a scale transaction, hold the semantic anchor page stable until the correction lands; then recompute once. This avoids posting progress for pages that crossed the 30% probe only because every preceding item changed height. Patra currently serializes progress posts, but serialization does not make a false intermediate page correct. [Patra page tracking][P-vertical] [Patra progress][P-progress]

A direct navigator seek should still mean “page top,” because Kavita progress is page-addressed and Patra's existing seek contract is page-level. [Patra vertical view][P-vertical] [Kavita progress endpoint][K-progress]

### 5. Navigation target

When chrome is hidden:

- Preserve direct vertical scrolling.
- Consider an optional unobtrusive `current / total` indicator; Mihon already treats this as independent from full chrome. [Mihon counter][Mihon-counter]

When chrome is shown in vertical scrolling:

1. Show a page slider/rail aligned with the scroll axis, page number, and previous/next chapter actions where those actions exist.
2. Add a clearly labeled thumbnail-overview action.
3. Open thumbnails as a side sheet on wide screens and a modal grid/sheet on phones. Tapping a thumbnail jumps to the page top and closes or leaves the overview according to usability testing.
4. Reuse `/api/Reader/thumbnail`, `ThumbLoadQueue`, and existing provider/cache behavior; do not use full pages for online overview images. [Patra image provider][P-images] [Patra thumbnail queue][P-thumb-queue]
5. Keep the accordion strip in paged reading, where page-to-page visual scrubbing matches the interaction. Its geometry and tests should not be destabilized by the vertical-reader change. [Patra thumbnail geometry][P-thumbs]

This preserves all three jobs of today's chrome—visual recognition, long-distance jumping, and position—while separating them by frequency. Counter and slider are compact and frequent; visual overview is larger and on demand. Kotatsu's pages button plus slider and Panels' vertical side panel are direct precedents for that separation. [Kotatsu actions][Kotatsu-actions] [Panels App Store][Panels-store]

### 6. Delivery sequence

1. **Prototype gesture ownership** in isolation with a long variable-height list; pass the transition cases from [Gesture policy](#gesture-policy-to-prototype).
2. **Implement layout scale and focal anchor** while retaining the existing bottom chrome unchanged.
3. **Measure** frame time, image-cache behavior, anchor drift, and end reachability on long/tall chapters at 0.5×, 1×, and 3×.
4. **Add alternate zoom controls and semantics.**
5. **Replace only vertical chrome** with compact navigator + on-demand overview after interaction testing; leave paged chrome unchanged.

This sequence makes zoom correctness independent of a navigation redesign and leaves a usable fallback after every stage.

## Acceptance and test matrix

The implementation should not be accepted without automated geometry tests and device-level gesture tests.

### Geometry invariants

- No gap or overlap between every adjacent page at all tested factors.
- First and last artwork edges are reachable; `maxScrollExtent` corresponds to scaled layout, not unscaled paint.
- Horizontal pan never exposes beyond the chosen black-canvas boundary rule and is zero when the strip is narrower than the viewport.
- Scale around a focal point retains the same page and intra-page fraction within a small logical-pixel tolerance.
- Rotate/resize at page start, middle, and end retains the anchor.
- Slider/thumbnail seek lands at page top and does not echo a false page report, following the same principle as Patra's paged `_seeking` guard. [Patra reader guidance][P-guidance]

### Gesture cases

- Pinch from rest; pinch after first finger moves; pinch during and immediately after fling.
- Lift either finger first; continue with one-finger vertical scroll without a stuck recognizer.
- Pinch while a page seam is under the focal point.
- Horizontal pan above 1×; diagonal intent; vertical scroll at max left/right pan.
- Double-tap versus single-tap chrome; long press if page actions are added later.
- Touch, mouse wheel, Ctrl-wheel, trackpad pinch/scroll, keyboard zoom, and screen-reader-adjustable controls.

### Data and lifecycle cases

- Online, saved chapter, signed out mid-read, failed page, missing dimensions, and a late image/dimension correction.
- Initial page 0, middle, and last; one-page chapter; hundreds of pages; exceptionally tall pages.
- Chrome shown during pinch/rotation; thumbnail overview opened before any thumbnails are warm.
- Memory pressure and page widget recycling at maximum scale.

## Open questions

1. **Range:** Should phones allow zoom-out below fit-width, or should `0.5–1.0` be tablet/desktop-only? The competitor range supports 0.5, but readability and accidental shrinking need Patra-specific testing. [Mihon implementation][Mihon-webtoon-rv] [Kotatsu scaling frame][Kotatsu-scale] [Neko zoom implementation][Neko-compose-zoom]
2. **Persistence:** Reset to 1× for every chapter, remember for the reading session, or persist a profile-level preferred vertical width? Kavita persists width in a reading profile; Kotatsu persists a default zoom-out amount. [Kavita profile][K-profile] [Kotatsu preferences][Kotatsu-prefs]
3. **Maximum:** Is 3× enough for phone text/detail, or should Patra retain the paged reader's 5× ceiling? Patra paged uses 5× while inspected continuous readers cap at 2.5× or 3×. [Patra paged zoom][P-paged] [Mihon implementation][Mihon-webtoon-rv] [Kotatsu scaling frame][Kotatsu-scale]
4. **Pinch-time implementation:** live layout every update, or paint preview followed by one anchored layout commit? Decide from profile-mode frame measurements, not intuition.
5. **Horizontal intent:** after zoom-in, should a one-finger diagonal drag axis-lock to x/y, or should x pan and y scroll simultaneously? Neko chooses x pan plus independent list y behavior; Kotatsu coordinates transformed movement with nested scroll. [Neko zoom implementation][Neko-compose-zoom] [Kotatsu scaling frame][Kotatsu-scale]
6. **Double tap:** Is persistent 2×/reset valuable enough to resolve its timing conflict with single-tap chrome? Mihon and Neko both implement a 2×/2.5× double-tap target. [Mihon implementation][Mihon-webtoon-rv] [Neko zoom implementation][Neko-compose-zoom]
7. **Navigation placement:** vertical rail on which side, and should handedness be a preference? Mihon makes side and rail height configurable. [Mihon navigator wiring][Mihon-nav-wire]
8. **Thumbnail surface:** side sheet, bottom sheet, or full-screen grid on a phone? Panels confirms a side panel on iOS/Mac, but that does not settle narrow-phone ergonomics. [Panels App Store][Panels-store]
9. **Counter visibility:** always-on opt-in or only with chrome? Mihon has a separate “show page number” preference. [Mihon preferences][Mihon-prefs]
10. **Server-profile import:** Should Patra ever read Kavita's width override as an initial hint while continuing to store its own preference locally? Current Patra policy says preferences are not sent to Kavita, and no interoperability requirement has yet been established. [Patra context][P-context] [Kavita profile][K-profile]
11. **Automatic detection:** Is Kavita-like automatic selection of vertical scrolling in scope at all? Kavita gates its client-side detector behind a profile choice and at least three pages; zoom does not require this feature. [Kavita detector][K-detector] [Kavita detector gate][K-detector-gate]
12. **Chapter boundaries:** Should a continuous strip eventually include adjacent chapters? Kavita, Mihon, Kotatsu, and Neko have chapter-transition behavior, but Patra's current strip and progress model are one chapter. [Kavita scroller template][K-scroller-html] [Mihon viewer][Mihon-viewer] [Kotatsu fragment][Kotatsu-fragment] [Neko layout][Neko-compose-layout]

## Sources

All repository links are immutable commit permalinks. All web/package/store sources were accessed 2026-09-11.

### Patra primary sources

- [`reader_screen.dart` — branch selection, vertical magnify exclusion, tap layer, chrome](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L382-L521)
- [`reader_screen.dart` — page reporting, progress, precache](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L129-L181)
- [`reader_screen.dart` — full images, thumbnail endpoint, local resize, decode cap](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L61-L290)
- [`reader_screen.dart` — paged `InteractiveViewer` and magnifying ownership](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L654-L730)
- [`reader_screen.dart` — vertical geometry, placement, tracking, list layout](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L884-L1013)
- [`reader_screen.dart` — shared bottom chrome, thumbnails, slider, counter](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L1117-L1211)
- [`thumb_strip.dart` — deferred visible-first loading and lifetime](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/thumb_strip.dart#L7-L166)
- [`thumb_strip.dart` — accordion, computed offset, visible window, dragging](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/thumb_strip.dart#L277-L669)
- [ADR-0001 — one-finger magnifying decision and vertical exclusion](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/docs/adr/0001-reader-magnify-gesture.md)
- [`CONTEXT.md` — vertical scrolling and preference definitions](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/CONTEXT.md#L152-L205)
- [Reader implementation guidance](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/CLAUDE.md)
- [`pubspec.yaml` dependency list](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/pubspec.yaml#L9-L35)
- [Pinned Kavita 0.9.0.0 OpenAPI, Reader operations](https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/docs/openapi/kavita-openapi-0.9.0.0.json#L9286-L9475)

### Kavita primary sources — commit `d77d956b9551227d8be2ee488b08f14aa3a341e5`

- [Web client `ReaderMode` enum](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/_models/preferences/reader-mode.ts#L1-L17)
- [Server `AppUserReadingProfile` manga-reader fields](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Models/Entities/User/AppUserReadingProfile.cs#L35-L93)
- [Reading profile width slider and breakpoint controls](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/user-settings/manage-reading-profiles/manage-reading-profiles.component.html#L238-L277)
- [Infinite-scroller image strip and chapter pulls](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/manga-reader/_components/infinite-scroller/infinite-scroller.component.html#L18-L45)
- [Infinite-scroller width override and resize jump](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/manga-reader/_components/infinite-scroller/infinite-scroller.component.ts#L332-L363)
- [Infinite-scroller page state, jumps, and loading](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/manga-reader/_components/infinite-scroller/infinite-scroller.component.ts#L710-L880)
- [Client-side webtoon dimension/statistics detector](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/manga-reader/_service/manga-reader.service.ts#L169-L235)
- [Automatic-detection preference gate](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/manga-reader/_components/manga-reader/manga-reader.component.ts#L931-L940)
- [Reader image and thumbnail controller actions](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Server/Controllers/ReaderController.cs#L79-L129)
- [Reader file-dimensions and chapter-info actions](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Server/Controllers/ReaderController.cs#L170-L231)
- [Reader thumbnail generation](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Services/Reading/ReaderService.cs#L733-L769)
- [`CoverImageSize.Default` dimensions](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Models/Entities/Enums/CoverImageSize.cs#L3-L35)
- [Reader progress endpoint](https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Server/Controllers/ReaderController.cs#L619-L635)

### Other reader primary sources

- [Mihon webtoon defaults and preferences, commit `1e054ea`](https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/tachiyomi/ui/reader/setting/ReaderPreferences.kt#L70-L110)
- [Mihon webtoon scale/translation implementation](https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/tachiyomi/ui/reader/viewer/webtoon/WebtoonRecyclerView.kt#L26-L45)
  and [scale, double-tap, limits](https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/tachiyomi/ui/reader/viewer/webtoon/WebtoonRecyclerView.kt#L98-L258)
- [Mihon webtoon viewer and page selection](https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/tachiyomi/ui/reader/viewer/webtoon/WebtoonViewer.kt#L55-L161)
- [Mihon page indicator](https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/presentation/reader/ReaderPageIndicator.kt#L18-L51)
- [Mihon horizontal/vertical chapter-page navigator](https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/presentation/reader/components/ChapterNavigator.kt#L53-L318)
- [Mihon navigator selection and page-seek wiring](https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/tachiyomi/ui/reader/ReaderActivity.kt#L450-L503)
- [TachiyomiSY webtoon defaults, commit `14648c7`](https://github.com/jobobby04/TachiyomiSY/blob/14648c7cf0aa84e5a35d48de9dbf1386df6cca42/app/src/main/java/eu/kanade/tachiyomi/ui/reader/setting/ReaderPreferences.kt#L35-L110)
- [TachiyomiSY webtoon settings](https://github.com/jobobby04/TachiyomiSY/blob/14648c7cf0aa84e5a35d48de9dbf1386df6cca42/app/src/main/java/eu/kanade/presentation/reader/settings/ReadingModePage.kt#L180-L257)
- [TachiyomiSY vertical navigator settings](https://github.com/jobobby04/TachiyomiSY/blob/14648c7cf0aa84e5a35d48de9dbf1386df6cca42/app/src/main/java/eu/kanade/presentation/reader/settings/GeneralSettingsPage.kt#L61-L101)
- [Kotatsu webtoon/zoom defaults, commit `34f6e52`](https://github.com/KotatsuApp/Kotatsu/blob/34f6e5232bf7f0bcdf8f3fbddb986697518e82a4/app/src/main/kotlin/org/koitharu/kotatsu/core/prefs/AppSettings.kt#L145-L168)
  and [webtoon settings](https://github.com/KotatsuApp/Kotatsu/blob/34f6e5232bf7f0bcdf8f3fbddb986697518e82a4/app/src/main/kotlin/org/koitharu/kotatsu/core/prefs/AppSettings.kt#L493-L509)
- [Kotatsu `WebtoonScalingFrame`](https://github.com/KotatsuApp/Kotatsu/blob/34f6e5232bf7f0bcdf8f3fbddb986697518e82a4/app/src/main/kotlin/org/koitharu/kotatsu/reader/ui/pager/webtoon/WebtoonScalingFrame.kt#L25-L315)
- [Kotatsu webtoon setup, state restoration, and zoom controls](https://github.com/KotatsuApp/Kotatsu/blob/34f6e5232bf7f0bcdf8f3fbddb986697518e82a4/app/src/main/kotlin/org/koitharu/kotatsu/reader/ui/pager/webtoon/WebtoonReaderFragment.kt#L55-L180)
- [Kotatsu page slider and pages-sheet button](https://github.com/KotatsuApp/Kotatsu/blob/34f6e5232bf7f0bcdf8f3fbddb986697518e82a4/app/src/main/kotlin/org/koitharu/kotatsu/reader/ui/ReaderActionsView.kt#L90-L183)
  and [slider seek behavior](https://github.com/KotatsuApp/Kotatsu/blob/34f6e5232bf7f0bcdf8f3fbddb986697518e82a4/app/src/main/kotlin/org/koitharu/kotatsu/reader/ui/ReaderActionsView.kt#L144-L183)
- [Neko webtoon preferences, commit `38ae185`](https://github.com/CarlosEsco/Neko/blob/38ae185195b9303ad9199afc6ab2e22099313281/app/src/main/java/org/nekomanga/domain/reader/ReaderPreferences.kt#L68-L130)
- [Neko Compose initial state and programmatic seek](https://github.com/CarlosEsco/Neko/blob/38ae185195b9303ad9199afc6ab2e22099313281/app/src/main/java/org/nekomanga/presentation/screens/reader/viewer/ComposeWebtoonViewer.kt#L120-L173)
- [Neko scaled `LazyColumn` layout](https://github.com/CarlosEsco/Neko/blob/38ae185195b9303ad9199afc6ab2e22099313281/app/src/main/java/org/nekomanga/presentation/screens/reader/viewer/ComposeWebtoonViewer.kt#L452-L490)
- [Neko two-pointer scale, horizontal pan, and double tap](https://github.com/CarlosEsco/Neko/blob/38ae185195b9303ad9199afc6ab2e22099313281/app/src/main/java/org/nekomanga/presentation/screens/reader/viewer/ComposeWebtoonViewer.kt#L487-L585)
  and [double-tap target](https://github.com/CarlosEsco/Neko/blob/38ae185195b9303ad9199afc6ab2e22099313281/app/src/main/java/org/nekomanga/presentation/screens/reader/viewer/ComposeWebtoonViewer.kt#L686-L745)
- [Neko reader bottom page text/slider wiring](https://github.com/CarlosEsco/Neko/blob/38ae185195b9303ad9199afc6ab2e22099313281/app/src/main/java/eu/kanade/tachiyomi/ui/reader/ReaderActivity.kt#L598-L648)
- [Panels official feature page](https://www.panels.app/)
- [Panels official App Store listing and release notes](https://apps.apple.com/us/app/panels-comic-reader/id1236567663)
- [YACReader official App Store listing](https://apps.apple.com/us/app/yacreader-comic-reader/id635717885)
- [WEBTOON official App Store listing](https://apps.apple.com/us/app/webtoon-comics/id894546091)
- [Tapas official App Store listing](https://apps.apple.com/us/app/tapas-comics-and-novels/id578836126)
- [Manta official App Store listing](https://apps.apple.com/us/app/manta-comics/id1536116642)
- [Chunky official App Store listing](https://apps.apple.com/us/app/chunky-comic-reader/id663567628)

### Flutter primary sources and issue evidence

- [`InteractiveViewer` behavior, defaults, clipping, constraints, and callbacks — Flutter commit `d3b14c8`](https://github.com/flutter/flutter/blob/d3b14c876900e553bc736ca19295fc09e3853e8e/packages/flutter/lib/src/widgets/interactive_viewer.dart#L38-L340)
  and [constraint documentation](https://github.com/flutter/flutter/blob/d3b14c876900e553bc736ca19295fc09e3853e8e/packages/flutter/lib/src/widgets/interactive_viewer.dart#L185-L240)
- [`InteractiveViewer` gesture classification and scale recognizer](https://github.com/flutter/flutter/blob/d3b14c876900e553bc736ca19295fc09e3853e8e/packages/flutter/lib/src/widgets/interactive_viewer.dart#L676-L703)
- [`Transform` is applied before paint, not layout](https://github.com/flutter/flutter/blob/d3b14c876900e553bc736ca19295fc09e3853e8e/packages/flutter/lib/src/widgets/basic.dart#L1544-L1551)
- [`GestureArenaManager`: first accept / last non-reject wins](https://api.flutter.dev/flutter/gestures/GestureArenaManager-class.html)
- [`GestureDetector` troubleshooting and custom/raw-pointer extension points](https://api.flutter.dev/flutter/widgets/GestureDetector-class.html)
- [`ScrollPhysics.adjustPositionForNewDimensions`](https://api.flutter.dev/flutter/widgets/ScrollPhysics/adjustPositionForNewDimensions.html)
- [Flutter #15011 — scale + scroll gesture-detector request](https://github.com/flutter/flutter/issues/15011)
- [Flutter #65006 — `ListView` in `InteractiveViewer` scale recognition](https://github.com/flutter/flutter/issues/65006)
- [Flutter #70192 — inner list scrolls during wheel/trackpad zoom](https://github.com/flutter/flutter/issues/70192)
- [Flutter #86531 — scaled scrollable cannot reach ends](https://github.com/flutter/flutter/issues/86531)
- [Flutter #68594 — `InteractiveViewer` nested in a paged scrollable](https://github.com/flutter/flutter/issues/68594)
- [Flutter #99158 — requested scroll anchoring for changing list heights](https://github.com/flutter/flutter/issues/99158)

### Package primary sources

- [`photo_view` on pub.dev](https://pub.dev/packages/photo_view)
- [`extended_image` on pub.dev](https://pub.dev/packages/extended_image)
- [`easy_image_viewer` on pub.dev](https://pub.dev/packages/easy_image_viewer)
- [`scrollview_observer` on pub.dev](https://pub.dev/packages/scrollview_observer)


<!-- Reference-style links used throughout the report. -->
[P-reader-mode]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L382-L521
[P-progress]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L129-L181
[P-images]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L61-L290
[P-paged]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L654-L730
[P-vertical]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L884-L1013
[P-bottom]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/reader_screen.dart#L1117-L1211
[P-thumb-queue]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/thumb_strip.dart#L7-L166
[P-thumbs]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/thumb_strip.dart#L277-L669
[P-adr]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/docs/adr/0001-reader-magnify-gesture.md
[P-context]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/CONTEXT.md#L152-L205
[P-guidance]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/lib/src/features/reader/CLAUDE.md
[P-pubspec]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/pubspec.yaml#L9-L35
[P-openapi]: https://github.com/rbioteau/patra/blob/b96d0f86ad9272a1e4944ec8222eab29b8fa244a/docs/openapi/kavita-openapi-0.9.0.0.json#L9286-L9475
[K-modes]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/_models/preferences/reader-mode.ts#L1-L17
[K-profile]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Models/Entities/User/AppUserReadingProfile.cs#L35-L93
[K-profile-ui]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/user-settings/manage-reading-profiles/manage-reading-profiles.component.html#L238-L277
[K-scroller-html]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/manga-reader/_components/infinite-scroller/infinite-scroller.component.html#L18-L45
[K-width]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/manga-reader/_components/infinite-scroller/infinite-scroller.component.ts#L332-L363
[K-scroller]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/manga-reader/_components/infinite-scroller/infinite-scroller.component.ts#L710-L880
[K-detector]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/manga-reader/_service/manga-reader.service.ts#L169-L235
[K-detector-gate]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/UI/Web/src/app/manga-reader/_components/manga-reader/manga-reader.component.ts#L931-L940
[K-reader-api]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Server/Controllers/ReaderController.cs#L79-L129
[K-reader-dimensions]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Server/Controllers/ReaderController.cs#L170-L231
[K-thumb-gen]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Services/Reading/ReaderService.cs#L733-L769
[K-thumb-size]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Models/Entities/Enums/CoverImageSize.cs#L3-L35
[K-progress]: https://github.com/Kareadita/Kavita/blob/d77d956b9551227d8be2ee488b08f14aa3a341e5/Kavita.Server/Controllers/ReaderController.cs#L619-L635
[Mihon-prefs]: https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/tachiyomi/ui/reader/setting/ReaderPreferences.kt#L70-L110
[Mihon-webtoon-rv]: https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/tachiyomi/ui/reader/viewer/webtoon/WebtoonRecyclerView.kt#L26-L358
[Mihon-viewer]: https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/tachiyomi/ui/reader/viewer/webtoon/WebtoonViewer.kt#L55-L161
[Mihon-counter]: https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/presentation/reader/ReaderPageIndicator.kt#L18-L51
[Mihon-nav]: https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/presentation/reader/components/ChapterNavigator.kt#L53-L318
[Mihon-nav-wire]: https://github.com/mihonapp/mihon/blob/1e054ea14d551f5f16c8dd892bfb5962be2426d2/app/src/main/java/eu/kanade/tachiyomi/ui/reader/ReaderActivity.kt#L450-L503
[SY-prefs]: https://github.com/jobobby04/TachiyomiSY/blob/14648c7cf0aa84e5a35d48de9dbf1386df6cca42/app/src/main/java/eu/kanade/tachiyomi/ui/reader/setting/ReaderPreferences.kt#L35-L110
[SY-settings]: https://github.com/jobobby04/TachiyomiSY/blob/14648c7cf0aa84e5a35d48de9dbf1386df6cca42/app/src/main/java/eu/kanade/presentation/reader/settings/ReadingModePage.kt#L180-L257
[SY-nav]: https://github.com/jobobby04/TachiyomiSY/blob/14648c7cf0aa84e5a35d48de9dbf1386df6cca42/app/src/main/java/eu/kanade/presentation/reader/settings/GeneralSettingsPage.kt#L61-L101
[Kotatsu-prefs]: https://github.com/KotatsuApp/Kotatsu/blob/34f6e5232bf7f0bcdf8f3fbddb986697518e82a4/app/src/main/kotlin/org/koitharu/kotatsu/core/prefs/AppSettings.kt#L145-L509
[Kotatsu-scale]: https://github.com/KotatsuApp/Kotatsu/blob/34f6e5232bf7f0bcdf8f3fbddb986697518e82a4/app/src/main/kotlin/org/koitharu/kotatsu/reader/ui/pager/webtoon/WebtoonScalingFrame.kt#L25-L315
[Kotatsu-fragment]: https://github.com/KotatsuApp/Kotatsu/blob/34f6e5232bf7f0bcdf8f3fbddb986697518e82a4/app/src/main/kotlin/org/koitharu/kotatsu/reader/ui/pager/webtoon/WebtoonReaderFragment.kt#L55-L180
[Kotatsu-actions]: https://github.com/KotatsuApp/Kotatsu/blob/34f6e5232bf7f0bcdf8f3fbddb986697518e82a4/app/src/main/kotlin/org/koitharu/kotatsu/reader/ui/ReaderActionsView.kt#L90-L183
[Neko-prefs]: https://github.com/CarlosEsco/Neko/blob/38ae185195b9303ad9199afc6ab2e22099313281/app/src/main/java/org/nekomanga/domain/reader/ReaderPreferences.kt#L68-L130
[Neko-compose-start]: https://github.com/CarlosEsco/Neko/blob/38ae185195b9303ad9199afc6ab2e22099313281/app/src/main/java/org/nekomanga/presentation/screens/reader/viewer/ComposeWebtoonViewer.kt#L120-L173
[Neko-compose-layout]: https://github.com/CarlosEsco/Neko/blob/38ae185195b9303ad9199afc6ab2e22099313281/app/src/main/java/org/nekomanga/presentation/screens/reader/viewer/ComposeWebtoonViewer.kt#L452-L490
[Neko-compose-zoom]: https://github.com/CarlosEsco/Neko/blob/38ae185195b9303ad9199afc6ab2e22099313281/app/src/main/java/org/nekomanga/presentation/screens/reader/viewer/ComposeWebtoonViewer.kt#L487-L745
[Neko-controls]: https://github.com/CarlosEsco/Neko/blob/38ae185195b9303ad9199afc6ab2e22099313281/app/src/main/java/eu/kanade/tachiyomi/ui/reader/ReaderActivity.kt#L598-L648
[Panels-site]: https://www.panels.app/
[Panels-store]: https://apps.apple.com/us/app/panels-comic-reader/id1236567663
[YAC-store]: https://apps.apple.com/us/app/yacreader-comic-reader/id635717885
[WEBTOON-store]: https://apps.apple.com/us/app/webtoon-comics/id894546091
[Tapas-store]: https://apps.apple.com/us/app/tapas-comics-and-novels/id578836126
[Manta-store]: https://apps.apple.com/us/app/manta-comics/id1536116642
[Chunky-store]: https://apps.apple.com/us/app/chunky-comic-reader/id663567628
[F-iv]: https://github.com/flutter/flutter/blob/d3b14c876900e553bc736ca19295fc09e3853e8e/packages/flutter/lib/src/widgets/interactive_viewer.dart#L38-L340
[F-iv-gesture]: https://github.com/flutter/flutter/blob/d3b14c876900e553bc736ca19295fc09e3853e8e/packages/flutter/lib/src/widgets/interactive_viewer.dart#L676-L703
[F-transform]: https://github.com/flutter/flutter/blob/d3b14c876900e553bc736ca19295fc09e3853e8e/packages/flutter/lib/src/widgets/basic.dart#L1544-L1551
[F-arena]: https://api.flutter.dev/flutter/gestures/GestureArenaManager-class.html
[F-gesture-detector]: https://api.flutter.dev/flutter/widgets/GestureDetector-class.html
[F-scroll-physics]: https://api.flutter.dev/flutter/widgets/ScrollPhysics/adjustPositionForNewDimensions.html
[F-15011]: https://github.com/flutter/flutter/issues/15011
[F-65006]: https://github.com/flutter/flutter/issues/65006
[F-70192]: https://github.com/flutter/flutter/issues/70192
[F-86531]: https://github.com/flutter/flutter/issues/86531
[F-68594]: https://github.com/flutter/flutter/issues/68594
[F-99158]: https://github.com/flutter/flutter/issues/99158
[Pkg-photo]: https://pub.dev/packages/photo_view
[Pkg-extended]: https://pub.dev/packages/extended_image
[Pkg-easy]: https://pub.dev/packages/easy_image_viewer
[Pkg-observer]: https://pub.dev/packages/scrollview_observer
