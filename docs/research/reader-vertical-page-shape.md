# Where a page stops being a page: the vertical threshold

**Status:** threshold named from Kavita's own reader, then **measured on a real library** — 1.8 confirmed  
**Researched:** 2026-09-13 · **Measured:** 2026-09-13, 26 series  
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
>
> **Measured on a real library, [below](#the-measurement--one-real-library):** 1.8 holds. The paged works there run from 1.30 up to **1.58**, and the one work that scrolls medians at **6.94** — so 1.8 sits in an empty interval, and 1.5 is measurably too low.

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

## The measurement — one real library

`tool/measure_page_shapes.dart` against a home library of **26 series** in two libraries (BD and Manga), one chapter per series, every page the server reported dimensions for. Every series measured is named, so this can be re-run:

| Library | Series | Pages | Spreads | Median h/w | Min | Max | ≥ 1.8 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| BD | Blast - Intégrale | 817 | 1 | 1.30 | 1.29 | 1.30 | paged |
| BD | Les Mythics | 63 | 0 | 1.32 | 1.31 | 1.32 | paged |
| BD | Les Âges perdus | 58 | 0 | 1.32 | 1.32 | 1.33 | paged |
| BD | Mecanique Celeste | 203 | 0 | 1.32 | 1.32 | 1.34 | paged |
| BD | Gargouilles | 50 | 0 | 1.36 | 1.36 | 1.36 | paged |
| Manga | Atelier des sorciers | 206 | 4 | 1.38 | 1.38 | 1.38 | paged |
| Manga | Frieren | 188 | 3 | 1.38 | 1.38 | 1.38 | paged |
| Manga | Berserk | 207 | 9 | 1.38 | 1.38 | 1.38 | paged |
| Manga | Fool Night | 228 | 0 | 1.38 | 1.38 | 1.38 | paged |
| BD | Lastman - Nouvelle Édition | 208 | 1 | 1.38 | 1.38 | 1.38 | paged |
| Manga | Kingdom | 215 | 3 | 1.42 | 1.42 | 1.42 | paged |
| Manga | 21st Century Boys - Perfect Edition | 394 | 4 | 1.42 | 1.42 | 1.42 | paged |
| Manga | Vinland Saga | 224 | 0 | 1.42 | 1.42 | 1.42 | paged |
| Manga | Mission In The Apocalypse | 225 | 0 | 1.42 | 1.42 | 1.42 | paged |
| Manga | Gantz - Perfect Édition | 424 | 9 | 1.42 | 1.42 | 1.42 | paged |
| Manga | GTO - Paradise Lost | 202 | 0 | 1.45 | 1.45 | 1.45 | paged |
| Manga | Ghost in the Shell - Perfect Edition | 346 | 2 | 1.45 | 1.45 | 1.45 | paged |
| Manga | Attaque des Titans - Édition colossale | 546 | 19 | 1.50 | 1.50 | 1.50 | paged |
| Manga | GTO | 168 | 15 | 1.50 | 1.50 | 1.50 | paged |
| Manga | Jujutsu Kaisen | 202 | 5 | 1.52 | 1.52 | 1.52 | paged |
| Manga | Demon Slayer | 191 | 1 | 1.52 | 1.52 | 1.52 | paged |
| Manga | Spy x Family | 218 | 1 | 1.54 | 1.54 | 1.54 | paged |
| Manga | Dragon Ball Super | 189 | 2 | 1.56 | 1.35 | 1.56 | paged |
| Manga | One piece | 211 | 0 | 1.57 | 1.57 | 1.57 | paged |
| Manga | Death Note | 194 | 2 | 1.58 | 1.50 | 1.58 | paged |
| Manga | Solo Leveling | 9 | 0 | 6.94 | 1.43 | 10.62 | vertical |

### What the table says

**The two populations do not overlap here, and the gap is enormous.** The twenty-five works that turn run from **1.30** (Blast - Intégrale) to **1.58** (Death Note); the one work that scrolls, Solo Leveling, medians at **6.94**. Nothing on the shelf lands between 1.58 and 6.94 — so any threshold in that interval classifies this library identically, and 1.8 sits in it, 0.22 above the highest paged work.

**1.5 is measurably too low.** Eight series — Death Note 1.58, One piece 1.57, Dragon Ball Super 1.56, Spy x Family 1.54, Demon Slayer and Jujutsu Kaisen 1.52, GTO and Attaque des Titans 1.50 — would open scrolling at Kavita's lower bound. That is the "weak" band Kavita hedges with `+0.2`, and on this shelf it is exactly where manga lives. **The threshold must be above 1.58.**

**A work's page shape is nearly constant — except in a webtoon.** For 23 of the 25 paged series the min and max sit within 0.02 of the median; these are uniform scans, and only Dragon Ball Super (1.35–1.56) and Death Note (1.50–1.58) carry a tail at all. Solo Leveling spans **1.43 to 10.62**: it contains pages shaped exactly like manga pages and still medians at 6.94. That is the case the median was chosen for, now observed rather than argued — a mean over those nine pages is dragged toward 1.43 by pages that say nothing about the work.

**What it does not settle: the upper half.** No series here lands between 1.58 and 6.94, so the measurement validates 1.8 but cannot choose between 1.8 and, say, 4.0. And the vertical population is **one series of nine pages** — the thinnest sample in the table. That is why 1.8 stays at the **low** end of the measured gap rather than in its middle: the paged population is well sampled and stops dead at 1.58, while the vertical population's lower tail is not sampled at all, and Solo Leveling proves that tail is real. Choosing 4.0 would bet that no webtoon medians below 4.0, on the evidence of one webtoon; choosing 1.8 bets only that no manga medians above 1.8, on the evidence of twenty-five.

## Why 1.8 and not 2.0 or 2.2

The candidates are Kavita's own bands plus what the measurement added:

- **≤ 1.58 is ruled out by measurement, not by Kavita.** Eight series on the shelf above reach 1.50–1.58. Whatever else is true, the threshold cannot be at or below the paged population's ceiling.
- **2.2 is where Kavita is *certain*, not where the boundary is.** It is the "strong" cutoff and the trigger for the 40% rule. Choosing it would catch only the unambiguous half of a shelf: a webtoon whose panels average 1.9 — taller than any manga page, and taller than Kavita needs when the widths are consistent — would still open paged.
- **1.5–1.8 cannot be the threshold**, because Kavita says in as many words that regular manga and comics live there. Scoring it at all is a hedge, not a judgement.
- **1.8 is the seam.** It is the point where Kavita stops calling a page *weak* and starts calling it *moderate*, and it is the number its width-consistency rule turns on (`avgAspectRatio > 1.8` with `widthVariation < 0.15`). Below it, Kavita's own evidence is "this is probably a comic page"; above it, "this is probably a panel" — and with consistent widths, above it *is* webtoon mode in Kavita today.

So the band splits at 1.8 the way #64 asked: its lower half reads **paged** and its upper half reads **vertical**, which is also the order of Kavita's own confidence. The measurement narrows that answer rather than moving it — the paged population stops dead at 1.58, so "1.5–1.8 is paged" is not merely the conservative reading of Kavita's hedge, it is the only reading this shelf does not contradict, and 1.8 is the lowest number Kavita's own bands offer above that ceiling.

**Kavita's absolute-size terms are not a second number for us.** The `isMangaLikeSize` veto exists because small scans between 1.5 and 1.7 *look* webtoon-shaped, and its ratio term is `avgAspectRatio < 1.7` — below a threshold of 1.8. It is not unreachable from a **median**, though: a chapter mixing two near-square pages with pages at 1.9 has a median above 1.8 and a mean below 1.7. The honest statement is therefore narrower than "inert": the veto cannot bite a work whose pages are *uniformly* at or above 1.8. #57 adopts no size term of its own — #64 promised one number, and adding a size guard is a decision for whoever measures a library and finds small scans tripping it. If the local measurement turns one up, that is a #57 finding and not a #64 one.

## What #57 implements

The predicate, in full, so no further measuring is needed:

1. Read `pageDimensions` for the chapter being opened, from `/api/Reader/chapter-info?chapterId=…&includeDimensions=true`. **Dimensions are opt-in** — without the flag the server reports none and there is nothing to measure.
2. Drop the pages the server calls wide: `ChapterInfo.isWide(page)` (Kavita's `isWide`, or plainly landscape). A spread is two pages' worth of width presented as one, so its shape says nothing about the shape of a page.
3. Take each remaining page's **tallness** = `height / width`, and take the **median**. Not the mean: Kavita averages and then has to compensate with a width-variation test and a 40%-strong rule, because one spread or one unusually short page drags an average. Solo Leveling is the measured proof — pages from 1.43 to 10.62 — and a median resists both in one number, which is the number #64 asked for.
4. **Fewer than three measured pages is no verdict** — Kavita's own floor, and the right one: two pages cannot separate a webtoon from a scan with a tall cover.
5. **Median ≥ 1.8 → the work is vertical.** Which way it then goes is the library type's answer and not this note's.

It is keyed by **series**, not chapter: `detectedDirectionProvider` is a family of the series id, and a direction detected for one chapter of a work is a direction for the work (ADR-0007).

`SpreadLayout` is the precedent for trusting the dimensions at all — "a page wider than it is tall is already a spread" — and this is the same kind of predicate on the other axis.

## What is still thin

- **The vertical population is one series.** Solo Leveling is n=1, and at nine pages it is the thinnest row in the table. More webtoons — or `--chapters 3` over the ones already here — would say whether that population's floor is nearer 2 or nearer 6. Until then 1.8 is the low end of the measured gap on purpose (above).
- **Nothing lands between 1.58 and 6.94**, so this shelf does not exercise the upper half of the band at all. A library holding a vertical manhua, whose panels are shorter than a Korean webtoon's, is the case that would.
- **The threshold did not move.** 1.8 was in the gap before the measurement and is in it after. What the measurement added is a floor — above 1.58 — and Kavita's 1.5 struck from the candidates.

## How to re-run it

`tool/measure_page_shapes.dart` is the instrument. It walks a real server, reads the numbers through `ChapterInfo` — so what it measures is exactly what the app will measure, including `includeDimensions` — and prints one row per series, sorted, with the widest gap in the medians called out:

```sh
dart run tool/measure_page_shapes.dart \
  --url https://kavita.example.org \
  --user roman \
  --api-key <the key from Kavita's user settings>
```

An API key is all it needs — no password is asked for. Patra's own client sends `username`, an empty `password` and the `apiKey`, all three on the wire every time because `LoginDto` binds them by name, and documents that the password is ignored when a key is present [Patra-login]. `--insecure` accepts a self-signed certificate, `--library <id>` measures one library, `--chapters <n>` reads more than the first chapter of each series. `--url`, `--user` and `--api-key` also come from `KAVITA_URL`, `KAVITA_USER` and `KAVITA_API_KEY`.

The table above was produced by exactly this run, one chapter per series, and is the whole of what #64 asked a human to do: paste what it prints in here and the criteria close.

## Sources

[Kavita-detector]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/UI/Web/src/app/manga-reader/_service/manga-reader.service.ts — `shouldBeWebtoonMode()`
[Kavita-component]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/UI/Web/src/app/manga-reader/_components/manga-reader/manga-reader.component.ts — `switchToWebtoonReaderIfPagesLikelyWebtoon()`, gated on `allowAutomaticWebtoonReaderDetection`
[Kavita-migration]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Database/Migrations/20250328125012_AutomaticWebtoonReaderMode.cs — `AllowAutomaticWebtoonReaderDetection`, `defaultValue: true`
[Kavita-profile]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Models/Entities/User/AppUserReadingProfile.cs — the per-reading-profile setting
[Kavita-pages]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/UI/Web/src/app/manga-reader/_service/manga-reader.service.ts — `pageDimensions`, the same array Patra maps into `ChapterInfo`
[Patra-login]: ../../lib/src/api/kavita_client.dart — `_loginBody`, whose three fields all go on the wire
