# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Verso is a Flutter mobile client (iOS + iPadOS + Android) for [Kavita](https://www.kavitareader.com/), a self-hosted manga/comics/book server. Login (multi-server), home shelves, library grid, series detail, an image reader with three reading directions, and offline downloads work. EPUB reading is still on the roadmap (see README.md).

## Commands

```sh
flutter pub get          # install dependencies
flutter analyze          # lint — must stay at zero issues
flutter test             # run all tests
flutter test test/x_test.dart   # run a single test file
flutter run -d linux     # fastest local run
```

On this dev machine the Flutter SDK lives in `~/development/flutter` (PATH set in `~/.zshrc`); in non-interactive shells use `export PATH="$HOME/development/flutter/bin:$PATH"` first. Android SDK is at `~/Android/Sdk`. The app targets iOS + Android; Linux desktop is enabled purely as a fast local dev target. `compileSdk` is pinned to 37 in `android/app/build.gradle.kts` because `flutter_secure_storage` requires it. iOS builds only happen in CI (`.github/workflows/build.yml`) as **unsigned** binaries; the IPA artifact is meant to be re-signed and sideloaded (AltStore/Sideloadly) until an Apple Developer account exists. CI publishes installable artifacts only on push to `main`, never from a pull request.

## Design system — the handoff is the source of truth

This UI implements a Claude Design handoff kept at `.claude/design/HANDOFF.md` — **untracked on purpose**, so it is there on this machine and absent from a fresh clone. Read it before changing anything visual; where it is missing, `lib/src/theme.dart` and the notes below are the reference. `lib/src/theme.dart` holds every token (colors, radii, spacing, type scale) plus shared primitives (`SectionLabel`, `CoverProgressBar`, `Skeleton`); shared widgets live in `lib/src/widgets/`. Never hardcode a color or a radius in a screen.

Two hard rules from the handoff:
- **`versoAccent` (purple) = reading progress and identity. `versoOffline` (teal) = downloads and offline. Never swap them.**
- Serif (`VersoText.serifTitle`, Source Serif 4) is only for titles of works, the wordmark, and reader page numerals. Everything else is Space Grotesk.

App icons come from `assets/icon/verso-1024.png` (the master mark) and `assets/icon/verso-adaptive-foreground.png` (the Android adaptive foreground). `dart run flutter_launcher_icons` regenerates the iOS set and the legacy Android mipmaps; its config is at the bottom of `pubspec.yaml`, and iOS icons must stay opaque (`remove_alpha_ios`).

The **launch screen** is themed to the ink so there is no flash of white before Flutter's first frame: `values*/styles.xml` paint `@color/verso_ink`, and on Android 12+ (`values-v31`, plus `values-night-v31` because the night qualifier outranks the API one) the system splash is pointed at `@drawable/verso_mark` — a **vector** copy of the mark. Left to itself Android 12+ composites the *adaptive* icon, ink tile included, over the theme background, which is the mismatched square, and upscales a bitmap. iOS mirrors this: `LaunchScreen.storyboard` paints the same ink and centres `LaunchImage`.

The Android **adaptive** icon is deliberately *not* generator-managed: its foreground is `drawable/verso_mark.xml`, the same vector the splash screen uses, so the launcher icon and the splash cannot drift apart and neither can pixelate. `flutter_launcher_icons` only rasterises PNG foregrounds and would rewrite `mipmap-anydpi-v26/ic_launcher.xml` with a 16% inset that double-pads a vector already carrying its own padding — so it keeps no `adaptive_icon_*` keys, and running it leaves the adaptive icon and `values/colors.xml` (`verso_ink` = `#16141C`) untouched. Only 66dp of the 108dp canvas is guaranteed visible, which is why the mark sits at ~48% of the viewport width in that vector; change it there and both the icon and the splash follow. `drawable/verso_mark_mono.xml` is the Android 13+ themed variant: same geometry, one colour, and the parchment fade carried by `fillAlpha` — the system ignores the colour but honours alpha. Its floor is raised to ~0.2 because a fainter tinted line disappears on some wallpapers. Regenerate the two vectors together.

The app ships a single dark theme (`themeMode: ThemeMode.dark`): the reader canvas is pure black and the whole chrome is built around it.

## Architecture

State: Riverpod 3. Routing: go_router. HTTP: dio. Layout: `lib/src/api/` (Kavita client + DTOs), `lib/src/auth/` (servers/session), `lib/src/downloads/` (offline storage), `lib/src/settings/`, `lib/src/widgets/` (shared UI), `lib/src/features/<screen>/` (one folder per screen, each declaring its own providers at the top of its file).

### Kavita API client — deliberately hand-written

Kavita's OpenAPI spec has ~500 endpoints; we do NOT generate a client. `lib/src/api/kavita_client.dart` wraps only the endpoints the app uses. When adding an endpoint, verify its path, parameters, and DTO shape against the spec first (`openapi.json` in the [Kavita repo](https://github.com/Kareadita/Kavita), `develop` branch) — do not code it from memory. DTO parsing in `models.dart` is defensive (`?? defaults`) because Kavita omits null fields; keep new DTOs minimal, mapping only the fields actually used.

