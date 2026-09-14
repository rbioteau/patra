# ADR-0009 — A saved copy keeps the pagination it was made with

**Status:** accepted · **Date:** 2026-09-14

## Context

ADR-0008 makes Kavita the thing that paginates a book, which means a saved copy
cannot be the EPUB file: with no server there is nothing to lay the text out, so
what has to be stored is the pages *as the server rendered them* the day the copy
was made.

That leaves a fact with no owner. `BookPageLayoutMode` (default / one column /
two columns) is a setting on the server and is **not** a parameter of
`GET /api/Book/{chapterId}/book-page`, so the server can recount a book at any
time and the app cannot ask it not to. A copy saved at 120 pages can find itself
out of step with a server that now says 200 — and since progress is reported as
a page number, being out of step means offering to resume at the wrong place.

## Decision

A saved copy stores the pages it was given, and the page total it was given with
them. When the server is reachable again and reports a different total, the copy
is **marked stale and offered for re-download**. It is not silently re-fetched,
and it is not silently kept.

## Why

**The two silent answers are both worse than the honest one.** Drifting in
silence puts the reader back into the wrong page of a book they deliberately
saved for later — the one failure that makes the Downloads tab look broken.
Re-fetching in silence spends network and disk on an event that may never
happen, and would quietly rewrite a copy the reader chose. Naming the state
costs one integer in the copy's metadata and one piece of copy on the row.

**The number is already there.** `book-info` answers with `pages` on every
visit, so the comparison is free and needs no new endpoint, no new polling and
no version negotiation.

## Cost, accepted

The Downloads tab grows a state it did not have ("this copy is out of date"),
and a book's saved copy is a directory of pages rather than the single file an
archive would be — each page self-contained, its resources inlined, because
there is no server left to fetch them from.

## Consequence

Progress written from a stale copy is still a page number in a pagination the
server no longer shares. Writing it is not wrong — it is the best answer the
device has, and the server owns the number — but it is why the copy says so out
loud instead of pretending the two agree.
