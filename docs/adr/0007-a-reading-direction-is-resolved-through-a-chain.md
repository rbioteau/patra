# ADR-0007 — A reading direction is resolved through a chain, and only the direction is remembered per series

**Status:** accepted · **Date:** 2026-09-13

## Context

The direction a chapter is read in was local state: taken from the profile's
own preference when the chapter opened, changed only in memory, and written
nowhere. The documented reason was that *a direction belongs to the book,
magnifying and the width belong to the hand* — and half of that is right.
Of the three rows in the cog's sheet the direction is the one that is about
the work; but it was not remembered for that work either, so it was neither
the person's preference nor a per-work setting. Measured: a chapter set to
vertical reopens paged, the profile's preference untouched, and no write
reaches the keychain at all. The other two rows in the same sheet — magnifying
and the width a chapter opens at — both write through.

At the same time the reading preferences are leaving Settings, because the
reader is where somebody notices they want them: magnifying and the width are
already gone. The direction's row stayed only because the reader had no way to
set a default of its own, and the screen says so where it still draws it.

So the direction needs two things the other two do not. It needs a value the
app can arrive at **without anybody choosing one** — detected from the work,
which is #57 — and it needs somewhere to keep a choice that is about one work
rather than about the person. Magnifying and the width need neither.

## Decision

Which direction a chapter opens in is answered by **one chain, each rung asked
only when the one above it has no answer**:

1. the **series direction** — a direction chosen for that one series;
2. the **profile's own** direction;
3. the **detected direction** — #57's rung, which has no answer for now;
4. the **device default**.

A series direction belongs to the profile that chose it and is never sent to
the server. It is stored beside that profile's other preferences, as a map of
series id to direction, in the one keychain row that store already writes
whole — so removing a profile takes it with its preferences, which is what
removing a profile already promises.

**Only the direction gets a per-series rung.** Magnifying and the width stay
preferences of the person, set from the cog. There is nothing in a file that
could tell us how somebody's hand works, and a guess that switched magnifying
off for webtoons would fight the person who needs it everywhere — which is
the same observation the original "this belongs to the hand" was making.

**Nothing anybody chose is ever outranked by the detected rung.** Only a
profile or a device that has *stored* a direction stands above it, and having
stored nothing is not the same as the built-in left-to-right fallback: that is
the distinction the stored language already makes between an empty string and
an absent key. A guess must never beat a choice.

The chain is shipped complete, with the detected rung present but empty, so
#57 fills one function and no screen changes.

The reader's sheet says **where the direction in force came from** — the
series' own, the profile's default, or detected — rather than only checking a
row, because a checked row reads as "I chose this" and a guess is not a
choice.

## Consequences

- Setting a series to the value the default happens to hold is not the same
  as leaving it unset: a series that is set stops following a default that
  later changes, where one with no series direction follows it wherever it
  goes. The sheet therefore owes an explicit way back, and an explicit way to
  promote a series' choice to the profile's own.
- Promoting a direction to the profile's own does **not** clear the series
  direction: one tap, one thing, and the way back from the series remains
  free because it now lands on the same value.
- A profile default, once promoted from the reader, outranks detection for
  every series, and nothing today can drop it again. **#58 must answer this
  before it takes the direction's row out of Settings**: the row cannot go
  until the reader can also *unset* a default. Written here so the gap is not
  discovered by whoever picks #58 up.
- The device default keeps its place as the last rung and gains no new
  surface: nothing outside a session reads it, and Settings' row is the
  profile's.

## Considered options

- **Per-series magnifying and width as well.** Deferred rather than rejected:
  a webtoon at 100% and a scanned manga narrower is plausible, but it is not
  what anybody reported, and the direction is the one setting that is about
  the work.
- **Asking for a scope when a direction is picked** (this chapter / this
  series / my default). Three taps where there were two, and it makes the
  common case — this series — a menu.
- **Letting the detected rung outrank a stored choice.** Rejected: a guess
  must never beat a choice, and a household that set a direction once would
  be corrected by a heuristic.

## Amendment — 2026-09-13 (#56)

The numbered rungs above put the detected direction third and the device
default fourth, which contradicts this ADR's own rule in the same section:
*only a profile or a device that has **stored** a direction stands above [the
detected rung]*. The two cannot both hold — a device that has stored a
direction is outranked by detection under the numbering and outranks it under
the rule.

