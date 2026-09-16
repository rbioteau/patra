# ADR-0011 — A second theme is deferred, not rejected

**Status:** accepted · **Date:** 2026-09-16

## Context

The app ships **one** dark theme: `ThemeMode.dark`, with `theme` and `darkTheme`
both `patraTheme()`, the reader's canvas pure black and every token in the theme
built around it. #75 closed the question for its own scope in as many words —
"the text keeps the app's own typeface on the app's dark background; no second
theme is introduced" — and #81 asked whether that ruling is permanent or merely
a deferral nobody had written down.

It matters because of a device class the app never considered. Android e-readers
(Boox, Bigme, Meebook) run the app, and on an e-ink panel a dark theme is the
wrong way round. The panel is **reflective**: black areas reflect almost nothing
towards the eye, so the front light has to be raised and the result reads grey
and uneven. E Ink's own documentation is explicit that the waveform set is
tuned for dark ink on a light ground, and that residual pigment — ghosting — is
far more conspicuous against black than against white. Our canvas is *pure*
black, the worst case of that.

Two facts from the palette make the question harder than "invert it". The accent
gold `#D7B976` is a **light ink** — the root `CLAUDE.md` says so, which is why
`patraOnAccent` exists — and it measures **1.89:1** against white. The offline
blue `#8EACD8` measures **2.32:1**. Neither can be an ink on a light ground. And
there is no reliable way to know we are on e-ink: no standard Android API, only
vendor SDKs (Onyx and the rest), none of which Flutter sees.

## Decision

**No second theme is built now. It is not rejected.** #75's ruling stands for
today and is recorded as a deferral rather than a refusal, so the question stops
being reopened from scratch.

If one is built, it is this one:

- **Whole-app**, not the reading surface alone.
- **Hue-free**: ink and ground, with hierarchy carried by value and weight
  rather than by colour. No accent on it.
- Gold stays where the brand lives — the dark theme, the icon, and the launch
  animation, none of which a theme touches.
- A **preference** per profile, with a device default — the same shape as the
  text size and the line spacing.
- Its reason for existing is e-ink. It is offered to everybody anyway, because
  e-ink cannot be detected.

## Why

**The chrome ghosts too.** A light page under a black bar is half a fix: the
chrome is static, so it ghosts less, but a light reading surface was the cheap
answer and it would have left the app's identity inverted around the one surface
that is right.

**A hue-free theme is the only one that survives a greyscale panel.** On e-ink,
gold and the offline blue both land as a mid-grey, so the distinction the design
system draws between them — progress is gold, downloads are blue, never swap —
is *already* lost there. Carrying hue into a theme built for those screens would
be pretending otherwise.

**We are not inventing a bronze.** A darkened gold that holds on white would
keep "progress is gold" alive on both themes, and it was the tempting answer.
The brand kit lives outside this repository and is the source of truth for the
palette; a second gold would be a colour it does not contain, invented by a
session that cannot re-export from it.

**Detection was considered and refused.** Best-effort detection buys a guess
correct on a handful of devices and wrong on the rest, and a wrong guess here is
worse than no answer: it silently inverts somebody's reader.

## Cost, accepted

Someone who chooses the light theme on an ordinary screen gets **an app with no
gold in it**. That is the price of (b) over inventing a colour, and it is
acceptable because the brand does not live only in the theme: the icon is the
word in gold on night blue, and the launch animation assembles it.

The other costs are known and none of them is a surprise:

- `CoverPlaceholder`'s 24 derived tones are two near-black tones, dark and
  low-contrast **on purpose** so they never compete with real artwork. On a
  light ground every missing cover becomes a dark blob, so the derivation needs
  a light counterpart.
- **The launch screen is the ink and nothing else, on every path**, with a
  `values-night-v31` qualifier. A light theme needs the non-night variant
  written, or a cold start flashes ink → paper at Flutter's first frame — the
  exact thing that decision exists to prevent.
- "The reader canvas is pure black and the whole chrome is built around it"
  stops being true. That is the e-ink win, and it is also a design invariant
  going away.
- The word पत्र is drawn **in the accent gold**. Inside the app it will need
  another answer; on the icon and at launch it does not.

## Consequence

#81 closes as *answered* rather than *built*: the four questions it raised are
settled, and the one that was left open is recorded here instead of in an open
issue. A light theme, when it is built, is a second token set and a second
launch background — not a flag on one surface.

## Considered options

- **Reject a second theme outright.** Rejected: e-ink is a real device class and
  this is a reading app; the door was open for a reason.
- **A light reading surface only, chrome left black.** Rejected above: half a
  fix, and the wrong half.
- **Detect e-ink.** Rejected above.
- **A light theme with a darkened gold.** Rejected above: not in the brand kit.
