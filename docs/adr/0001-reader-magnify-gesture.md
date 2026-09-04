# ADR-0001 — A one-finger drag magnifies the page, and the border wins

**Status:** accepted · **Date:** 2026-09-03

## Context

Pinching to zoom a page needs two thumbs and so a second hand, which is the
one thing a person reading on a phone usually does not have. The reader wanted
a one-finger alternative that "feels natural": press somewhere, and the page
magnifies around that point; the *direction* of the drag decides which part of
the page comes into view — pull down to see what is above the finger, pull
right to see what is to the left — and the *length* of the drag decides how
much it magnifies. One hard constraint came with it: **magnifying must never
show anything that is not page.** The border stays on screen.

The direction rules needed no case analysis in the end. They are all one rule —
the page is carried along with the finger, so what was on the far side of the
finger comes towards it — and the four directions fall out of it. What the
brief did not settle, and what turned out to be the whole design, is what
happens at an edge: press near the top of the page and pull down, and there is
nothing above to reveal. Something has to give.

## What was tried

A throwaway prototype (see below) put four complete answers side by side and
was driven by hand at several settings.

1. **The finger gives way.** Magnification keeps growing with the drag; the
   page stops at its border and the artwork slides out from under the finger.
2. **The gesture gives way.** The drag is honoured only as far as the page can
   follow it, and refused past that.
3. **The magnification gives way.** Where the page would run out, it magnifies
   harder than asked, by exactly enough that there is something there to show.
4. **Aim a loupe.** The finger does not carry the page at all: the drag aims at
   a point away from the finger and brings it to the middle of the screen.

Two facts came out of the prototype that were not obvious beforehand. The
border constraint does **not** discriminate between them — all four hold it, in
every one of 101,728 swept gestures — because clamping the pan is enough on its
own. And the letterbox bars beside a scan that does not match the screen's
shape are where the trouble lives: the page cannot move on that axis at all
until it has grown past the screen, so every dragging answer has a dead zone at
the start of the gesture.

Answers 2 and 3 are unusable near an edge, which is exactly where the gesture
matters most: 2 refuses about 92% of a drag started near the top and then does
nothing at all however hard you pull, and 3 jumps straight to the ceiling off a
20px drag. 4 works everywhere and never has to compromise, but gives up direct
manipulation — the page no longer follows the hand.

## Decision

**Answer 1.** The page follows the finger; where the drag asks to go past an
edge, the page stops at the edge and the grip is what gives way.

Settings: **2.5×** at strongest, over **400 logical pixels** of drag. Letting
go returns the page — the gesture is momentary, something held rather than a
mode within a mode.

The travel distance is deliberately **absolute, not a fraction of the screen**.
The ruler for this gesture is a thumb, and a thumb is the same size on a phone
and on a tablet; scaling the distance with the screen would make the same
magnification cost twice the reach on the bigger device for no reason a hand
would recognise. A logical pixel is already density-independent, so 400 is a
physical distance of roughly 6 cm. It is capped at the screen's longest side so
full magnification stays reachable in one drag, which on any real device is
inert.

At these settings there is little slack, so a page is pinned against an edge
for most of a typical drag and properly glued to the finger only near full
travel. That is not a defect of the choice — it is the choice. What a reader
can see is that the view walks towards the part they asked for and keeps
walking that way for the whole drag, and that the page never comes off the
screen.

## Consequences

- **The swipe that turns a page is gone while the mode is on.** Two recognisers
  cannot share one drag. Pages turn by tapping the side zones, which already
  existed. This is why the setting is off by default and why its row in
  Settings says so.
- **Vertical scrolling is excluded.** There the drag *is* how the chapter
  advances; taking it would leave no way through at all.
- The reference point is taken from the pointer-down, not from `onPanStart`,
  which reports where the pan was *recognised* — already a slop distance (~18pt)
  into the drag, in the direction of travel.
- Wiring this up uncovered a pre-existing bug: the first tap on a side zone
  never turned the page, and the second skipped one. Harmless while swiping was
  the usual way through a chapter; fatal once tapping is the only way. Fixed
  and pinned.

## The prototype

Kept as a primary source on the throwaway branch **`prototype/reader-loupe-gesture`**,
one self-contained HTML file that opens by double-click:

```sh
git show prototype/reader-loupe-gesture:lib/src/features/reader/prototype_zoom_gesture.html > /tmp/loupe.html
```

Its `ZoomGesture` module holds all four answers; `lib/src/features/reader/magnify_gesture.dart`
is the accepted one, ported.
