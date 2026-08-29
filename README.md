# Patra

A mobile client for [Kavita](https://www.kavitareader.com/), built with Flutter for iOS, iPadOS and Android.

*Patra* — the left-hand page of an open book, and a nod to the verse behind Kavita's name (कविता, "poem").

## Status

Usable, still young. What works:

- **Multiple servers** — sign in to several Kavita servers and switch between them in one tap; tokens live in the platform keychain, passwords are never stored
- **Home** — Continue reading, On deck, and your libraries
- **Library** — filter pills per library, 3-column cover grid with reading progress
- **Series** — volumes, chapters and specials as rows, with covers and per-chapter progress
- **Reader** — left-to-right, right-to-left (manga) or webtoon vertical scrolling; pinch to zoom, tap zones, thumbnail strip and slider, automatic two-page spread in landscape, progress synced back to the server
- **Offline** — save chapters to the device and read them with no server reachable
- English and French, following the system language

## Roadmap

- [ ] EPUB reading (Kavita renders book chapters to HTML server-side, so a styled WebView is enough)
- [ ] Search across libraries
- [ ] Reading lists and collections

## Install

**Android** — grab the `patra-debug-apk` artifact from the latest [Actions run](../../actions) on `main` and install it.

**iOS / iPadOS** — every push to `main` is signed and sent to **TestFlight**, so an invitation and the TestFlight app are all it takes; builds expire 90 days after upload. A fork, having no signing secrets, falls back to an unsigned `patra-unsigned-ipa` artifact, which has to be re-signed with your own Apple ID (AltStore or Sideloadly, from a Windows or Mac machine) — a free account's signature lasts 7 days.

## Development

```sh
flutter pub get
flutter run -d linux   # or a connected device
flutter analyze && flutter test
```

Requires a running [Kavita](https://github.com/Kareadita/Kavita) server (v0.9+).

## Architecture

- `lib/src/api/` — thin hand-written client for the Kavita REST API
- `lib/src/auth/` — remembered servers, session and token refresh
- `lib/src/downloads/` — offline page storage
- `lib/src/theme.dart` + `lib/src/widgets/` — design tokens and shared UI
- `lib/src/features/` — one folder per screen

State management: [Riverpod](https://riverpod.dev) · Routing: [go_router](https://pub.dev/packages/go_router) · HTTP: [dio](https://pub.dev/packages/dio)
