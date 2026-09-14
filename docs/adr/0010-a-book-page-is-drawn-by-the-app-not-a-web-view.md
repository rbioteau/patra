# ADR-0010 — A book's page is drawn by the app, not handed to a web view

**Status:** accepted · **Date:** 2026-09-14

## Context

ADR-0008 settled who turns a file of words into pages: Kavita does. `book-page`
hands back "a single page within the epub book… all html will be rewritten to be
scoped within our reader, all css is scoped", and the app renders what it is
given.

"Renders" was read, in the README and in the epic's own test plan, as *a styled
WebView is enough*: drop the HTML into a web view and let the platform draw it.
Two facts recorded in this repository say otherwise.

**Kavita's book endpoints are header-authenticated and take no `apiKey` in the
query** — `lib/src/api/CLAUDE.md`, and the one image URL in the app with none.
An `<img>` inside a web view can carry no header of ours, so a page's pictures
would never load: they are exactly what `book-resources` serves, and the
pictures are half of what an illustrated book is.

**A web view is not available where this project develops.** `webview_flutter`
has no Linux implementation; Linux desktop is the fast local target, and losing
it — which ADR-0008 gives as the reason to reject `flutter_epub_viewer` and
Readium — costs the dev loop on every screen. It is also a new dependency, which
ADR-0008's decision rules out in as many words, and it paints nothing under a
test binding, which is why the epic expected a seam to stand in for it.

## Decision

The app takes the server's HTML apart itself — into paragraphs, headings,
quotations, list items and pictures — and draws those in Flutter, in the app's
own type on the app's own background. No web view, no new dependency.

## Why

**A page's pictures can be fetched at all.** They go through
`CachedNetworkImage` with the session's headers and under `imageCacheKey`, like
every other image in the app, which is the only way `book-resources` answers.

**A book then looks like it belongs here.** On a black canvas in Space Grotesk
at a size the reader chose, with no stylesheet of ours injected into someone
else's document. A web view needs the opposite: CSS written to fight the book's
own.

**Everything else the epic asks for is cheaper this way.** The scroll anchor
inside a page (#72) is a `ScrollController` offset rather than a JavaScript
bridge; text size and line spacing (#75) are two numbers on a `TextStyle`
rather than injected CSS; and #77's self-contained stored page is the same
blocks with the bytes inlined.

**It is less code than it sounds, because the server already did the hard
part.** Kavita scopes the HTML and the CSS; what is left to honour is the
handful of tags a page of a book is really made of.

## Cost, accepted

A **subset** of HTML is honoured and no CSS is. Tables, ruby, vertical writing
and a picture set inline with text are not drawn as the book set them, and a
picture is always a block of its own. Tags the parser does not know are
transparent — their words are kept and their layout is not — so an unusual book
reads as words rather than as nothing.

## Consequence

`book_page.dart` is ours to keep, and it grows only where a book needs it. The
seam it hands the reader — `BookPage`, and `BookPageBody`'s `picture` builder —
is the whole of what a different renderer would have to satisfy, so hosting a
page body in a web view later, should Kavita ever serve one that needs it,
costs the reader nothing: not the progress arithmetic, not the offline shape,
and not one test.