Non-obvious API facts already encoded in the client:
- Series listing is `POST /api/Series/all-v2` with a filter body of magic enums: `field: 19` = Libraries, `comparison: 5` = Contains, `combination: 1` = And. Enum values come from the OpenAPI spec (`SeriesFilterField`, `FilterComparison`).
- That endpoint silently caps results at the page size, so `allSeriesForLibrary` pages until a short page comes back. A single call would truncate a library at 100 series.
- Two auth mechanisms coexist: JWT Bearer header for regular calls, and the user's `apiKey` as a query param for image URLs. Image widgets get both (`client.imageHeaders` + apiKey in the URL) because they can't always send headers.
- **Kavita sentinel numbers leak through the API**: a volume with `minNumber == -100000` holds chapters that belong to no volume, `-100001` holds specials, and a chapter with `minNumber == -100000` is the placeholder for a volume with no chapter breakdown. `VolumeDto.isLooseLeaf` / `isSpecials` / `ChapterDto.isVolumePlaceholder` exist so these never reach the UI as "-100000". Covered by `test/models_test.dart`.
- `GET /api/Reader/chapter-info` returns `pageDimensions`, which the webtoon view uses to lay pages out (and so keep the slider in sync) before any image has loaded.

### Auth: several servers, one active session

`ServerEntry` is a remembered server (`baseUrl`, `username`, and its tokens — **never a password**); an empty `token` means "remembered but signed out". `AuthState` is the list plus `activeUrl`, and `AuthState.active` is non-null only when the active entry still has tokens. `main()` loads it from `flutter_secure_storage` **before** `runApp` and injects it via `initialAuthStateProvider`; `SessionStorage.load()` still migrates the old single-server key layout.

Mutate auth through `authProvider.notifier` (`login`, `resume`, `signOut`, `switchServer`, `forget`, `updateTokens`); read the current session through `sessionProvider`. `signOut` keeps the entry but drops its tokens (a password is needed again), `switchServer` keeps the tokens so returning is one tap. Covered by `test/auth_test.dart`.

`kavitaClientProvider` watches only the session's *identity* (`baseUrl`, `apiKey`), not its tokens: the client patches its own tokens on refresh, so rebuilding it there would invalidate every data provider mid-read. It also keeps the previous client alive across a logout, because screens can rebuild once more while the router redirects. The client refreshes an expired JWT on a 401 and retries the request; a failure of the *retried* request is not a session failure — keep those two error domains separate (`test/kavita_client_test.dart`).

### Navigation

Four tabs (Home / Library / Downloads / Settings) via `StatefulShellRoute.indexedStack`; `/series/:id` and `/reader/:chapterId` are declared **outside** the shell so they are full-screen. Use `context.push()` to drill down — it stacks the screen, giving the AppBar back arrow and correct Android back-button behavior — and `context.go()` only for switching branch or for login/logout redirects. Using `go` for drill-down makes the system back button exit the app.

The bottom bar **measures its labels before showing them** (`_VersoShell._labelsFit`): French labels are much longer than English ones and a large system font makes any of them overflow the bar, so when they do not fit in their share of the width the bar falls back to icons plus tooltips. Keep `VersoText.navLabel` as the single definition of that style — the theme and the measurement must agree, or the check is meaningless.

Reading changes progress on the server, so a screen that pushed the reader invalidates its own provider when the push returns.

### Downloads and offline

`DownloadsService` stores pages under `<documents>/downloads/<chapterId>/`, one extension-less file per page, and writes `meta.json` **last** — a chapter directory without one is a partial download and gets deleted on the next `scan()`. Keep that invariant. `DownloadsNotifier` owns per-chapter `CancelToken`s; a cancelled or failed download leaves nothing behind. Covered by `test/downloads_service_test.dart` (pass `DownloadsService(root:)` a temp dir).

Two stores must not be confused. **Saved chapters** live in the documents directory, are chosen by the user and are never evicted; their total is what the Downloads tab reports. The **image cache** is `cached_network_image`'s own store in the system cache directory, holding covers and pages merely browsed online — it grows on its own (it outgrew the downloads three to one on a real device) and the OS may reclaim it. `ImageCacheStore` exposes its size and clears it from Settings; clearing it must never touch the documents directory.

Progress is mirrored into each saved chapter's `meta.json` (`recordProgress`), because the Downloads tab has to show it with no server; the series screen resyncs it from the server, which stays the authority. A chapter opened from the Downloads tab must be opened at its stored page — opening at 0 posts that back and wipes the reader's place.

`offlineProvider` flips to true when a request fails to *reach* the server (dio connection/timeout errors) and back on the next success. Offline, unsaved chapters are dimmed and non-tappable, and the reader falls back to the stored `SavedChapter` metadata so a saved chapter reads with no server at all.

### Reader

One setting decides everything: `ReadingDirection` is left-to-right, right-to-left, or webtoon — webtoon is a *direction*, not a separate mode, and there is a single control for it. Never write "LTR"/"RTL" in UI copy; use the full localized phrases.

- Paged: tap zones are 30/40/30 (sides page, centre toggles chrome); right-to-left mirrors `reverse`, the tap meanings, the thumbnail strip and the slider together (via `Directionality`) while page numerals stay left-to-right.
- Landscape (paged only) becomes a two-page spread advancing by two, first page of the pair leading per direction.
- Progress posts are serialized through a queue so a slow save cannot regress a later page, and the **last page reports `pages`, not `pages - 1`** — Kavita only marks a chapter read when `pagesRead >= pages`. The initial page is saved on open, since `onPageChanged` never fires for it.

### Localization

The app is localized (English = template/fallback, French). Never hardcode user-facing strings: add the key to both `lib/l10n/app_en.arb` and `lib/l10n/app_fr.arb`, run `flutter gen-l10n` (also runs automatically on build/test), and use `AppLocalizations.of(context)` (import `lib/l10n/generated/app_localizations.dart`; the getter is non-nullable, configured in `l10n.yaml`). Generated files are committed. Widget tests run under the `en` locale — note `SectionLabel` uppercases its text, so tests match `'CONTINUE'`, not `'Continue'`.
