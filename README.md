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

Releases are cut by a `v*` tag — `git tag v0.2.0 && git push origin v0.2.0`, or publishing a GitHub release that creates that tag; no commit needed: the tag is what names the version, and the app reads that name back off its own binary. A push to `main` between releases only compiles and tests, and leaves a sideloadable artifact.

**Android** — a tag builds a signed **App Bundle** and, once a Play service account is configured, sends it to the internal test track on Google Play. Without the signing secrets — a fork, or this repository before the Play account existed — the job falls back to the `patra-debug-apk` artifact on the latest [Actions run](../../actions), which installs by sideloading.

**iOS / iPadOS** — a tag is signed and sent to **TestFlight**, so an invitation and the TestFlight app are all it takes; builds expire 90 days after upload. A fork, having no signing secrets, falls back to an unsigned `patra-unsigned-ipa` artifact, which has to be re-signed with your own Apple ID (AltStore or Sideloadly, from a Windows or Mac machine) — a free account's signature lasts 7 days.

## Development

```sh
flutter pub get
flutter run -d linux   # or a connected device
flutter analyze && flutter test
```

Requires a running [Kavita](https://github.com/Kareadita/Kavita) server (v0.9+),
reachable over `https://` or, for a server on your own network, `http://`.

## Architecture

- `lib/src/api/` — thin hand-written client for the Kavita REST API
- `lib/src/auth/` — remembered servers, session and token refresh
- `lib/src/downloads/` — offline page storage
- `lib/src/theme.dart` + `lib/src/widgets/` — design tokens and shared UI
- `lib/src/features/` — one folder per screen

State management: [Riverpod](https://riverpod.dev) · Routing: [go_router](https://pub.dev/packages/go_router) · HTTP: [dio](https://pub.dev/packages/dio)
