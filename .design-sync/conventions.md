# How to design with Patra

**Patra has no React components.** It is a Flutter app (iPhone, iPad, Android); `window.Patra` is empty on purpose. This system carries the brand: tokens, text styles, faces, guidelines and screenshots. Build every screen from plain elements styled with them, and follow `guidelines/components.md` to draw Patra's own pieces (the resume hero, chapter rows, the download pill, the batch card, buttons, section labels, setting rows) at the app's measurements.

## Setup

Link `styles.css` once; it brings the tokens, the text-style classes and the three bundled faces. Patra is dark only: paint the page yourself, or it renders on white.

```html
<link rel="stylesheet" href="styles.css">
<body style="margin:0; background: var(--patra-bg); color: var(--patra-text); font-family: var(--patra-font-sans);">
```

Design for a phone first (about 390pt wide), then a tablet.

## Styling idiom: CSS custom properties and a few classes

- Grounds: `--patra-bg` (page), `--patra-chrome` (app bar, bottom bar), `--patra-surface` (cards, sheets), `--patra-surface-hi` (raised off a surface), `--patra-border` (hairlines).
- Ink: `--patra-text`, `--patra-text-muted`, `--patra-text-on-art` (over pictures).
- Meaning: `--patra-accent` gold = reading progress and identity ONLY, with `--patra-on-accent` for text on it (never white); `--patra-offline` blue = downloads and offline ONLY; `--patra-danger` = destruction; `--patra-online` = the server dot. Never swap gold and blue.
- Faces: `--patra-font-sans` (Space Grotesk) for all interface text; `--patra-font-serif` (Literata) only for titles of works and page numerals; `--patra-font-legible` is a reading face for books.
- Space and shape: `--patra-gutter` (20px side margin), `--patra-section-gap` (24px), `--patra-radius-thumb` (covers on rows), `--patra-radius-cover` (buttons, hero covers, fields), `--patra-radius-card` (cards), `--patra-radius-pill`; `--patra-min-hit-target` (44px), `--patra-control-max-width` (280px: a button never grows past it).
- Text-style classes: `.patra-serif-title`, `.patra-app-bar-title`, `.patra-body`, `.patra-row-title`, `.patra-section-label`, `.patra-metadata`, `.patra-pill-label`, `.patra-nav-label`, `.patra-page-numeral`, `.patra-book-body`.
- Icons: Material Icons (the Flutter set), e.g. `menu_book` to continue, `save_alt` to save, `check` for saved; load the font from Google Fonts.

## Where the truth lives

Read `guidelines/brand.md` (the rules), `guidelines/components.md` (each piece, with sizes) and `guidelines/screens.md` (the screenshots in `guidelines/screens/`) before composing a screen. The mark is `guidelines/logos/patra-mark.svg` beside `patra-signature.svg`; never set it in a font.

## Example: a chapter row

```html
<div style="display:flex; align-items:center; gap:12px; padding:11px var(--patra-gutter); border-bottom:1px solid rgba(255,255,255,.06);">
  <div style="width:var(--patra-row-cover-width); height:var(--patra-row-cover-height); border-radius:var(--patra-radius-thumb); background:var(--patra-surface-hi);"></div>
  <div style="flex:1; min-width:0;">
    <div class="patra-row-title">Chapter 12 - The duel</div>
    <div class="patra-metadata" style="margin-top:3px;">Page 14 / 26</div>
    <div style="margin-top:7px; max-width:180px; height:2px; background:rgba(255,255,255,.07);"><div style="width:54%; height:100%; background:var(--patra-accent);"></div></div>
  </div>
  <span class="patra-pill-label" style="color:var(--patra-text-muted);">Save</span>
</div>
```
