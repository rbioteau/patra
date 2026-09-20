# Hyphenating a book's prose: where the breaks come from, and who draws the mark

**Status:** research and recommendation for [#119] — **build the break points now, wait for the mark**
**Researched:** 2026-09-20 · **Measured:** 2026-09-20, on Flutter 3.47.2 and on Kavita's public demo (0.9.1.4)
**Scope:** a book's prose only — `book_page.dart`'s paragraphs, quotations and list items. Nothing here touches the image reader, and nothing here is about the *shape* of a page (that is [reader-vertical-page-shape.md](reader-vertical-page-shape.md)).

## Executive recommendation

> **Build the language and the break points. Do not build the hyphen, and do not put justification back.**
>
> The study set out to find what hyphenation costs. It found that the two halves of the question have opposite answers, and that the expensive half is not the one the issue expected.
>
> - **Break points are cheap and certain.** Liang's algorithm is **88 lines of Dart** (103 with its comments), measured by writing it. French and American English patterns together are **41,163 bytes** — French alone is **9,674**, not the "few hundred KB" the issue assumed, which is **4% of one of the three fonts this app already ships**. French is **MIT**; American English is a notice-preserving permissive grant. Both go into the bundle the way the fonts do, under the test that already checks every shipped face carries its licence.
> - **A book's language is already on a call this app makes.** `ChapterDto.Language` is a BCP-47 code taken from the EPUB's own `dc:language`, and it rides on `GET /api/Series/volumes` — the call the series screen already makes. Measured on Kavita's own demo: **54 of 57 book series carry one**, in six languages. That is the hole [#118] left, closed at no cost, and it needs no new endpoint, no per-book setting and no guess from the interface language.
> - **Nobody can draw the hyphen.** Not "it is hard": **there is no fixed point to reach.** The engine breaks a line to fit *without* the hyphen's width, so putting a real hyphen at the break overflows it and moves the break, stranding the hyphen mid-line. Measured at the reader's own column (350pt on a 390pt phone): two hyphens drawn, **both stranded, through six passes, and reserving the hyphen's 5.66pt advance does not fix it**. Drawing the mark therefore costs our own line breaker — and with it `Text.rich`, the book's own face, its italics, and the engine's own bidi.
> - **The engine is one line away from doing it for us.** Skia's `setRenderSoftHyphens` ships **inside the 3.47.2 binary, defaulted off**; Flutter's [PR #185152] would turn it on behind a `Hyphens` API and is open with changes requested, blocked on an unrelated test cleanup. [#18443] has been open since 2018 with 305 thumbs-up.
> - **So justification does not come back yet.** The measurement behind ragged right stands unamended: hyphenation alone would close the worst gap in a 190pt column from **101.6pt (53%) to 34.2pt (18%)** — but a break with no mark is the very thing the reader's rules call a rendering fault, and it would now be the app chopping words rather than a publisher.
>
> **Size of the change, as recommended:** the language field is **one line** in `models.dart` plus its decode; the pattern work is **88 lines and 41 KB**; the hyphen is **zero lines and one wait**. The one measurement that pins it: on 2026-09-20, `engine/src/flutter/lib/ui/text.dart` at tag `3.47.2` contains the string `hyphen` **zero times**.

Neither package is recommended. `hyphen` 0.4.0 is a good citizen that **bundles no patterns at all**, so it buys the 88 lines and leaves the whole licence burden; `custom_text_engine` 0.1.5's hyphenation is eleven hand-typed Russian orthography rules and its one widget does not re-lay-out when its text changes.

---

### What "the pinned SDK" is, exactly

Every Flutter number below was taken on **Flutter 3.47.2 · Dart 3.13.2 · framework `d3b14c8769` · engine `a804b26164`, 2026-08-26**, which is what `flutter --version` reports on this machine. That is worth stating precisely because **nothing in this repository pins it**: `pubspec.yaml` asks only for `sdk: ^3.13.2` (a *Dart* constraint), and all three `subosito/flutter-action` steps in `.github/workflows/build.yml` (lines 25, 70 and 268) say `channel: stable` with no `flutter-version`. So the SDK moves under the app whenever CI runs, with no commit and no tag.

For this study that cuts the right way. The recommendation is to **wait** for the engine, and a build that follows stable is a build that will pick the fix up on the first release after [PR #185152] lands, with nothing to bump. It also means the ragged-right measurement can stop being true without anybody touching the repository — which is the argument for the one-line check in [How to re-run it](#how-to-re-run-it).

## 1. Where the break points come from

Three candidates, and only one survives contact.

**The publisher's `&shy;` alone** is already honoured — `book_page.dart:456` decodes the entity to U+00AD, and `test/book_reader_test.dart:874` pins it including a `codeUnits` check for `0xAD`. It is free, and it is a floor rather than an answer: a `&shy;` is present only where an author or an editing tool put one, which is why the reader's own rules already record that honouring it *"has the same defect"* as chopping — the break is there and the mark is not. How often it is present in a real library was not measured here and would be worth measuring before anyone argues it is enough; nothing in this note assumes either way.

**Patterns fetched from the server** are ruled out by the issue's own constraint and by [ADR-0009]: a saved copy is the server's pages, and the app is what draws them. A device that hyphenates one book because it was online and another because it was not is a reader that reads differently on a train, which is the one thing this app refuses.

**Liang's algorithm over bundled patterns** is what every browser does and what the recommendation takes. The algorithm is a table of patterns — each an interleaving of letters and digits — competing for every position of a word between two full stops; the highest digit at a position wins, and an odd digit is a break [Liang]. Its size was not estimated; it was written. The implementation below, complete with pattern parsing, an exception list and soft-hyphen insertion, is **88 non-blank non-comment lines of Dart, 103 with its doc comments**:

```dart
class Hyphenator {
  Hyphenator(this._patterns, this._exceptions, this._left, this._right);

  final Map<String, List<int>> _patterns;
  final Map<String, List<int>> _exceptions;
  final int _left;
  final int _right;

  List<int> breaks(String word) {
    final lower = word.toLowerCase();
    if (lower.length < _left + _right) return const [];
    final points = _exceptions[lower] ?? _points(lower);
    return [
      for (var i = _left; i <= word.length - _right; i++)
        if (points[i - 1].isOdd) i,
    ];
  }

  List<int> _points(String lower) {
    final bounded = '.$lower.';
    final points = List<int>.filled(bounded.length + 1, 0);
    for (var i = 0; i < bounded.length; i++) {
      for (var j = i + 1; j <= bounded.length; j++) {
        final values = _patterns[bounded.substring(i, j)];
        if (values == null) continue;
        for (var k = 0; k < values.length; k++) {
          if (values[k] > points[i + k]) points[i + k] = values[k];
        }
      }
    }
    return points.sublist(2); // drop the two full stops
  }
}
```

It is correct, and the proof is a bug. Fed `hyph-en-us`, it answers `de-mo-c-rat` for *democrat* — which is exactly what that pattern file's own header records as a known defect: `de-mo-c-rat: 'instead of dem-o-crat (see GitHub issue #15)'` [Patterns-en-us]. An implementation that reproduces TeX's documented mistakes is reproducing TeX. Its other answers on the pinned SDK:

| | |
|---|---|
| `fr` | `in-com-pré-hen-si-bi-lité` · `an-ti-cons-ti-tu-tion-nel-le-ment` · `bi-blio-thèque` · `ty-po-gra-phie` |
| `en-us` | `hy-phen-ation` · `in-com-pre-hen-si-bil-ity` · `in-sti-tu-tion-al-iza-tion` · `al-go-rithm` |

Loading both tables takes **4 ms**; softening a 7,439-character page of French takes **2.14 ms**. Neither is a cost worth designing around.

## 2. Which languages, and what they cost

The primary source is the `hyph-utf8` distribution, which is what CTAN ships and what every browser's dictionaries are built from. Real byte sizes, taken from the CTAN-2024.12.31 tag [Patterns-tree]:

| Language | Patterns file | Bytes | Patterns | Exceptions | Licence |
|---|---|---:|---:|---:|---|
| French | `hyph-fr.pat.txt` | **9,674** | 1,216 | none | **MIT** [Patterns-fr] |
| American English | `hyph-en-us.pat.txt` | **31,489** | 4,938 | 169 B | notice-preserving permissive [Patterns-en-us] |
| British English | `hyph-en-gb.pat.txt` | **54,769** | 8,527 | 103 B | **MIT** [Patterns-en-gb] |

**French and American English together are 41,163 bytes** (20,964 gzipped); adding British English takes it to 95,929. For scale, `assets/fonts/Literata-Variable.ttf` is **955,132 bytes**. The issue's "a few hundred KB for French alone" is out by a factor of thirty, and the whole of question 2 turns on that: **patterns are not a size problem.**

The licences are per language and have to be named exactly. French is plain MIT, holder *Copyright (C) 1994-2002 Daniel Flipo, Bernard Gaulle, 2016 Arthur Reutenauer*. British English is plain MIT, holder *Dominik Wujastyk, Graham Toal*. American English is **not** MIT and carries no licence name at all — its whole grant is three lines, holder *Gerard D.C. Kuiken*:

> Copying and distribution of this file, with or without modification, are permitted in any medium without royalty provided the copyright notice and this notice are preserved.

That is an FSF all-permissive grant with a notice-preservation condition, which is compatible with Apache-2.0 distribution and **obliges the app to ship the notice**. It is the file `hyphen` 0.4.0's own third-party notice singles out as *"freely redistributable but not MPL/LGPL-compatible"* [Hyphen-third-party], and it is the reason the patterns cannot be pasted in as bare data.

**The browsers confirm both the sizes and the obligation.** Chromium ships 52 languages as compiled `.hyb` files [Chromium-hyb] built from these same TeX patterns, French at **8,165** bytes, British English **46,607**, American English **59,802**; its `README.chromium` names the licence set as *"BSD-3-Clause, CC-BY-3.0, FSFAP, LGPL-2.1, MIT, MPL-1.1, MPL-2.0, Unicode-DFS-2015, Unlicense"* and records that its own `LICENSE` file *"was generated by concatenating `NOTICE` or `LICENSE` files in each locale directory"* [Chromium-patterns]. Firefox ships 47 locales and puts a **`LICENSE` beside each one** — `intl/locales/fr/hyphenation/` holds `hyph_fr.dic` (14,390 B) and a 6,034-byte `LICENSE`; `en-US` holds a 106,063-byte dictionary and a `README_hyph_en_US.txt`, and Firefox ships **no British English at all** [Firefox-fr] [Firefox-en]. Two independent shipping browsers both answer the licence question by carrying the notice per language, which is exactly what this app already does for its fonts.

**What bundling would have to satisfy here.** The app's accounting is not a list kept by hand. `registerPatraFontLicenses()` ([`patra_font_licenses.dart:29`][Patra-licences]) is called from `main()` before `runApp`, and two tests enforce it from opposite directions: `test/about_version_test.dart:125` reads the **asset manifest** for every `assets/fonts/*-OFL.txt` that actually ships and fails if any is missing from `LicenseRegistry`, while `test/reading_settings_test.dart:114` walks every declared face and fails if the licence file beside it does not exist. Patterns would join on the same terms — `assets/hyphenation/hyph-fr.txt` beside `hyph-fr-LICENSE.txt`, registered in the same function, with the manifest test widened from `assets/fonts/` to cover both. That is the whole of the licence work, and it is the same shape as work already done.

## 3. Which language a book is in — and how that answers #118 consistently

This was the question the study expected to be hardest, and it turned out to have been answered by the server all along.

**Kavita does drop the book's `lang`.** `PrepareFinalHtml` copies only the **classes** off `<html>` and `<body>` and returns `<div class="{classes}">{body.InnerHtml}</div>` [Kavita-prepare]; `BookService.cs` contains no `hyphens`, `word-break`, `overflow-wrap`, `line-break` or `text-wrap` anywhere. And the book's CSS, which does arrive, **cannot carry a language at all** — CSS has no language property, only the `:lang()` selector, which `book_face.dart`'s `_neverMatches` refuses outright (`lib/src/features/reader/book_face.dart:469`) for the good reason that a rescoped selector carrying a colon matches nothing. So the route [#118] took for direction is closed for language, not by choice but by the shape of CSS.

**But Kavita reads `dc:language` out of the EPUB and keeps it.** `BookService.ParseInfo` fills `ComicInfo.LanguageISO` from `epubBook.Schema.Package.Metadata.Languages` through `ValidateLanguage`, which round-trips the code through `CultureInfo.GetCultureInfo` and returns the empty string for anything it cannot parse [Kavita-language] [Kavita-validate]. The scanner writes it onto the chapter [Kavita-process], `SeriesMetadata.Language` documents itself as *"Language of the content (BCP-47 code)"* [Kavita-metadata], and — the fact that decides this — **`ChapterDto.Language` is on the DTO `GET /api/Series/volumes` already returns** [Kavita-chapterdto]. Neither `ChapterInfoDto` nor `BookInfoDto` carries it [Kavita-chapterinfo], so the reader's own call is the wrong place to ask; the series screen's call is the right one, and it is already made (`lib/src/api/kavita_client.dart:459`, decoded into `Chapter` at `lib/src/api/models.dart:487`, which ignores the field today).

**Measured, on Kavita's own public demo** (0.9.1.4, `demouser`/`Demouser64`, the same server the page-shape note used [Kavita-demo]) — all 57 series of its Books library, read through `/api/Series/metadata` and `/api/Series/volumes`:

| | |
|---|---:|
| Book series measured | **57** |
| Carrying a non-empty BCP-47 language | **54** (95%) |
| Series language and chapter language agreeing | **54 of 54** |
| `languageLocked` (a human had edited it) | **0** |

with the distribution `en` 42 · `fr` 5 · `de` 4 · `nl` 1 · `en-US` 1 · `ru` 1 · empty 3. The three empties are the demo's three author-collection series (*Franz Kakfa*, *Herman Melville*, *Tom Albrighton*), whose chapters report `null` — not a failure of the field but of the files. Two things worth carrying: **a bare `fr` is the common shape, not `fr-FR`**, so the lookup must fall back from a full tag to its primary subtag; and **`en-US` occurs**, so a naive `== 'en'` is wrong. Both are ordinary BCP-47 handling.

**So the two holes get two different answers, and that is the consistent position rather than the inconsistent one.** [#118] reads direction out of the book's own stylesheet because `direction` is a CSS property and survives `ScopeStyles`; language is not a CSS property and does not survive anything, so it comes from the metadata Kavita parsed out of the file. The principle is the same in both — *read what the book itself declares, wherever the server lets it through* — and in neither case is it the profile's interface language or a setting for the reader to make. The interface language stays as the **last** rung, for the 5% with nothing declared, and no per-book setting is needed: #118's closing note already records that a book's cog has no direction row and that this wants its own ticket; a language row would be the same mistake made twice.

One caveat, honestly held: `SeriesMetadata.Language` is editable in Kavita's own UI and carries a `LanguageLocked` flag, so on a curated server it is a human's answer rather than the file's. That is fine — a human's answer is better — but it means the field is *metadata*, not a fact about the page, and a book whose second half is in another language has one language like it has one title.

## 4. Who draws the hyphen — the question with no cheap answer

The issue frames this as a choice between accepting a real hyphen inside selectable text and writing our own line breaker. The first horn is not real here, and the second is not optional.

**Selection is not a cost in this app.** `SelectionArea`, `SelectableText` and `SelectableRegion` appear **nowhere in `lib/`**. A book's prose is `Text.rich` (`book_page.dart:391`), the page is not selectable and nothing is copyable, so a character inside the rendered text is inside nothing a reader can lift. The objection is real for a reader that offers selection and would have to be reopened the day this one does; today it decides nothing.

**The real cost is that the break and the mark depend on each other.** Reconfirmed on the pinned SDK with Literata loaded, in a column narrow enough to force the break — the same three numbers the issue records, to the hundredth:

```
fragment "Donaudampf"        1 line,  first line 100.10
the same fragment plus "-"   1 line,  first line 105.76
broken at a soft hyphen      2 lines, first line  99.94
broken at a real hyphen      2 lines, first line 105.76
```

The mark is not there, and a hyphen's advance in Literata at 16pt is **5.66pt**. What is *new* is that the break is observable: `TextPainter.getLineBoundary` returns a `TextRange` whose `end` sits **one past the soft hyphen** on every line the engine broke at one —

```
line 0 w=104.6 range=0..15  shy=true   "The in·com·pre·"
line 1 w=119.9 range=15..36 shy=true   "hen·si·bil·ity of in·"
line 2 w=101.2 range=36..55 shy=true   "sti·tu·tion·al·iza·"
line 3 w= 31.6 range=55..59 shy=false  "tion"
```

— so a two-pass scheme is expressible: lay the softened text out, ask where it broke, put a real hyphen at each of those positions, lay it out again. **It does not converge.** The engine fits the line *without* the hyphen's 5.66pt; adding it overflows the line, so the break moves earlier and the hyphen it was drawn for is now printed in the middle of a line. Measured, counting hyphens that the settled layout does **not** put at a line end:

| Column | pass 1 | pass 2 | pass 3 | pass 4 | pass 5 | pass 6 |
|---|---|---|---|---|---|---|
| 190pt | 6 drawn / 6 stranded | 6 / 5 | 7 / 6 | 6 / 5 | 7 / 6 | 6 / 5 |
| 280pt | 3 / 3 | 5 / **0** | — | — | — | — |
| **350pt** (a 390pt phone, less the reader's gutters) | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 | 2 / 2 | **2 / 2** |
| 520pt | 3 / 3 | 2 / 1 | 3 / **0** | — | — | — |

Two of four widths oscillate for ever, and one of them is the width that matters. Reserving the hyphen's advance while breaking — lay out at `width - 5.66`, then draw at `width` — does not rescue it either: it changes *every* line's break, not only the hyphenated ones, and at 350pt still leaves both hyphens stranded. A stranded hyphen is strictly worse than the silent chop this study set out to fix.

**So the mark costs our own line breaker**, and the framework is explicit about what that means: `LineMetrics` carries no character index at all — nine fields, all geometry plus `hardBreak` [Flutter-linemetrics]; there is no API to force a break at a chosen index; and `TextPainter.paint` paints the whole paragraph with no per-line entry point [Flutter-textpainter]. Composing lines ourselves means measuring candidate substrings, positioning each line by hand, and drawing with a `CustomPainter` — which costs the semantics tree, the `Text.rich` span model that carries the book's face and its italics (`book_page.dart:35`, [ADR-0012]), and the engine's own bidi, which [#118] just taught this reader to respect.

**And the engine is about to do it.** Flutter's [#18443] — *"Support soft hyphenation (line breaks at U+00AD plus rendering a hyphen at the end of the line)"* — has been open since 2018-06-13 with **305 thumbs-up** and the `customer: crowd` label, still **P2**. No maintainer in eight years has defended the missing glyph as a design choice; the explanations are successively *"not wired up"*, *"should be supported in SkParagraph when we switch"* and, after that switch shipped in 2022 without it, nothing. It was fixed **upstream in Skia** on 2026-04-13 by an outside contributor, behind `ParagraphStyle::setRenderSoftHyphens()` which *"defaults to false to preserve existing behavior for current consumers"* [Skia-hyphen]. The decisive fact for this study: **Flutter 3.47.2 pins a Skia revision that contains that commit** [Flutter-deps], so the capability ships inside every binary this app builds, switched off [Skia-style], and `engine/src/flutter/txt/src/skia/paragraph_builder_skia.cc` at that tag never calls it [Flutter-text]. [PR #185152] would call it behind a `Hyphens { manual, none }` API defaulting to drawing the glyph — an API shape settled in a design doc [#185154] that deliberately excludes `Hyphens.auto`, so *automatic* hyphenation is on no Flutter roadmap at all; it is open, `CHANGES_REQUESTED` [#185154], last touched 2026-09-10, and blocked on an unrelated `material_ui` test cleanup ([flutter/packages#12728]) that is itself unmerged.

Two caveats disclosed in that design review matter to a reader and should be checked when it lands: because the hyphen is appended **post-layout**, a rendered line can exceed `maxWidth` by the glyph's advance; and [#189234] records that skparagraph's `getRectsForRange` skips the synthetic hyphen, so a selection spanning a break would not highlight it. Neither is a reason to wait less.

## 5. What our own line breaker would cost what is already built

Confirmed rather than assumed, by reading the two paths end to end. **Nothing depends on the text being byte-identical to the server's.**

- **The anchor is a fraction, by construction.** `BookAnchor` ([`book_page.dart`][Patra-book-page]) is *"a fraction of the room there is to scroll, and not a number of points, because a fraction survives being read somewhere else"* (`book_page.dart:141-182`), and `BookPageBody.didUpdateWidget` already re-places it whenever the text size, the line height **or the face** changes (`book_page.dart:252-265`). Hyphenation changes the height of a page exactly the way a face change does — measured above, 11 lines to 8 in a 190pt column — and the anchor is the mechanism that already absorbs that. What travels to the server is `fraction.toStringAsFixed(4)` (`book_page.dart:167`), which the server stores as an opaque `bookScrollId` string.
- **Progress is a page number and never a character offset.** ADR-0009's whole argument is that a saved copy keeps the page count it was made with, and that `POST /api/Reader/progress` takes the same integer the image reader posts. Nothing in that chain looks at the text.
- **A saved copy is the server's HTML with picture names rewritten, and it is parsed at read time by the same function the streamed page is.** `downloads_service.dart:885-895` writes `renameBookPictures(html, …)` to disk; `reader_screen.dart:83` parses a streamed page with `BookPage.fromHtml(html)` and `reader_screen.dart:96` parses a stored one with `BookPage.fromHtml(file.readAsStringSync())`. Hyphenation applied after parsing therefore applies identically to both, which is exactly the constraint the issue sets. Nothing compares stored bytes to server bytes; the only comparison ADR-0009 makes is the page **count**.
- **`test/book_reader_test.dart` pins the parse, not the bytes.** Its assertions are on `BookWords.spans`, on `BookBlockStyle`, on which page was asked for and what was posted (`:874` for the soft hyphen, `:1082` for ragged right). None would be invalidated by inserting U+00AD between parse and draw.

So the *break points* cost nothing already built. The **line breaker** is what costs: `Text.rich` and with it the face, the italic and the bidi; the semantics tree; and the `_SqueezedByPane`-style class of layout bugs this reader has already paid for once (`lib/src/features/reader/CLAUDE.md`, on rebuilding under `LayoutBuilder`). And it costs time on the page path: measured on the pinned SDK, a 20-paragraph page at the reader's own 350pt column takes **11.2 ms through one pass and 16.5 ms through four**, against **0.9 ms** for a plain layout — on a desktop test binding, so a phone is some multiple of that. Once per page and per width, not per frame, but it lands in a build.

## 6. Does justification come back

**Not yet, and the reader's rules are amended rather than reversed.**

Hyphenation is measurably the thing justification needs, and by how much is now a number. The same sentence, in Literata at 16pt, laid out ragged and hyphenated — "worst gap" being the largest amount of white a justified line would have to absorb, i.e. the column less the widest line's natural width:

| Column | worst gap, unhyphenated | worst gap, hyphenated | lines |
|---|---:|---:|---|
| 190pt | **101.6pt (53%)** | **34.2pt (18%)** | 11 → 8 |
| 320pt | 93.1pt (29%) | 37.0pt (12%) | 5 → 5 |

A 53% gap is not a river, it is a canyon, and the reason is visible in the unjustified widths: Flutter distributes slack at word boundaries, so a line holding one long word cannot stretch at all and the line above it absorbs everything. Hyphenation roughly **thirds** the worst case. That is the premise of the ragged-right rule doing exactly what the rule said it would.

But the premise has two halves — *there is nothing to hyphenate with* — and only one of them moves. Break points without a mark give a justified column that is evenly spaced **and silently chops words**, which is the rendering fault the rule names, now committed by the app rather than inherited from a publisher. So: **ragged right stands, the measurement in [the reader's rules][Patra-reader-rules] stands, and `test/book_reader_test.dart:1082` stands.** What changes when [PR #185152] lands is that the premise's second half is gone, and the question becomes a real one.

When it does, the shape of the answer is already drawn by [ADR-0012]. The face is the one part of a book's design this app defers to, read out of the book's own scoped stylesheet by `parseBookFace` (`book_face.dart:262` [Patra-book-face]); `text-align` is a declared ExCSS longhand and survives `ScopeStyles` [Kavita-scope] exactly as `direction` does, and `_stillPicksOutThePage` (`book_face.dart:402`) is the machine that decides whether a declaration still speaks for the page. Honouring a book's own `text-align: justify` would be the same walk over the same `<style>`, and would make justification a **second** thing deferred to the book rather than a setting — which is the argument [ADR-0012] already won. It would not be a global switch, and it should not be one: a book that asks for ragged right should get it.

One Kavita-side fact worth keeping, since it is the reason the question looks different in a browser: **`-epub-hyphens` is silently dropped and unprefixed `hyphens` survives.** `BookService` constructs its parser as `new StylesheetParser()` (`BookService.cs:50`), whose defaults are `includeUnknownRules: false, includeUnknownDeclarations: false` [ExCSS-parser] — strict — and `ScopeStyles` re-serialises through `stylesheet.ToCss()` (`BookService.cs:242`), so anything the parser did not recognise is gone. `hyphens` is a declared longhand (`PropertyNames.cs:132`, `PropertyFactory.cs:225` [ExCSS-hyphens]); the `-epub-` prefix that EPUB 3 books actually write is not. So the one hyphenation-related thing that does reach this app is a book saying `hyphens: auto` — a hint that the book wants it, not a source of break points and not a language.

---

## The three routes, judged

### `hyphen` 0.4.0 — good code, no patterns

Published **2026-09-09**, three likes, 150/160 pub points, 1,367 downloads in 30 days, six platforms including iOS and Android, Dart 3, null-safe, no native code since 0.4.0 dropped its FFI path [Hyphen-pub]. Two runtime dependencies, `flutter` and `characters` [Hyphen-pubspec]. 1,211 lines of Dart, 88 tests, and a differential-verification story most packages do not attempt — but **no CI at all**, and `license:unknown` on pub.dev because the licence is a deliberate MIT + MPL-2.0 file-level split (holder *SchoolCraft GmbH*) that no scanner classifies [Hyphen-licence].

The decisive fact is in its own README: *"`Hyphen` requires a `.dic` file for the language you want to hyphenate. These are not bundled due to licensing reasons. You need to generate or obtain these `.dic` files yourself."* [Hyphen-readme]. Every `.dic` in the repository is a test fixture; the largest is 112 bytes. So the package buys the 88 lines and leaves **the entire content of question 2** — sourcing the TeX patterns, running hunspell's `substrings.pl` over them offline, and carrying each one's notice — exactly where it was. Two further frictions: it returns a `List<String>` of grapheme-aware chunks rather than UTF-16 indices, which is the wrong unit for `TextPainter`; and its `InitializationException` is thrown but not exported, so a caller can only `catch (e)`. A dependency that removes 88 lines and adds a licence-scanner exception, an unexported error type and a unit mismatch is not a trade [ADR-0008] and [ADR-0010] would make.

### `custom_text_engine` 0.1.5 — not a candidate

Published **2025-12-16**, all six versions within 43 minutes of one another and nothing since; one like, 40 downloads in 30 days, Apache-2.0, unverified uploader [CTE-pub]. **No tests, no CI, no tags**, a `CONTRIBUTING.md` the README links to that does not exist, an `example/` with no `pubspec.yaml`, and 57 of 58 comment lines in Cyrillic. ~1,500 hand-written lines.

Its hyphenation claim does not hold. `hyphenator.dart` is eleven hand-typed rules over a three-symbol alphabet whose "consonant" and "vowel" classes are Russian with unaccented ASCII appended [CTE-hyphenator]; there is no pattern data, no language parameter, and no `leftHyphenMin`/`rightHyphenMin`. Run on English it answers `bre-aking`, `so-met-hing` and `ex-t-ra-or-di-na-ry`; on French it goes partly inert, because `é` and `è` fall through unclassified. And independently of hyphenation, `AdvancedText` has no `didUpdateWidget` and re-lays-out only on a **width** change [CTE-widget] — so at a fixed column width it renders the previous page's layout for the current page's text, which is precisely this reader's case. It is not a library.

### Liang here — the recommendation

88 lines, no dependency, patterns as data under their own notices, in the shape this client is already in. The issue's "a few hundred lines" is generous by a factor of three or four; the issue's "few hundred KB" is generous by thirty. **What it does not buy is the mark**, and that is the whole of why the recommendation is to build it and hold it.

---

## What is still thin

- **The line breaker was not prototyped.** The case against it is an argument from what it costs (`Text.rich`, semantics, bidi) plus the 11–16 ms a two-pass scheme already costs on a desktop binding. Nobody built one and measured it on a phone. If [PR #185152] stalls for another year that is the measurement to make, and the honest comparison is against `custom_text_engine`'s ~1,500 lines as a floor rather than against nothing.
- **The stranding measurement is one paragraph at four widths.** It oscillates at two of them and settles at two, which is enough to refuse the scheme but not enough to say what fraction of real prose strands. A paragraph whose long words happen to fall away from the line ends would settle at every width.
- **Only French and English were costed.** The demo's own shelf holds German, Dutch and Russian, and `hyph-de-1996` is **261,255 bytes** — twenty-seven times French — so "one file per language" is not one cost per language, and a rule for *which* languages ship has to be made rather than assumed.
- **The language field was measured on one server.** Kavita's demo is a Calibre/Gutenberg-shaped library, and Gutenberg EPUBs carry good `dc:language`. A shelf of hand-made EPUBs would very likely do worse than 95%, and nothing here says how much worse. The three empties on the demo are all author collections, which hints that the gap is about how a series was built rather than about the field.
- **How many real books carry a `&shy;` was not counted.** §1 dismisses the publisher's own soft hyphen as a floor on the strength of the reader's existing rules rather than on a count. A scan of a real shelf for U+00AD would say whether the cheap answer is cheaper than it looks — and it is a `grep` over saved pages, so it costs nothing to find out.
- **`hyphens: auto` in a book's CSS was never seen in the wild.** ExCSS's tables say it survives and `-epub-hyphens` does not; nobody ran a real book's stylesheet through Kavita and looked.
- **Nothing was measured on a device.** Every Flutter number here is a desktop test binding.

## How to re-run it

Two independent measurements, both cheap.

**The patterns and their licences** need only `curl` — every number in §2 comes from the CTAN-2024.12.31 tag:

```sh
for f in hyph-fr hyph-en-gb hyph-en-us; do
  curl -sL "https://raw.githubusercontent.com/hyphenation/tex-hyphen/CTAN-2024.12.31/hyph-utf8/tex/generic/hyph-utf8/patterns/tex/$f.tex"    -o "$f.tex"
  curl -sL "https://raw.githubusercontent.com/hyphenation/tex-hyphen/CTAN-2024.12.31/hyph-utf8/tex/generic/hyph-utf8/patterns/txt/$f.pat.txt" -o "$f.pat.txt"
done
wc -c hyph-*        # sizes
sed -n '/^% licence:/,/^% hyphenmins:/p' hyph-fr.tex   # the grant, per language
```

**The engine's behaviour** is a throwaway test file dropped into `test/` and deleted afterwards — it is not committed, because unlike `tool/measure_page_shapes.dart` it needs no server, takes no argument and says the same thing on every machine until the SDK moves. Load `assets/fonts/Literata-Variable.ttf` through a `FontLoader`, lay `Donaudampf` / `Donaudampf-` / `Donaudampf­schiff` out at `maxWidth: 120` and compare `computeLineMetrics().first.width`. The single number that decides whether this study's recommendation still holds is cheaper still, and needs no Flutter at all:

```sh
curl -sL https://raw.githubusercontent.com/flutter/flutter/3.47.2/engine/src/flutter/lib/ui/text.dart | grep -c -i hyphen   # 0
```

**When that stops being 0, reopen §4 and §6 together.** §1's `Hyphenator` above is the whole of the Dart worth keeping. The Flutter probes are not committed, for the reason given above; the **browser** probe is, at [hyphenation-probe.html](hyphenation-probe.html), because unlike them it measures a platform rather than this SDK and its answer moves with Android and iOS rather than with a version this repository can name.

## Addendum, 2026-09-20 — the browser distinguishes the language, and a fourth route was never instructed

Everything above costs what it costs because the app draws the page itself. [#119] establishes that a browser hyphenates and then instructs three **native** routes, and §6 records the one Kavita-side fact that makes the question look different in a browser. Neither the issue nor this note weighs handing the page body to a web view — [ADR-0010] had settled that, and both inherited it.

The wall both stop at is the same: [#119]'s probe *"hyphenated `lang="en"` and `lang="fr"` identically in this Chromium, so the dictionary was not distinguishable from here"*. So *a browser hyphenates* was established and *a browser hyphenates in the book's language* was not, and only the second decides anything.

That probe could not distinguish them because its sentence holds no word whose break differs between the two languages. [hyphenation-probe.html](hyphenation-probe.html) is built from words that do, over two independent families so one dictionary quirk cannot fake a result — `s` + consonant, where English breaks **before** the `s` and French **after** it (`con-struction` / `cons-truction`), and the `gn` digraph French never splits (`sig-nal` / `si-gnal`). For each of five words under `lang="en"`, `lang="fr"` and an unknown tag, it sweeps the column from 20% to 95% of the word's natural width and reads the break back at every width by binary search over "is this character still on the first line?". The sweep is what makes it sound: an engine takes the **latest** break that fits, so one width reveals one point and not the set.

**Measured on device, 2026-09-20: 5 words of 5 separated, on Chrome/Android and on Safari/iOS alike.** Hyphenation is available and `lang` genuinely selects the dictionary.

What that changes, and what it does not, is argued on [#119] rather than here — including the three costs a web view carries (the Linux dev loop, two renderers that can drift, the header-authenticated pictures) and the one thing still unproven: **Chrome/Android is not the Android System WebView and Safari/iOS is not WKWebView**, so this is a strong proxy and not a proof. The recommendation at the head of this note stands until that route is weighed; it is not amended by this addendum, and the measurement is recorded here because the probe is.

## Sources

[#119]: https://github.com/rbioteau/patra/issues/119 — "Hyphenate a book's prose, so a narrow column can justify without gaps", the study this note answers
[#118]: https://github.com/rbioteau/patra/issues/118 — "Read a book's own declared direction as evidence for how it opens", closed; its comments name the shared language hole

[Liang]: https://tug.org/docs/liang/liang-thesis.pdf — Franklin Mark Liang, *Word Hy-phen-a-tion by Com-put-er*, Stanford STAN-CS-83-977 (1983); the algorithm's primary source, distributed by TUG

[Patterns-tree]: https://github.com/hyphenation/tex-hyphen/tree/CTAN-2024.12.31/hyph-utf8/tex/generic/hyph-utf8/patterns — the `hyph-utf8` patterns as CTAN shipped them on 2024-12-31; `tex/` carries the licence headers, `txt/` the stripped patterns whose sizes are quoted
[Patterns-fr]: https://github.com/hyphenation/tex-hyphen/blob/CTAN-2024.12.31/hyph-utf8/tex/generic/hyph-utf8/patterns/tex/hyph-fr.tex — French patterns, `licence: name: MIT`, © 1994-2002 Daniel Flipo, Bernard Gaulle, 2016 Arthur Reutenauer
[Patterns-en-us]: https://github.com/hyphenation/tex-hyphen/blob/CTAN-2024.12.31/hyph-utf8/tex/generic/hyph-utf8/patterns/tex/hyph-en-us.tex — American English, © 1990, 2004, 2005 Gerard D.C. Kuiken; an unnamed notice-preserving grant, and the `known_bugs: de-mo-c-rat` entry
[Patterns-en-gb]: https://github.com/hyphenation/tex-hyphen/blob/CTAN-2024.12.31/hyph-utf8/tex/generic/hyph-utf8/patterns/tex/hyph-en-gb.tex — British English, MIT, © 1992, 1996, 2005, 2016 Dominik Wujastyk, Graham Toal

[Chromium-patterns]: https://chromium.googlesource.com/chromium/src/+/refs/heads/main/third_party/hyphenation-patterns/README.chromium — 52 compiled `.hyb` files from the TeX patterns, the per-locale licence set, and how the concatenated `LICENSE` is built
[Chromium-hyb]: https://chromium.googlesource.com/chromium/src/+/refs/heads/main/third_party/hyphenation-patterns/hyb — the `.hyb` directory whose `hyph-fr`/`hyph-en-gb`/`hyph-en-us` sizes are quoted
[Firefox-fr]: https://github.com/mozilla-firefox/firefox/tree/main/intl/locales/fr/hyphenation — `hyph_fr.dic` (14,390 B) beside its own 6,034-byte `LICENSE`
[Firefox-en]: https://github.com/mozilla-firefox/firefox/tree/main/intl/locales/en-US/hyphenation — `hyph_en_US.dic` (106,063 B) and `README_hyph_en_US.txt`; Firefox ships 47 locales and no en-GB

[Kavita-prepare]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Services/BookService.cs#L405-L420 — `PrepareFinalHtml`: only the classes off `<html>`/`<body>` survive, so `lang` and `dir` do not
[Kavita-scope]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Services/BookService.cs#L187-L250 — `ScopeStyles`, the `body` → `.book-content` rewrite, and the `stylesheet.ToCss()` re-serialisation that drops what ExCSS did not parse
[Kavita-language]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Services/BookService.cs#L610-L613 — `LanguageISO` read from the EPUB's `dc:language`
[Kavita-validate]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Services/BookService.cs#L868-L880 — `ValidateLanguage`, round-tripping the code through `CultureInfo.GetCultureInfo`
[Kavita-process]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Services/Scanner/ProcessSeries.cs#L974-L977 — the scanner writing `comicInfo.LanguageISO` onto the chapter unless it is locked
[Kavita-chapterdto]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Models/DTOs/ChapterDto.cs#L122-L130 — `ChapterDto.Language`, on the DTO `/api/Series/volumes` returns
[Kavita-metadata]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Models/DTOs/SeriesMetadataDto.cs#L48-L50 — `SeriesMetadataDto.Language`, *"Language of the content (BCP-47 code)"*
[Kavita-chapterinfo]: https://github.com/Kareadita/Kavita/blob/v0.9.1.4/Kavita.Models/DTOs/Reader/ChapterInfoDto.cs — the reader's own call, which carries no language
[Kavita-demo]: https://github.com/Kareadita/Kavita/blob/develop/README.md — `demouser` / `Demouser64` at `demo.kavitareader.com`, the server the language measurement was taken on

[ExCSS-parser]: https://github.com/TylerBrinks/ExCSS/blob/v4.3.2/src/ExCSS/Parser/StylesheetParser.cs#L15-L23 — the default constructor Kavita uses: `includeUnknownRules: false, includeUnknownDeclarations: false`
[ExCSS-hyphens]: https://github.com/TylerBrinks/ExCSS/blob/v4.3.2/src/ExCSS/Factories/PropertyFactory.cs#L225 — `AddLonghand(PropertyNames.Hyphens, …)`; unprefixed `hyphens` is known, `-epub-hyphens` is not

[#18443]: https://github.com/flutter/flutter/issues/18443 — "Support soft hyphenation (line breaks at U+00AD plus rendering a hyphen at the end of the line)", open since 2018-06-13, 305 👍, P2, `customer: crowd`
[PR #185152]: https://github.com/flutter/flutter/pull/185152 — "Support soft hyphen (U+00AD) rendering with a Hyphens API", open, `CHANGES_REQUESTED`, last touched 2026-09-10
[flutter/packages#12728]: https://github.com/flutter/packages/pull/12728 — the unrelated `material_ui` test cleanup PR #185152 is blocked on; itself open
[#185154]: https://github.com/flutter/flutter/issues/185154 — "Design doc: Soft hyphen (U+00AD) rendering"; scoped to manual soft hyphens, with `Hyphens.auto` explicitly excluded
[#189234]: https://github.com/flutter/flutter/issues/189234 — the rendered soft-hyphen glyph is excluded from the selection highlight
[Skia-hyphen]: https://github.com/google/skia/commit/98daf58d4cb82f705a2a503047e5c2ea81a29922 — "[skparagraph] Render visible hyphen at soft hyphen (U+00AD) line breaks", 2026-04-13, gated behind `setRenderSoftHyphens()` which *"defaults to false"*
[Skia-style]: https://github.com/google/skia/blob/8df24be66531469e576a806749a0202ae26b8d08/modules/skparagraph/include/ParagraphStyle.h#L137-L155 — `fRenderSoftHyphens = false` in the exact Skia revision Flutter 3.47.2 pins
[Flutter-deps]: https://github.com/flutter/flutter/blob/3.47.2/DEPS#L19 — `skia_revision` at tag 3.47.2, the revision containing the commit above
[Flutter-text]: https://github.com/flutter/flutter/blob/3.47.2/engine/src/flutter/lib/ui/text.dart — `dart:ui`'s text layer at the pinned tag; the string `hyphen` appears zero times
[Flutter-linemetrics]: https://api.flutter.dev/flutter/dart-ui/LineMetrics-class.html — nine fields, all geometry plus `hardBreak`; no character index
[Flutter-textpainter]: https://api.flutter.dev/flutter/painting/TextPainter-class.html — `paint`, `computeLineMetrics`, `getLineBoundary`, `getPositionForOffset`; one paint entry point, no per-line one

[Hyphen-pub]: https://pub.dev/packages/hyphen — version 0.4.0, published 2026-09-09; three likes, 150/160 points, 1,367 downloads in 30 days, `license:unknown`
[Hyphen-pubspec]: https://github.com/tstumpSC/hyphen/blob/112525bba42e69c5a3f366ca63e9c61c2b51b653/pubspec.yaml — SDK `^3.7.0`; the two runtime dependencies, `flutter` and `characters`
[Hyphen-licence]: https://github.com/tstumpSC/hyphen/blob/112525bba42e69c5a3f366ca63e9c61c2b51b653/LICENSE — MIT + MPL-2.0, © 2025 SchoolCraft GmbH
[Hyphen-third-party]: https://github.com/tstumpSC/hyphen/blob/112525bba42e69c5a3f366ca63e9c61c2b51b653/THIRD_PARTY_LICENSES.md — the pattern-licence warning, and `hyph_en_US` named as notice-preserving and not MPL/LGPL-compatible
[Hyphen-readme]: https://github.com/tstumpSC/hyphen/blob/112525bba42e69c5a3f366ca63e9c61c2b51b653/README.md — *"These are not bundled due to licensing reasons"*, and the `substrings.pl` recipe

[CTE-pub]: https://pub.dev/packages/custom_text_engine — version 0.1.5, published 2025-12-16, one like, 40 downloads in 30 days, Apache-2.0, unverified uploader
[CTE-hyphenator]: https://github.com/1bgn/custom_text_engine/blob/c606ec4384b483228ad2c5a7263d91dbf502193a/lib/src/layout_engine/hyphenator.dart — the eleven hand-typed rules and the Russian letter classes
[CTE-widget]: https://github.com/1bgn/custom_text_engine/blob/c606ec4384b483228ad2c5a7263d91dbf502193a/lib/src/widget/advanced_text.dart — `_rebuildLayoutIfNeeded`, which returns early unless the **width** changed; no `didUpdateWidget`

[Patra-reader-rules]: ../../lib/src/features/reader/CLAUDE.md — the ragged-right measurement this note amends rather than reverses
[Patra-book-page]: ../../lib/src/features/reader/book_page.dart — `BookAnchor` (141-182), `Text.rich` (391), `TextAlign.start` (403), the `shy` entity (456)
[Patra-book-face]: ../../lib/src/features/reader/book_face.dart — `bookStyleSheets` (320), `parseBookDirection` (361), `_stillPicksOutThePage` (402), `_neverMatches` (469)
[Patra-licences]: ../../lib/src/branding/patra_font_licenses.dart — `registerPatraFontLicenses`, the seam patterns would join
[ADR-0008]: ../adr/0008-kavita-paginates-a-book-the-app-parses-no-epub.md — no EPUB parsing, no new dependency
[ADR-0009]: ../adr/0009-a-saved-copy-keeps-the-pagination-it-was-made-with.md — a copy is the server's pages, and progress is a page number
[ADR-0010]: ../adr/0010-a-book-page-is-drawn-by-the-app-not-a-web-view.md — the app draws the page itself, and refuses a web view and a dependency with it
[ADR-0012]: ../adr/0012-a-book-is-set-in-the-face-the-book-asks-for.md — the precedent for deferring to a book's own design, and the shape justification would take
