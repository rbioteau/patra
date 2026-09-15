# ADR-0008 — Kavita paginates a book; the app parses no EPUB

**Status:** accepted · **Date:** 2026-09-14

## Context

A chapter can be made of [[Reflowable content]] — an EPUB — and the app
refused those from the day it was written: `MangaFormat.content` answers
`reflowable` for them (it was `MangaFormat.isImageReadable` when this was
decided), and the series screen dimmed the row and answered "Format not
supported yet". Making them readable meant choosing who turns a file of
words into pages.

The obvious reading of the API is that the client does it. Kavita *does* expose
the file (`GET /api/Download/chapter`), and there are Dart packages that open an
EPUB: `epubx` (a parser), `epub_view` and `flutter_epub_viewer` (epub.js in a
WebView), `flureadium` (Readium, native). Choosing one of those makes the app
own pagination, the CFI/anchor scheme, the layout of arbitrary XHTML and the
sanitising of whatever CSS the file ships with.

Kavita also offers the opposite: `GET /api/Book/{chapterId}/book-info` (whose
`BookInfoDto` carries `pages`), `book-page?page=N`, which returns "a single page
within the epub book… all html will be rewritten to be scoped within our reader,
all css is scoped", `book-resources?file=` for what the page references, and
`chapters`, a table of contents with page numbers. Its own web client is the
reference consumer of all four, and has been since v0.4.

## Decision

The app never opens the EPUB file. It asks Kavita for the page it wants and
renders the HTML it is given. No EPUB parsing, no epub.js, no Readium, and no
new dependency.

## Why

**The server has already done the hard part, and the hard part is hostile input.**
Kavita scopes the HTML and the CSS for us. A book that ships a stylesheet
redefining `body` cannot repaint our chrome, and we never have to decide how
much of an EPUB's CSS to honour. Reimplementing that in the app is a browser,
not a feature.

**Progress keeps its shape.** `BookInfoDto` has `pages`, and
`POST /api/Reader/progress` takes a `pageNum` — the same integer the image
reader already posts. So `pagesRead >= pages`, the resume rule, the hero's ring,
Continue and On deck all carry over untouched. A client that paginates locally
would have to invent a mapping from its own positions onto a page number the
server counts, and the two would drift.

**The local toolkits do not run where we develop.** `flutter_epub_viewer`
excludes Linux, and Readium is mobile-only; Linux desktop is this project's fast
local target and losing it costs the dev loop on every screen. Everything the
server path needs works there.

**One pagination, not two.** A local renderer is the only way to read with no
server, which is tempting — but it would mean two layouts, two notions of a page
and two ways to report progress, one for online and one for saved. ADR-0009
takes the offline case instead by storing the server's own pages.

## Cost, accepted

Reading a book needs the server. This is the same trade the app already makes
for everything except chapters the reader deliberately saved, and it is why
ADR-0009 exists.

## Consequence

A page of a book is whatever Kavita says it is, and Kavita can change its mind:
`BookPageLayoutMode` (default / one column / two columns) is a server setting
and is **not** a parameter of `book-page`, so the same book can be recounted
under us. That is ADR-0009's problem; here it only means a page number is a
position in the server's pagination and never an arithmetic fact we own.

## Considered options

- **`epubx` + Flutter widgets** — a layout engine for XHTML, written by us.
  Rejected: months of work to arrive at less than the server already returns.
- **`flutter_epub_viewer` / `epub_view` (epub.js in a WebView)** — rejected: we
  would own pagination and anchors, and lose Linux.
- **`flureadium` (Readium)** — rejected: mobile-only, same loss, plus a native
  toolkit in an app whose reader is otherwise all Flutter.
