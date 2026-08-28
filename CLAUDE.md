# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Verso is a Flutter mobile client (iOS + Android) for [Kavita](https://www.kavitareader.com/), a self-hosted manga/comics/book server. Early stage: login, library browsing, series grid, and a basic image reader work; webtoon mode, RTL manga direction, EPUB reading, and offline downloads are on the roadmap (see README.md).

## Commands

```sh
flutter pub get          # install dependencies
flutter analyze          # lint — must stay at zero issues
flutter test             # run all tests (none exist yet)
flutter test test/x_test.dart   # run a single test file
flutter run              # launch on a connected device/emulator
```

On this dev machine the Flutter SDK lives in `~/development/flutter` (PATH set in `~/.zshrc`); in non-interactive shells use `export PATH="$HOME/development/flutter/bin:$PATH"` first. Android SDK is at `~/Android/Sdk`. The app targets iOS + Android, but Linux desktop support is enabled purely as a fast local dev target (`flutter run -d linux`). iOS builds only happen in CI (`.github/workflows/build.yml`) as **unsigned** binaries (`--no-codesign`; signing/TestFlight comes later, no Apple Developer account is configured).

## Architecture

State: Riverpod. Routing: go_router. HTTP: dio. Structure: `lib/src/api/` (Kavita client + DTOs), `lib/src/auth/` (session), `lib/src/features/<screen>/` (one folder per screen, each screen declares its own Riverpod providers at the top of its file).

### Kavita API client — deliberately hand-written

Kavita's OpenAPI spec has ~500 endpoints; we do NOT generate a client. `lib/src/api/kavita_client.dart` wraps only the endpoints the app uses. When adding an endpoint, verify its path, parameters, and DTO shape against the spec first (`openapi.json` in the [Kavita repo](https://github.com/Kareadita/Kavita), `develop` branch) — do not code it from memory. DTO parsing in `models.dart` is defensive (`?? defaults`) because Kavita omits null fields; keep new DTOs minimal, mapping only the fields actually used.

Non-obvious API facts already encoded in the client:
- Series listing is `POST /api/Series/all-v2` with a filter body of magic enums: `field: 19` = Libraries, `comparison: 5` = Contains, `combination: 1` = And. Enum values come from the OpenAPI spec (`SeriesFilterField`, `FilterComparison`).
- Two auth mechanisms coexist: JWT Bearer header for regular calls, and the user's `apiKey` as a query param for image URLs. Image widgets get both (`client.imageHeaders` + apiKey in the URL) because they can't always send headers.

### Session flow

`main()` loads the session from `flutter_secure_storage` **before** `runApp`, then injects it by overriding `initialSessionProvider` in the `ProviderScope`. `sessionProvider` (auth state) feeds both `kavitaClientProvider` — which throws if no session, safe because the router guards — and the go_router `redirect` in `app.dart`, which bounces logged-out users to `/login`. Router refresh on auth change goes through a `ValueNotifier` bumped by `ref.listen`.

### Localization

The app is localized (English = template/fallback, French). Never hardcode user-facing strings: add the key to both `lib/l10n/app_en.arb` and `lib/l10n/app_fr.arb`, run `flutter gen-l10n` (also runs automatically on build/test), and use `AppLocalizations.of(context)` (import `lib/l10n/generated/app_localizations.dart`; the getter is non-nullable, configured in `l10n.yaml`). Generated files are committed. Widget tests run under the `en` locale.

### Navigation

Routes are declared flat (not nested) in `app.dart`, so with go_router: use `context.push()` to drill down (library → series → chapter → reader) — it stacks the screen, giving the AppBar back arrow and correct Android back-button behavior. `context.go()` replaces the whole stack and must only be used for section switches with no "back" (login/logout redirects). Using `go` for drill-down makes the system back button exit the app.

### Reader

`reader_screen.dart` posts reading progress to the server fire-and-forget on every page turn and precaches the next page. Progress needs `libraryId`/`seriesId`/`volumeId`, all obtained from `GET /api/Reader/chapter-info` — routes only carry the `chapterId`.
