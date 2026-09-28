# design-sync notes

- **Patra is Flutter, so this is a tokens-only design system.** `.design-sync/brand/` is a tiny hand-made package (`index.js` exports nothing) that carries the brand for Claude Design: `tokens.css` (CSS custom properties and text-style classes), `fonts.css` (the three bundled faces, read from `assets/fonts/`), and three guideline files. The converter reports `[ZERO_MATCH]` and treats it as tokens-only; that is expected.
- **`tokens.css` is a hand copy of `lib/src/theme.dart`.** Nothing generates it. When a colour, radius, spacing or text style changes in `theme.dart`, change it here too, and the numbers quoted in `brand.md` and `components.md`.
- **The logo and the screenshots are added to `ds-bundle/guidelines/` by hand after every build**, because `guidelinesGlob` copies Markdown only: `site/assets/img/patra-mark.svg`, `patra-signature.svg`, `assets/icon/patra-1024.png` into `guidelines/logos/`, and the screenshots into `guidelines/screens/`. **The screenshots are not in the repository** (they show a real library, with the profile photo and server address painted over), so a re-sync that does not put them back will delete them from the project in its reconciliation pass.
- **The Design System pane shows only preview cards, and a tokens-only build makes none**: uploaded as is, the project looked empty. The twelve cards (Colors, Typography, SpacingAndRadii, Logo, the seven pieces, Screens) live in `.design-sync/brand/cards/` with their shared `cards.css`; copy that folder to `ds-bundle/components/` after every build. They are static HTML linking `../../../styles.css`, one `<!-- @dsCard group=… -->` marker each.
- Build: `node .ds-sync/resync.mjs --config .design-sync/config.json --node-modules .ds-sync/node_modules --out ./ds-bundle --entry ./.design-sync/brand/index.js --no-render-check`. Converter deps live in `.ds-sync/` (`esbuild ts-morph @types/react react@18 react-dom@18`), never in the Flutter project.
- The render check is skipped (`--no-render-check`): there are no component previews to render, and Playwright is not installed here.

## Re-sync risks

- `tokens.css` and the guidelines drift silently from `theme.dart` and the widgets; nothing checks them against the Dart.
- The screenshots date from 2026-09-28 and go stale as screens change.
- The preview cards are hand-written HTML: when a widget changes in the app, its card and `components.md` change with it.
- The anchor (`_ds_sync.json`) was written before the cards were added, so it does not cover them; the next sync re-uploads them.
- `components.md` describes seven Flutter widgets in words; Claude Design redraws them, so its versions can differ from the app's.
