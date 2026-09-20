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

The chain therefore reads — with the library's rung, which #65 built before
this amendment was implemented:

1. the **series** direction;
2. the **library** direction (#65);
3. the **detected** direction (#57);
4. the built-in left-to-right.

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

### A direction per library, shipped (#65)

The case the profile's rung covered is not empty. A "Manga" library holding
manhua — whose pages are the shape of manga's, and would be detected
right-to-left when they read the other way — is wrong for every series in it.
A default held **per library** answers that in one tap and has the right
shape: a library is a shelf of works, so it belongs on the work's side of the
chain, under the series and above detection. It was also cheap to add —
`ChapterInfo.libraryId` was already in the reader's hand, `Library` carries its
own name, and the storage mirrors the per-series map that already existed.

**It lands before or with the profile rung's removal** — which is why it is
being built first (#65). This amendment first deferred it, for the reason
per-series magnifying was: nobody had complained, because detection did not
exist yet. That reasoning does not survive what triaging #57 established — the
genres and tags a series carries say what a work is *about* and nothing about
how it is read, so detection rests on the library type and the shape of the
pages, and nothing else. A library whose type is wrong is therefore wrong for
**every** series in it, and with the profile rung gone there is no rung
between the series and detection left to correct it.

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

## Amendment — 2026-09-13 (#65)

The per-library direction is built, and it is the second rung: **the series',
then the library's**, then the detected direction, then the built-in
left-to-right. The two rungs about a person and a device that used to sit
between the library's and the detected one are gone with the amendment above.

It sits **directly under the series'** rather than merely somewhere above
detection, for two reasons. Both rungs are answers about the work's side of the
chain, and a library is the wider of the two. And it is what *replaces* the
profile's own, so it has to be the rung every series in the library follows
**even while a person has a default of their own stored** — otherwise the case
it exists for, a library the guess gets wrong, is outranked by the very
default this ADR says is the wrong shape.

It is stored as `ProfilePreferences.libraryDirections`, a map of library id to
direction in the same keychain row as the per-series map, read and written by
the same parser: a choice about works, belonging to the profile that made it,
never sent to the server, and gone when the profile is. The reader's sheet
gained what the series rung already had — a row promoting the direction in
force to the library's, a row back from it worded with where the chapter
really lands, and a line of provenance — and reports each as a
`ReaderSettingsOutcome` for the reader to act on, as it does for the series.

**The name those rows are worded with is read off the spine the device already
holds, and not through the catalogue's library list.** Watching that read is a
request, and its write starts the eager fill, which pages every library's
series; opening a chapter is not the moment to fill a household's catalogue.
Where the device holds no name yet the rows say "this library" instead.

The [Consequences] bullet about promoting a default that nothing can unset
applies to this rung too, and is answered the same way: a library that is set
owes a row back.

## Amendment — 2026-09-13 (#58, shipped)

The removal above is implemented, and it is the whole of what Settings lost:
the screen has no reading section now, and nothing was reachable only from it.
`ProfilePreferences.direction`, `ProfilePreferencesStore.deviceDirection` and
`ReadingSettingsStore`'s direction row are gone with the two notifiers that
wrote them, and `ChapterDirection` asks three rungs where it asked five.

**A direction somebody had really stored is dropped rather than migrated**, and
that is a decision rather than an oversight: there is nothing to migrate it
*to*. A profile's default was one direction for every series they read, and the
only rung that could inherit it is a library's — but a profile's default is not
per library, so there is no library to copy it onto. Whoever had one is now
read by detection, per work, with the library's rung available where a library
is guessed wrong. The key is left on the device and is simply not read.

*A guess must never beat a choice* still holds, and is the whole of what is
left to state: the two rungs above the detected one are the series' and the
library's, and both are choices about works.

## Amendment — 2026-09-20 (#118)

The detected rung gains a **third kind of evidence**, and it is the first of
the three asked: **what a book declared of itself**.

The two signals #57 named are both inferences from what the server measured.
This one is not — it is the work's own statement, and it arrives because
Kavita hands a book's CSS over with every page of it. Both conventional
places for a base direction are thrown away on the way: `PrepareFinalHtml`
copies the classes off a book's `<html>` and `<body>` and returns their inner
HTML in a wrapper of its own, so a `dir` attribute and an `<html lang>` never
reach us while the stylesheet does. A book that declares itself right-to-left
was therefore laid out left-to-right with nothing in the app knowing it.

It is asked **before** the two measurements rather than beside them, and that
is not a precedence between competing answers — it is where the questions
stop overlapping. A declaration answers *which way the words run*, which the
library type only witnesses as a convention of origin. And a book has no page
dimensions at all for `chapter-info` to report, so asking the pages first
would read every book left to right and leave the declaration with nothing to
say. **Whether** a work is vertical stays the pages' answer alone, because no
book declares that: `direction` is an axis of writing and not a way of
turning pages.

It is evidence for the **detected** rung and nothing more, so nothing above
it moved: a series or a library somebody set still outranks it, and *a guess
must never beat a choice* holds unchanged. A reading of a book's own
stylesheet is closer to a fact than the other two are, but it is still the
app reading a file rather than a person choosing — and a book that scopes its
CSS unusually is exactly the case the rungs above exist for.

**A declaration is not a match.** `ScopeStyles` rewrites selectors and leaves
inert declarations behind by the handful — `html{}`, `:root{}`,
`html[dir=rtl]{}` and `body[dir=rtl]{}` all survive as text and apply to
nothing once the elements they named are gone — so "is `direction:rtl`
anywhere in the stylesheet" would over-trigger on books saying the opposite.
What counts is a rule whose selector still picks out the page as a whole: the
wrapper Kavita scopes a page into, everything, or the page's own paragraphs.
The wrapper's class list is weighed in one place only — it is what can make a
selector the rescoping broke match the page again, which is the case Kavita
assembles that list *for* — and it is never trusted alone, because what is
being read is still a `direction` the book declared.

**Nor is a rule that only applies sometimes.** At-rules are dropped whole,
with the rules inside them: nothing here can evaluate a media query, there is
no browser (ADR-0010), and the medium a `@media print` names is not the one
anybody is reading on. That matters more than it sounds, because the grammar
this app reads CSS with matches the *inner* rule of
`@media print{.book-content{direction:rtl}}` as though it stood on its own —
so an at-rule left in place turns a book on the strength of its print
stylesheet. The correction belongs to the one definition of what a rule is,
so it applies to the face as well: a font named in a print stylesheet was
never the face a page is set in either.

**Only right-to-left is read.** `direction: ltr` is the CSS default and is
written as a reset far more often than as a statement, so it cannot be told
from a stylesheet that says nothing; `rtl` is never written by accident.

Recorded against the **series**, like #57's measurement and for the reason
this ADR already gives: a direction read off one chapter of a work is a
direction for the work. An omnibus carrying a single right-to-left story
would turn whole, which is the case that could argue for per-chapter and is
written up on #118 rather than decided here.

**For a book the declaration is the whole of the detected rung.** The two
measurements above it are about scans and have nothing to go on for a book: it
carries no page dimensions at all, so a shape recorded for one answers
`isVertical: false` about a work nothing was measured of — and the library
type beside it then speaks, though what that type witnesses is a convention
about how *scans* are bound.

This amendment first shipped without that guard, and the cost was measured
rather than imagined. Against the demo server (Kavita 0.9.1.4,
`demo.kavitareader.com`), `chapter-info` reports `libraryType: 0` — **manga** —
for all 53 epubs of a library whose type is *Books*, while reporting
`seriesFormat: 3` correctly for every one of them. So the fault was not the
rare case of a book shelved oddly: **every book on every server** opened
right-to-left, with nothing in the book saying so and nothing on the shelf
either. The guard therefore keys off the chapter's *content* — derived from
the format, which the server does report — and never off the type it states. `PageShapesNotifier.record` now
refuses a reflowable chapter, which is a refusal of a *measurement* and not of
a work: a series holding both scans and words keeps what its scans measured. A
book declaring nothing therefore opens at the built-in left-to-right, which is
where a book has always opened.

What still reaches a book from above is the two rungs that are **choices** —
the series' and the library's — and that follows this ADR rather than
contradicting it. It leaves one sharp edge, recorded on #118 rather than
answered here: the book's cog offers no direction row, so a library set
right-to-left while reading its scans turns the epubs shelved beside them with
no row back.

The reader sets **both halves from that one answer** — the prose's
`Directionality`, so its `TextAlign.start` resolves to the right, and the
pager, which turns inside the same `Directionality` — because a book that
reads right-to-left while its pages turn left-to-right is worse than one that
does neither. `ReadingDirection.verticalScroll` collapses to left-to-right
for a book rather than becoming a third case: a book's pages are the server's
and they are turned, so what a vertical direction names is not something a
book has.

**The book's own language is the same hole and is not closed here.** Kavita
drops a book's `lang` exactly as it drops its `dir`, and #119 needs it for
hyphenation. This amendment establishes the shape an answer to it should take
— read out of what the page already hands over, recorded per work, feeding
the rung that guesses — and nothing more.
