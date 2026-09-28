# Patra brand

Patra is a mobile reader (iPhone, iPad, Android) for Kavita, a self-hosted server of manga, comics and books. It is built for reading on a train: dark, quiet, and honest about what is on the device and what needs the server. Design every screen for a phone first, then answer the tablet (below).

## Identity

- The mark is the Devanagari word पत्र ("leaf, letter, page") in `var(--patra-accent)` gold, beside the Latin signature "Patra" in `var(--patra-text)` ivory with a gold dot. Use `guidelines/logos/patra-mark.svg` and `patra-signature.svg` exactly as they are; they are outlines, never set in a font. The app icon is `patra-icon-1024.png`: the gold word on `var(--patra-bg)`.
- One theme, dark. Everything sits on `var(--patra-bg)` night blue (#111722), with `var(--patra-chrome)` for bars and `var(--patra-surface)` / `var(--patra-surface-hi)` for what is raised. There is no light theme.

## The two colour rules

- **`var(--patra-accent)` gold is reading progress and identity, and nothing else.** Progress bars and rings of reading, the read rail, the resume button, the selected tab, a focused field, a text action. Text or icons on gold use `var(--patra-on-accent)` dark ink, never white.
- **`var(--patra-offline)` blue is downloads and offline, and nothing else.** Download rings and pills, the batch card, the saved-copy check, headers about the offline store.
- Never swap them, and never mix them on one control. A row may carry both facts at once (a reading bar on its cover and a download ring at its end), so they must stay two colours and two shapes.
- `var(--patra-danger)` is for destruction and failure only (remove, a failed download). `var(--patra-online)` is only the small status dot beside a server's host.

## Type

- The interface is set in Space Grotesk (`var(--patra-font-sans)`): `.patra-body` for copy, `.patra-row-title` for list rows, `.patra-metadata` for the lines under them, `.patra-section-label` for headers (uppercase, tracked 1.5px, `var(--patra-text-muted)`), `.patra-app-bar-title` for screen titles.
- Literata (`var(--patra-font-serif)`) is for **titles of works** (`.patra-serif-title`, 21px, 25px on tablet) and the reader's page numerals (`.patra-page-numeral`, tabular). Never use the serif for interface text, buttons or labels.
- A book's prose is the one exception: the reader chooses the face (the book's own, Space Grotesk, Literata or Atkinson Hyperlegible Next), the size (16px by default) and the leading (1.55 by default).
- All faces are bundled variable fonts and are never fetched.

## Layout

- Side margin `var(--patra-gutter)` (20px) on every screen; `var(--patra-section-gap)` (24px) above each section label. The profile picker and sign-in form use `var(--patra-gate-gutter)` (32px).
- Covers are always 2:3, with `var(--patra-radius-thumb)` on rows and tiles and `var(--patra-radius-cover)` in the hero. Row covers are 46x66 (80x115 on a tablet), hero covers 124x182 (160x235 on a tablet).
- Cards: `var(--patra-surface)` with a `var(--patra-border)` hairline and `var(--patra-radius-card)`. Bottom sheets: `var(--patra-surface)`, top corners `var(--patra-radius-card)`. Snack bars: `var(--patra-surface-hi)`, floating, `var(--patra-radius-cover)`, action in `var(--patra-accent)`.
- Tap targets are at least `var(--patra-min-hit-target)` (44px).
- **A button never scales with the screen**: it stops at `var(--patra-control-max-width)` (280px). A swipe pane is sized in points, never as a share of the row.
- A tablet (shortest side ≥ `tablet-breakpoint`) is answered three ways: a column of rows runs full width at the gutter with bigger covers and one step up the type scale; a grid of cards keeps its card size and adds columns; shelves and the reader run edge to edge.

## Progress, downloads and state

- **Reading progress on a cover is a 3px `var(--patra-accent)` bar pinned to its bottom edge**, over a 45% black track, drawn from the first page read and kept full once finished.
- **A download's own progress is a ring**, never a bar: a 24px ring in `var(--patra-offline)` (2px stroke on `var(--patra-track)`) around its glyph, beside a word in the state's colour (Save, Waiting, Preparing, Pause). A saved copy is a 32px `var(--patra-offline)` check in a 14% tinted disc, a mark rather than a button.
- **A batch's progress is a bar** (a proportion of a set): 2px, `var(--patra-offline)`, along the bottom of the batch card.
- **Read is marked, never erased**: a read row keeps `var(--patra-text)` for its title, wears a 2px `var(--patra-accent)` rail down its leading edge, and says "Read · 26 pages" in its metadata line.
- A row swipes both ways: the leading edge is progress (mark read or unread, `var(--patra-accent)`); the trailing edge is destruction (remove from the device, `var(--patra-danger)`).
- Offline, anything that needs the server disappears rather than failing: no save pill, no mark-read swipe, a batch card only when everything is already saved.
- While something loads, draw a skeleton shimmer (`var(--patra-surface)` to `var(--patra-surface-hi)`) in the shape of what is coming. A missing cover is drawn as the series' initial on a dark tone derived from the series, never grey.

## The reader

- Pictures (manga, comics) are read on `var(--patra-reader-canvas)` pure black; books on `var(--patra-book-canvas)`, the night blue, with the text in `var(--patra-text)` ivory whatever colours the book declares.
- The reader opens with no chrome. Its controls float over the page with `var(--patra-on-page-fill)` and `var(--patra-on-page-outline)`, a share of white that reads on any scan.
- How pages advance is one choice (left to right, right to left, vertical scroll), never split into a mode plus a direction.

## Voice

- Plain, short, and specific; say what a control does ("Download what's next", "Continue", "Remove"). A cost is always worded, never shown by an icon alone.
- Name things by the library's own vocabulary: a manga has chapters and volumes, a comic has issues ("Issue #12"), a book library has books. Never hardcode "chapter".
- Never write "LTR" or "RTL"; say "Left to right", "Right to left".
- English uses sentence case. French uses "vous", and Kavita's glossary: tome, chapitre, numéro (#12), hors-série, arc narratif.
- No emoji anywhere.

## Iconography

- Material Icons (the Flutter set), mostly rounded or outlined: `menu_book_rounded` for continue, `save_alt` to save, `check` for saved, `pause`, `delete_outline` to remove, `signal_cellular_alt` for mobile data, `download_done`, `chevron_right` on a row that opens something. 18px in rows, 20px in buttons, 22px in the navigation bar.
- Icons take the colour of what they mean (`var(--patra-accent)`, `var(--patra-offline)`, `var(--patra-danger)`) or `var(--patra-text-muted)`; never a colour of their own.