Implemented (#56) as the rule says, because the rule is the decision and the
numbering is a summary of it: **the device's stored default is asked before
the detected direction**, and the built-in left-to-right — which is what an
absent key falls back to, and which nobody chose — sits behind both. The
detected rung is therefore asked while the device holds nothing and stands
down the moment it does, which is what "storing nothing is not the same as
having stored left-to-right" has to mean for the chain to be a chain of
choices.

The last bullet of [Consequences] is amended with it: the device default is
not the last rung. It is the last rung *anybody chose*.

## Amendment — 2026-09-13 (#58)

The reading profile's own direction is **removed** from the chain.

It was kept for one reason, in this ADR's own words: *the direction's row
stayed only because the reader had no way to set a default of its own*. #57
removes that reason. Detection is per series — `detectedDirectionProvider` is
a family of the series id, and `ChapterInfo` already carries the library type,
the series format and the page dimensions a guess is made from — so what the
profile's default was doing, choosing a direction for works nobody has opened,
is what detection does better and *per work*.

It was also the wrong shape. The direction is **a property of the work**,
which is this ADR's own reason for giving it a per-series rung and refusing
one to magnifying and the width. A rung held by a person overrides detection
for **every** series at once, so in a library holding manga and webtoons side
by side it is precisely wrong: set right-to-left and every webtoon in it opens
paged. The one case the rung genuinely served — a library the guess gets
systematically wrong — is answered *below* the series, not above it, and is
written up as such at the end of this amendment.

The chain therefore reads:

1. the **series** direction;
2. the **detected** direction (#57);
3. the built-in left-to-right.

The **device's** stored default is removed with the profile's: its only writer
was the notifier this amendment deletes, so nothing can store one, and a rung
that cannot be written is not a rung. The built-in left-to-right keeps its
place at the end, and is still the one answer nobody chose.

Nothing else in this ADR changes. *A guess must never beat a choice* still
holds, and is the stronger for there being one choice above detection rather
than three. The sheet still says where the direction in force came from — the
series' own, detected, or the built-in — and still owes a row back from a
series' own choice, now worded with the direction the work itself suggests.

**Sequencing.** This amendment must not be implemented before #57 lands.
Detection answers nothing today, so removing the profile's rung while it is
empty drops every series a person has not set to the built-in left-to-right: a
manga reader who stored right-to-left would find the whole app reading
backwards, and the per-series rung is two days old, so almost nobody has one.

The bullet of [Consequences] saying #58 *"must answer this before it takes the
direction's row out of Settings"* is **superseded**: there is no default to
unset, and #58 is no longer blocked on one.

### A direction per library, planned

The case the profile's rung covered is not empty. A "Manga" library holding
manhua — whose pages are the shape of manga's, and would be detected
right-to-left when they read the other way — is wrong for every series in it.
A default held **per library** answers that in one tap and has the right
shape: a library is a shelf of works, so it belongs on the work's side of the
chain, under the series and above detection. It is also cheap to add —
`ChapterInfo.libraryId` is already in the reader's hand, `Library` carries its
own name, and the storage would mirror the per-series map that already
exists.

**Planned, and it lands before or with the profile rung's removal.** This
amendment first deferred it, for the reason per-series magnifying was: nobody
had complained, because detection does not exist yet. That reasoning does not
survive what triaging #57 established — the genres and tags a series carries
say what a work is *about* and nothing about how it is read, so detection
rests on the library type and the shape of the pages, and nothing else. A
library whose type is wrong is therefore wrong for **every** series in it, and
with the profile rung gone there is no rung between the series and detection
left to correct it.

The per-library direction is not an extra beside the profile's. It is what
replaces it.

## Amendment — 2026-09-13 (#57)

The detected rung has an answer, and filling it changed no screen — which is
what shipping the chain complete with an empty rung was for.

It is measured **from the chapter being read**. `chapter-info` is the one
place page dimensions reach the app, and it is asked for one chapter at a
time: the catalogue deliberately keeps reader-level data out (ADR-0005), and
a saved chapter carries a page count and no dimensions. So the reader's own
fetch is what measures a work, and what it measures is recorded against the
**series** rather than the chapter it was measured on, for the reason this
ADR already gives — a direction detected for one chapter of a work is a
direction for the work. The record is a measurement and not a preference:
nothing is written to the device, a series is measured again when it is
opened again, and the container it lives in is rebuilt for every profile.

The two signals the guess is made from **answer different questions, so there
is no precedence to arbitrate** between them:

- **whether** a work is vertical is a property of the pages: the median
  tallness (height over width) of the pages the server did not call a spread,
  at **1.8** — a number measured on a real library rather than chosen, and
  written up in `docs/research/reader-vertical-page-shape.md`;
- **which way** it goes when it is not is a convention of origin, which the
  library type is the only witness to: a manga library reads right to left,
  every other one the way a chapter always has.

Nothing above this rung moved. A guess is still asked only while the series,
the profile and the device have all answered nothing, and the sheet still
says that what is in force was detected rather than chosen.
