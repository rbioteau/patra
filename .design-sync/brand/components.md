# Patra components

Patra is a Flutter app, so none of these ships as a React component. When a design needs one, build it from these specifications with the tokens and classes in `styles.css`; the measurements are the app's own.

## SeriesHero

The top of a series screen and the Continue card on Home: the cover of the chapter it resumes, the title, who made it, how much of it there is, and one button back to where the reader left off.

- Padding: 12px top, `var(--patra-gutter)` sides and bottom. Cover 124x182 (160x235 on a tablet), `var(--patra-radius-cover)`, with the 3px `var(--patra-accent)` reading bar at its foot for the thing pictured; 16px to the words.
- Title in `.patra-serif-title` (21px, 25px on a tablet), then two `.patra-metadata` lines at 12px (authors; the tally of volumes and chapters), 6px apart, then the button at the foot.
- The button is the hero Button: `menu_book_rounded` and one word (Continue / Start reading / Read again), 44px, at most `var(--patra-control-max-width)`.
- While a chapter is under way, a blurred page of it sits behind the hero and the secondary text switches to `var(--patra-text-on-art)`.
- Home adds nothing above it: no eyebrow label. Home's card also opens the series from its cover and title.

Source: `lib/src/widgets/series_hero.dart`.

## ChapterRow

One chapter, volume, issue or book in a series' list: cover, title, a metadata line, and the download pill at the trailing edge.

- Cover 46x66 (80x115 on a tablet), `var(--patra-radius-thumb)`, with a 3px 35% black spine shadow on its leading edge; 12px to the text, 12px to the pill. Row padding 11px (14px on a tablet), a 6% white hairline under it.
- Title in `.patra-row-title` (13.5px, 15px on a tablet), two lines at most, named in the library's vocabulary (Chapter 12 - The duel, Issue #12, Volume 3).
- **In progress**: metadata "Page 14 / 26" and a 2px `var(--patra-accent)` track (on 7% white) at most 180px wide. The chapter the reader is in sits in a "Reading now" group, its title in `var(--patra-accent)` and the row faintly tinted.
- **Read**: the title stays `var(--patra-text)`; a 2px `var(--patra-accent)` rail runs down the row's leading edge (at the screen edge) and the metadata says "Read · 26 pages".
- Swipe from the leading edge to mark read or unread (`var(--patra-accent)`), from the trailing edge to remove what is on the device (`var(--patra-danger)`). The row is squeezed by the pane, never slid off the screen.

Source: `lib/src/features/series/series_detail_screen.dart` (`_ChapterRow`), `lib/src/widgets/read_mark.dart`.

## DownloadPill

The control at the trailing end of a chapter row that saves the chapter for offline reading, shows its download as a ring, and marks it once saved.

- **Not saved**: `save_alt` (14px) and the word Save in `.patra-pill-label`, both `var(--patra-text-muted)`.
- **On its way**: a 24px ring (2px stroke, `var(--patra-offline)` on `var(--patra-track)`) around a 12px pause glyph, and the word for the moment it is in: Waiting, Preparing, Downloading. Tapping pauses it. The ring shows the pages already fetched even while waiting; it only spins while the page count is unknown.
- **Stopped**: the ring stays where it stopped; the word is the tap (Resume, or Retry in `var(--patra-danger)` after a failure).
- **Saved**: a 32px disc of `var(--patra-offline)` at 14% with a 16px `var(--patra-offline)` check. A mark, not a button; its tooltip says Saved.
- No box or outline around the pill: the tap area is 8px either side and 4px above and below, and the coloured word is what says "control".
- A download's own progress is always a ring; a bar on a cover is reading progress.
- Offline, the Save state is not drawn at all.

Source: `lib/src/widgets/download_pill.dart`.

## BatchCard

The card under a series' hero that saves the next few unread chapters in one tap, then reports on them.

- A full-width row at the gutter: `var(--patra-surface)`, 8% white border, `var(--patra-radius-card)`, 12px/14px padding; a 32px circle (1.5px border) holding a 16px glyph, 12px to a title in `.patra-row-title` at 13px and a `.patra-metadata` subtitle.
- **Offer**: "Download what's next" in `var(--patra-text)`; the subtitle names the run ("Chapters 13 to 15", "Chapter 7 – Omake") and what is already on the device. The title never carries the number: how many is a setting (3, 5, 10 or 20).
- **Running**: tinted `var(--patra-offline)` at 7%, border `var(--patra-offline)` at 45%, title and glyph in `var(--patra-offline)`, and a 2px `var(--patra-offline)` bar along the bottom. A batch's progress is a bar because it is a share of a set.
- **All saved**: tinted 10%, a check, "Next 3 saved · Ready to read offline". Offline, the card is drawn only in this state.
- Not drawn when a single chapter is left: that is the row's own pill's job.
- On mobile data the tap first asks "You're on mobile data" before anything is fetched.

Source: `lib/src/features/series/series_detail_screen.dart` (`_BatchCard`).

## Button

The app's buttons: one gold filled button per screen for the main act, outlined for secondary acts, text buttons for small inline answers.

- **Filled** (`FilledButton`): `var(--patra-accent)` fill, `var(--patra-on-accent)` label in `button` (14px, 600), `var(--patra-radius-cover)`, 48px tall. Reserved for the act that moves reading forward or gets the reader in (Sign in, Continue, Start reading).
- **Hero** variant: 44px tall, 12px side padding, a 20px `menu_book_rounded` icon before one word (Continue / Start reading / Read again). It never names the chapter; the row under it does.
- **Outlined** (`OutlinedButton`): transparent, `var(--patra-text)` label, 1px `var(--patra-border)`, 44px tall, `var(--patra-radius-cover)`.
- **Text**: the label alone in `var(--patra-accent)`, for Show / Hide folds and snack bar actions.
- Never wider than `var(--patra-control-max-width)` (280px), whatever the screen: a button given a whole hero to fill stops reading as a button.
- Destructive confirmations put the word in `var(--patra-danger)` on a text button; there is no red filled button.

Source: `lib/src/theme.dart` (`patraTheme`), `lib/src/widgets/series_hero.dart`.

## SectionLabel

The header over a section of a screen: uppercase, tracked, quiet.

- `.patra-section-label`: 12px, weight 500, letter-spacing 1.5px, uppercased, in `var(--patra-text-muted)`. `var(--patra-section-gap)` (24px) above it.
- On the Downloads tab it may take `var(--patra-offline)` (sections about the offline store) or `var(--patra-danger)` (what stopped). Never `var(--patra-accent)`: a heading is not progress.
- An optional trailing control sits at its end, such as a worded Show / Hide (never a chevron alone) or the sort button.
- A group inside a section (a volume over its chapters, other profiles in Settings) is a sub-header in sentence case in `.patra-row-title`'s muted form, not another SectionLabel.

Source: `lib/src/theme.dart` (`SectionLabel`).

## SettingSwitch

A setting that is simply on or off, with a line saying what turning it on changes.

- The whole row is the control, at least 44px tall, `var(--patra-gutter)` padding at the sides and 12px above and below; one element to a screen reader.
- An 18px icon in a 22px column, 14px to the text: title in `.patra-body`, a `.patra-metadata` caption under it, then the switch 8px after.
- The icon takes the colour of its subject: `var(--patra-offline)` for anything about downloads, `var(--patra-accent)` for the profile and its lock.
- The caption is not decoration: it says what the switch changes, and what it does not.
- A setting with more than two values is a row with its value in `var(--patra-accent)` and a chevron, opening a bottom sheet of options.

Source: `lib/src/features/settings/settings_screen.dart` (`_SwitchRow`).
