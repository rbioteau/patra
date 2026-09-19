# ADR-0012 — A book is set in the face the book asks for

**Status:** accepted · **Date:** 2026-09-19

## Context

A book's page has been drawn by this app since ADR-0010, and always in the
app's own type. *Which* type was a setting with four values, one per family the
app bundled (#92), and a profile that had never chosen read in Space Grotesk —
so the app restyled every book it opened, including the many that ship a face
their publisher chose deliberately.

The server's own client answers that question the other way round. Its font
choice is a sentinel named `Default` whose tooltip reads *"Default will load the
book's default font"*; it resolves to CSS `inherit`, and the reader then
**removes** the `font-family` it had set, leaving the book's own scoped
stylesheet to win (`epub-reader-settings.service.ts:663-668`,
`book-reader.component.ts:1980-2020`). Its list of faces — Merriweather, EB
Garamond, Fira Sans, Lato, Libre Baskerville, Open Dyslexic, and uploads of the
user's own — is an **override** on top of that, forced onto top-level elements
with `!important` and documented as best-effort: a book that sets `font-family`
on nested elements still wins, which is what the wiki warns about and issue
#4395 reports.

Kavita also makes that answer *available*. `BookService.InlineStyles` prepends
the book's own CSS to every page it hands over, `ScopeStyles` scopes it, and
`EscapeFontFamilyReferences` rewrites every `@font-face` source to
`book-resources` — which serves any file in the EPUB's manifest, `font/otf` and
`font/ttf` included. The server did not accidentally leave the book's fonts
reachable; it arranged for them.

## Decision

**A book is set in the face its own stylesheet asks for**, and the app's sans
stands in where the book asks for nothing. The setting offers three choices
rather than four families — the book's own, the app's serif, the app's sans —
and **the book's own is the default**.

The app also ships **three** families instead of four. Source Serif 4 and
Literata were both serifs, one for the interface and one for a book; the
interface's serif becomes Literata and Source Serif 4 leaves the repository.

## Why

**It is the ordinary answer, not a special one.** Every mainstream EPUB reader
honours a book's embedded fonts by default and offers its own faces as an
override, and the server's own client is one of them. A client that restyles
somebody's library is the one that has to argue for itself.

**The face is the one part of the book's design this app can honour.** It draws
the page itself (ADR-0010): the words are ragged right and never justified,
there is no hyphenation (the engine draws no hyphen at a soft break on Flutter
3.47.2 — measured, in the reader's rules), the size and the leading are the
reader's eyes, and the theme is the app's. Singling the face out is a partial
respect; refusing it would be none.

**A reader is choosing a kind of type, not a font.** The four family names said
nothing to somebody who does not already know what Literata looks like, and a
name on a row is a label where a sample is possible. Three rows, each composed
in the face it offers, say what they do by being it — which is also why the
name could go.

**One serif, because two was two answers to one question.** `PatraText.serifTitle`
and the book's own serif were the same decision made twice, and the second one
had a face with no italic of its own (`canSetItalic` was false for Source Serif
4 because its italic was deliberately not bundled). Literata ships its italic,
and the interface's titles, the wordmark and a book's prose now agree.

## Cost, accepted

**The app parses a little CSS.** `book_face.dart` reads the page's `<style>` for
`@font-face` blocks and for the rule that uses a family, and reads nothing else
of the book's stylesheet. A book that ships several families and never says
which one its words are in is read as asking for **nothing**, so the app's sans
stands in rather than setting a page of prose in whatever the book used for its
chapter titles.

**A font is loaded per book, for the life of the process.** `FontLoader`
registers a family globally and there is no way to unload one, so the face is
registered under a name namespaced by the chapter — a book shipping a font
called `Literata` must not shadow the app's own — and a second registration of
the same face is never made. A face the engine will not decode (a `.woff2`, or
a file the server refuses) leaves the book with no face rather than failing the
page, which is the same fallback a book that asks for nothing gets.

**A saved copy is no longer pages and nothing else.** It carries the book's face
as `book-font` and `book-font-italic` beside its pages, and promotion — which
deletes every file in a chapter's directory that is not a page — has one
exception it has to know about. The alternative, carrying the font as a data
URI inside every page, multiplies a 900 KB file by the number of pages.

**The default changes for everybody at once.** A profile that has never chosen
read in Space Grotesk and now reads in the book's own face, or in the app's
sans where the book has none. It is a change nobody asked for, in the direction
of the work rather than of the app.

## Consequence

`ReadingFace` is a choice among *kinds of type*, and the family behind one of
them is the book's business: `ReadingFace.resolve` is the single place that
decides, and a page and the row that chose it cannot disagree. The three names
a device may already hold are read as the choices that stand closest to them
(`_legacyNames`), because a preference stored as a string resets itself in
silence when the string stops being recognised.

The rows in the reader's sheet are composed in the face they offer — including
the book's own row, which is composed in the face the book actually resolved
to, and in the app's sans where it resolved to none.
