# ADR-0002 — One rule decides where reading resumes, and it is ours

**Status:** accepted · **Date:** 2026-09-06

## Context

Two screens now have to answer the same question — *which chapter would you
resume?* The series screen has answered it since it was written, client-side:
order the chapters, take the first one that is not fully read
(`_SeriesHero._target()`). The home screen's Continue hero needs the same
answer, and needs the chapter itself as well, because it names the chapter and
counts the pages left in it.

Kavita offers `GET /api/Reader/continue-point?seriesId=`, an endpoint named for
exactly this job, returning the one `ChapterDto` the hero would otherwise have
to find for itself.

## Decision

The hero does not call it. It fetches `/api/Series/volumes` for its one
featured series and runs the **same rule the series screen runs**, extracted
into a single shared function. `continue-point` stays uncalled.

## Why

**The two rules are not known to agree.** The spec's own summary of
`continue-point` describes a different rule from ours — "loop through the
chapters and volumes in order to find the next chapter which has progress",
against our "the first chapter not fully read". With chapter 1 finished and
chapter 2 untouched, those two sentences do not obviously point at the same
chapter. Whether Kavita's implementation actually diverges is not knowable from
the spec: it is Swashbuckle output, and every expensive fact in this client came
from Kavita's C# source rather than from that file. Two screens of one app
offering to resume different chapters of one series is a bad enough outcome
that "they probably agree" is not a good enough reason.

**The server cannot see an optimistic write.** Swiping a chapter read on the
series screen moves the resume target on the gesture, not on the round trip:
`readOverridesProvider` lays the new progress over the fetched volumes. A
target decided by the server is a round trip behind that by definition. So
adopting `continue-point` everywhere would regress the series screen, and
adopting it only on the hero is the divergence above.

Extracting the rule makes the two screens agree *by construction* rather than
by coincidence, which is the only form of agreement that survives someone
editing one of them.

## Cost, accepted

`/api/Series/volumes` returns every volume and every chapter of the series,
where `continue-point` returns one chapter — and it lands on home load. This is
one request for one featured series, not one per tile, and it is the same
request the series screen makes the moment the user taps the hero's cover.

## Consequence

The shared rule is load-bearing on two screens. Changing it changes both, which
is the point of this decision rather than a side effect of it.
