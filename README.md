# Verso

A mobile client for [Kavita](https://www.kavitareader.com/), built with Flutter for iOS and Android.

*Verso* — the left-hand page of an open book, and a nod to the verse behind Kavita's name (कविता, "poem").

## Status

Early skeleton. What works:

- Login against a Kavita server (JWT, stored in the platform keychain)
- Library list
- Series grid with covers and read progress
- Volume/chapter list
- Basic image reader: horizontal paging, pinch-to-zoom, next-page preload, reading progress synced back to the server

## Roadmap

- [ ] Webtoon mode (continuous vertical scroll)
- [ ] Manga reading direction (right-to-left)
- [ ] EPUB reading (server-side rendered HTML in a WebView)
- [ ] Offline downloads
- [ ] Continue reading / on-deck on the home screen

## Development

```sh
flutter pub get
flutter run
```

Requires a running [Kavita](https://github.com/Kareadita/Kavita) server (v0.9+).

## Architecture

- `lib/src/api/` — thin hand-written client for the Kavita REST API
- `lib/src/auth/` — session state and secure storage
- `lib/src/features/` — one folder per screen (login, library, series, reader)
- State management: [Riverpod](https://riverpod.dev) · Routing: [go_router](https://pub.dev/packages/go_router)
