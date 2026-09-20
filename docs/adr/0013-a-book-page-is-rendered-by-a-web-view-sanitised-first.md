# ADR-0013 — A book's page is rendered by a web view, sanitised first

**Status:** accepted · **Date:** 2026-09-20 · **Supersedes:** [ADR-0010](0010-a-book-page-is-drawn-by-the-app-not-a-web-view.md)

## Context

ADR-0010 decided that the app takes Kavita's scoped HTML apart itself and draws
the pieces in Flutter. It was right on the evidence it had. Three things have
since been measured that it did not have, and two of them cut against it.

**A browser hyphenates in the book's own language, on both platforms this app
ships to.** [#119] established that a browser hyphenates and that *"hyphenation
is not a nicety on top of justification — it is the thing justification needs"*,
but its own probe could not tell `lang="en"` from `lang="fr"`, so the half that
decides anything was never shown. [hyphenation-probe.html] is built from words
the two languages break differently, over two independent families — `s` +
consonant, where English breaks before the `s` and French after it, and the `gn`
digraph French never splits — and sweeps the column rather than picking one
width, because an engine takes the latest break that fits. Measured on device on
2026-09-20: **five words of five separated, on Chrome/Android and Safari/iOS
alike.**

**The app cannot draw the mark, and there is no date by which it could.**
[book-hyphenation.md] set out to cost hyphenation and found the two halves have
opposite answers: Liang's algorithm is 88 lines and French is 9,674 bytes, but
*"nobody can draw the hyphen. Not 'it is hard': there is no fixed point to
reach"* — the engine breaks a line to fit without the hyphen's width, so drawing
one at the break moves the break. Skia's `setRenderSoftHyphens` ships inside the
3.47.2 binary defaulted off and [PR #185152] would expose it, open with changes
requested. So the native route's remaining cost is a wait of unknown length for
the one part that cannot be worked around.

**Kavita sanitises nothing, and this is the fact that shapes the decision rather
than the two above.** Verified against `Kavita.Services/BookService.cs` at
v0.9.1.4: `<script>` is not stripped but deliberately *preserved* — `EscapeTags`
(L921-925) closes self-closing script tags so HtmlAgilityPack keeps them
well-formed, and the word counters merely skip their contents
(`node.ParentNode?.Name != "script"`, L1025, L1168, L1208), which proves they are
still in the tree. Inline `on*` handlers are untouched. `PrepareFinalHtml`
(L405-422) hoists classes and returns `body.InnerHtml` verbatim. There is no
sanitiser library in the repository. An EPUB is a file somebody dropped into a
library, so this is third-party content with live script.

What makes that moot today is the parser: `test/book_reader_test.dart:924-932`,
*"a script and a stylesheet are not words"*. A web view would execute what the
parser drops on the floor, and **disabling JavaScript does not answer it**:
`onNavigationRequest` is main-frame only by explicit guard
(`android_webview_controller.dart:1635-1650`), `webview_flutter` wraps no
`shouldInterceptRequest`, no `WKURLSchemeHandler` and no `WKContentRuleList`, so
`@font-face { src: url(…) }` and `<img src="http://…">` reach the network unseen.
Disabling it also costs the scroll anchor: `getScrollPosition` and
`setOnScrollPositionChange` are native and need no JavaScript, but the scrollable
**extent** is wrapped nowhere at any layer — neither `WebView.getContentHeight()`
nor `WKWebView.scrollView.contentSize` — and `BookAnchor` is a fraction by
construction (`book_page.dart:163-166`).

ADR-0010's own three reasons, re-read against this: the **pictures** argument it
already conceded does not carry the decision; the **Linux** argument is a
development cost, since `CLAUDE.md` has Linux as *"purely a fast local dev
target"* and nothing ships there; and **nothing paints under a test binding**
stands, unchanged and unanswered.

## Decision

A book's page body is rendered by a web view — `webview_flutter`, the official
plugin — and **the HTML is rewritten in Dart before it ever reaches it**. One
pass strips `<script>` and `on*` handlers, rewrites every remote `url()`, points
pictures at local files, and injects a `<meta http-equiv="Content-Security-
Policy">`. JavaScript is then enabled, for the app's own scroll bridge and
nothing else.

The reader keeps authority over **text size, line height and reading face**,
imposed as `!important`; the book keeps everything else it declares. Where a book
declares no alignment, the app justifies and hyphenates — **but only where the
book's language is known**, since justifying without a dictionary is what opens
the rivers [#119] describes.

## Why

**The trust boundary is a pass over bytes the app holds, not a setting a third-
party engine honours.** It closes the egress channel `JavaScriptMode.disabled`
leaves open, and it costs nothing that was not already being built: the same pass
is what points pictures at files they can be fetched with, and what makes a saved
copy open on its own.

**It answers the study rather than building it.** No patterns bundled and no
licences carried; no rule invented for which languages ship, so `hyph-de-1996`'s
261,255 bytes stops being a question; no line breaker of our own, and with it
none of what one costs — `Text.rich`, the book's italics, the engine's bidi. And
nobody has to draw the hyphen.

**It is the only route whose answer grows.** Tables, ruby, vertical writing and a
picture set inline with text — the whole of ADR-0010's *Cost, accepted* — arrive
with it rather than as four more decisions.

**The language exists and is one field away.** `ChapterDto.Language` is BCP-47
out of the EPUB's own `dc:language` and rides on `GET /api/Series/volumes`, the
call the series screen already makes; 54 of 57 book series carry one on Kavita's
demo. `Chapter.fromJson` drops it today.

## Cost, accepted

**Sanitising HTML correctly is notoriously hard**, and choosing it does not make
it less so. It is the residual risk of this decision and it has no mitigation
here beyond keeping the pass small and auditable.

**Nothing paints under a test binding.** The renderer that ships is not the one
`test/book_reader_test.dart` pins. Of its 52 tests roughly 25 are renderer-
independent and survive; the parser's 14 survive because the parser does; the
~13 coupled to the render tree describe a path that is no longer shipped. What
replaces them is one golden on a device, run by hand before a tag — not CI.

**Every book already in a library changes appearance**, and nobody asked for it.

**No Linux and no Windows**; macOS is present but its scroll APIs are not. The
book page therefore cannot be looked at on the dev machine.

**Pictures are fetched before the page is drawn** rather than arriving under the
text as `CachedNetworkImage` lets them, so a richly illustrated page opens later
than it does today.

## Consequence

`book_page.dart`'s **parser survives and is not optional**: the downloader reads
`pictureSources` to know what to fetch and `renameBookPictures` to write a copy.
Its **renderer** is demoted to an explicitly development-only path — kept because
it is the only way to see a page of a book without a phone, named as such so that
it cannot be mistaken for what ships, and allowed to drift.

`BookAnchor` becomes a **block index plus a fraction within the block**, over ids
the rewrite emits; a stored anchor that still looks like a bare fraction is read
as one, the way `ReadingDirection._legacyNames` reads a renamed value.

A **saved copy becomes a directory rather than a file** — pictures and fonts as
siblings of the page, which is the shape fonts already had (`book-font`,
`book-font-italic`). Copies already written with pictures inlined as `data:` URIs
keep opening, because such a page is still valid; nothing is migrated.

ADR-0009 is untouched in substance and extended in kind: a saved copy keeps the
pagination it was made with, and now the **language** it was made with too, or a
book read on a train is hyphenated in nothing.

[#119]: https://github.com/rbioteau/patra/issues/119
[PR #185152]: https://github.com/flutter/flutter/pull/185152
[hyphenation-probe.html]: ../research/hyphenation-probe.html
[book-hyphenation.md]: ../research/book-hyphenation.md
