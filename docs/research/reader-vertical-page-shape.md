# Where a page stops being a page: the vertical threshold

**Status:** threshold named, from Kavita's own reader — a local library has **not** been measured  
**Researched:** 2026-09-13  
**Scope:** the one number #64 was opened for: the aspect ratio at which a page is a panel. It says nothing about *which way* a work reads — the library type answers that (#57).

## The question

#57 decides a direction from the library type and the shape of the pages. The type needs no measuring; the shape does, because *where "very tall" starts cannot be guessed* — a tall manga page and a short webtoon panel are not far apart, and the number decides whether a whole shelf opens scrolling or paged.

So: **at what aspect ratio does a page stop being a page and start being a panel?**

Two conventions are in play and they are reciprocals, so they must be named before any number is:

| | Definition | A manga page (1000×1450) | A webtoon panel (800×4000) |
|---|---|---|---|
| **tallness** (Kavita's, and this note's) | height / width | 1.45 | 5.00 |
| **`PageDimension.aspectRatio`** (Patra's) | width / height | 0.69 | 0.20 |

Kavita divides height by width. `PageDimension.aspectRatio` divides width by height, which is why a portrait comic page is `2/3` there. **Patra's threshold is the reciprocal of the one below.**

## The answer

> **A page is a panel at tallness ≥ 1.8** — in Patra's own terms, `width / height ≤ 0.556`.
>
> **The band is 1.5–2.2.** Below 1.5 nothing is a panel; above 2.2 nothing is a page. Between them the two populations overlap, and the seam is 1.8: **1.5–1.8 falls on *paged*, 1.8–2.2 falls on *vertical***.

## Where the number comes from

Not from a guess and not from a survey of readers: from **Kavita's own web client**, which has shipped automatic webtoon detection for a year and a half. `shouldBeWebtoonMode()` [Kavita-detector] scores every page the server measured:

| Tallness | What Kavita calls it | Score |
|---|---|---|
| ≥ 2.2 | **strong** indicator (and counted toward the 40%-of-pages rule) | +1.0 |
| 1.8 – 2.2 | **moderate** | +0.5 |
| 1.5 – 1.8 | **weak** — its own comment: *"many regular manga/comics have ratios in this range"* | +0.2 |
| < 1.2 | *"too square-like (common in traditional comics)"* | −0.5 |

Those four bands are the **aspect-ratio part** of the score. The same loop adds three absolute-size terms — `+0.2` for `width <= 750`, `+0.5` for `height > 2000` (or `+0.3` above 1500), and `+0.3` for an area above 1.5 megapixels — so `averageScore >= 0.7` is partly a *size* test and a page of no great height can still finish positive. The number below is taken from the bands and their comments rather than from the score, because the size terms answer how big a scan is and not what shape a page is.

It then accepts webtoon mode when the average score is ≥ 0.7, the pages are **not** `isMangaLikeSize` (`avgHeight < 1200 && avgAspectRatio < 1.7 && avgWidth < 700`), and at least one of:

- ≥ 40% of pages are a **strong** indicator (tallness ≥ 2.2);
- the **average** tallness is ≥ 2.0;
- the widths are consistent (`widthVariation < 0.15`) **and** the average tallness is > 1.8.

Two things make these numbers evidence rather than somebody's first attempt:

- **They ship as the default.** The column behind the feature, `AllowAutomaticWebtoonReaderDetection`, was added to `AppUserPreferences` with `defaultValue: true` [Kavita-migration] — it has since moved to the per-reading-profile `AppUserReadingProfile` [Kavita-profile], carrying the same default — and every web reader reaches the detector unless they switch it off [Kavita-component]. Whatever its faults, it has been exercised on real libraries since 2025-03-28.
- **They have not moved.** The constants are unchanged at `dad212bfb96` (2025-03-30), `6d1c7a4ff50` (2025-12-31), `8d053f05598` (2026-09-01) and the v0.9.1.4 release (2026-09-02). A year and a half of use did not budge 1.8, 2.0 or 2.2. (The *file* did change around them — `inject()`, page offsets — which is what makes the constants standing still interesting.)

(A curiosity worth noting rather than trusting: the comment above the first branch says *"at least 2:1"* while the code says `2.2`. The code is the one that shipped and stayed.)

## Why 1.8 and not 2.0 or 2.2

The three candidates are all Kavita's own, so the choice is about which question each answers:

- **2.2 is where Kavita is *certain*, not where the boundary is.** It is the "strong" cutoff and the trigger for the 40% rule. Choosing it would catch only the unambiguous half of a shelf: a webtoon whose panels average 1.9 — taller than any manga page, and taller than Kavita needs when the widths are consistent — would still open paged.
- **1.5–1.8 cannot be the threshold**, because Kavita says in as many words that regular manga and comics live there. Scoring it at all is a hedge, not a judgement.
- **1.8 is the seam.** It is the point where Kavita stops calling a page *weak* and starts calling it *moderate*, and it is the number its width-consistency rule turns on (`avgAspectRatio > 1.8` with `widthVariation < 0.15`). Below it, Kavita's own evidence is "this is probably a comic page"; above it, "this is probably a panel" — and with consistent widths, above it *is* webtoon mode in Kavita today.

So the band splits at 1.8 the way #64 asked: its lower half (1.5–1.8) reads **paged** and its upper half (1.8–2.2) reads **vertical**, which is also the order of Kavita's own confidence.

**Kavita's absolute-size terms are not a second number for us.** The `isMangaLikeSize` veto exists because small scans between 1.5 and 1.7 *look* webtoon-shaped, and its ratio term is `avgAspectRatio < 1.7` — below a threshold of 1.8. It is not unreachable from a **median**, though: a chapter mixing two near-square pages with pages at 1.9 has a median above 1.8 and a mean below 1.7. The honest statement is therefore narrower than "inert": the veto cannot bite a work whose pages are *uniformly* at or above 1.8. #57 adopts no size term of its own — #64 promised one number, and adding a size guard is a decision for whoever measures a library and finds small scans tripping it. If the local measurement turns one up, that is a #57 finding and not a #64 one.

## What #57 implements

The predicate, in full, so no further measuring is needed:

1. Read `pageDimensions` for the chapter being opened, from `/api/Reader/chapter-info?chapterId=…&includeDimensions=true`. **Dimensions are opt-in** — without the flag the server reports none and there is nothing to measure.
2. Drop the pages the server calls wide: `ChapterInfo.isWide(page)` (Kavita's `isWide`, or plainly landscape). A spread is two pages' worth of width presented as one, so its shape says nothing about the shape of a page.
3. Take each remaining page's **tallness** = `height / width`, and take the **median**. Not the mean: Kavita averages and then has to compensate with a width-variation test and a 40%-strong rule, because one spread or one unusually tall cover drags an average. A median resists both in one number, which is the number #64 asked for.
4. **Fewer than three measured pages is no verdict** — Kavita's own floor, and the right one: two pages cannot separate a webtoon from a scan with a tall cover.
5. **Median ≥ 1.8 → the work is vertical.** Which way it then goes is the library type's answer and not this note's.

It is keyed by **series**, not chapter: `detectedDirectionProvider` is a family of the series id, and a direction detected for one chapter of a work is a direction for the work (ADR-0007).

`SpreadLayout` is the precedent for trusting the dimensions at all — "a page wider than it is tall is already a spread" — and this is the same kind of predicate on the other axis.

## What this note does not contain

**No series were measured.** The repository has no Kavita server to reach, which is the reason #64 was filed as a human task: the half of it that remains is confirming 1.8 against a shelf holding both things that scroll and things that turn. The number above is Kavita's, read out of their client — real, pinned and in production, but not observed on our own library.

Two of #64's acceptance criteria are therefore only partly met: the threshold is named and the band around it is named, but **no series is named here**, because none was measured.

## How to re-run it

`tool/measure_page_shapes.dart` is the instrument. It walks a real server, reads the numbers through `ChapterInfo` — so what it measures is exactly what the app will measure, including `includeDimensions` — and prints one row per series, sorted, with the widest gap in the medians called out:

```sh
dart run tool/measure_page_shapes.dart \
  --url https://kavita.example.org \
  --user roman \
  --api-key <the key from Kavita's user settings>
```

An API key is all it needs — no password is asked for. Patra's own client sends `username`, an empty `password` and the `apiKey`, all three on the wire every time because `LoginDto` binds them by name, and documents that the password is ignored when a key is present [Patra-login]. `--insecure` accepts a self-signed certificate, `--library <id>` measures one library, `--chapters <n>` reads more than the first chapter of each series. `--url`, `--user` and `--api-key` also come from `KAVITA_URL`, `KAVITA_USER` and `KAVITA_API_KEY`.

Paste the table it prints in here, under the series it names, and the acceptance criteria close.

## Sources

[Kavita-detector]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/UI/Web/src/app/manga-reader/_service/manga-reader.service.ts — `shouldBeWebtoonMode()`
[Kavita-component]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/UI/Web/src/app/manga-reader/_components/manga-reader/manga-reader.component.ts — `switchToWebtoonReaderIfPagesLikelyWebtoon()`, gated on `allowAutomaticWebtoonReaderDetection`
[Kavita-migration]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Database/Migrations/20250328125012_AutomaticWebtoonReaderMode.cs — `AllowAutomaticWebtoonReaderDetection`, `defaultValue: true`
[Kavita-profile]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Models/Entities/User/AppUserReadingProfile.cs — the per-reading-profile setting
[Kavita-pages]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/UI/Web/src/app/manga-reader/_service/manga-reader.service.ts — `pageDimensions`, the same array Patra maps into `ChapterInfo`
[Patra-login]: ../../lib/src/api/kavita_client.dart — `_loginBody`, whose three fields all go on the wire
