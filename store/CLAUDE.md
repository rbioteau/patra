# What the two store listings take

*Loaded when work touches `store/`. The entry point is still the root `CLAUDE.md`.*

Everything the consoles demand as an image, and how each one is made. Three kinds, and only one of them is a file anybody draws:

**The icon.** Play wants its own 512×512, 32-bit PNG **with** alpha, under 1 MB; the App Store takes the icon out of the build and has nothing to upload. Both come from the one master, `assets/icon/patra-1024.png`:

```sh
convert assets/icon/patra-1024.png -resize 512x512 -strip PNG32:store/icon-512.png
```

**The feature graphic.** Play refuses to publish a listing without one: **1024×500**, JPEG or 24-bit PNG **no alpha**. `store/feature-graphic.html` is its source — open it in a browser at exactly that size, screenshot, and flatten:

```sh
convert shot.png -alpha remove -alpha off -strip PNG24:store/feature-graphic-1024x500.png
```

It is drawn on **ivory**, not on the night blue every other surface of this project uses, and that is Play's rule rather than a change of mind: Google asks for a background that is not pure white, black **or dark grey**, because that is what its own store is, and a night-blue band sinks into it. The mark, the wordmark and the tagline keep the brand; the paper is turned over for the one place the brand is seen inside somebody else's shop.

**The screenshots.** Generated, never taken by hand — `tool/store_screenshots.sh` runs `integration_test/store_screenshots_test.dart` through `flutter drive`, with `test_driver/store_screenshots.dart` writing the files:

```sh
KAVITA_URL=https://kavita.example KAVITA_USER=roman KAVITA_PASSWORD=… \
  ./tool/store_screenshots.sh --locale fr
```

What the script is for, and why each of its steps is there:

- it **uninstalls the app** first, so the run starts from the sign-in form rather than from whoever was reading last. Uninstalled, and not `pm clear`ed: clearing needs a permission `adb shell` does not have on a device that is not rooted, and it fails with a `SecurityException` — a step that quietly does nothing is how a recipe ends up photographing the profiles somebody left behind. **The cost is real and worth saying before the run**: a build installed from a store is gone from that device, and what comes back is the debug build this run makes;
- it **refuses a screen that is not 9:16** — Play's recommended size is 1080×1920, Apple's is 1320×2868 for a 6.9" iPhone and 2064×2752 for a 13" iPad, and no phone ships with any of them. On an emulator: `adb shell wm size 1080x1920`;
- it **flattens** what comes out, because both stores refuse an alpha channel.

## Where the screenshots' content comes from

A store screenshot is a publication: MangaDex covers, a publisher's page scans and Kavita's own demo library are all somebody else's, and a listing that shows them shows what the app was pointed at rather than what the app is. There are two ways out, and they are not exclusive.

**A library that is yours or already free** — Standard Ebooks for books, public-domain comics for pages — pointed at with `KAVITA_URL` like any server.

**The demo, which needs no library at all.** `tool/gen_demo_library.sh` draws four covers, six pages and an avatar in the app's own palette and face, and `tool/demo_server.dart` serves them as a Kavita server:

```sh
./tool/gen_demo_library.sh
dart run tool/demo_server.dart          # http://localhost:5000, any password
adb reverse tcp:5000 tcp:5000           # the phone then reaches it itself

KAVITA_URL=http://127.0.0.1:5000 KAVITA_USER=roman KAVITA_PASSWORD=demo \
  ./tool/store_screenshots.sh --locale en
```

Every pixel is then ours and the app is none the wiser: the stores get a picture of the *app*, which is what they ask for, over content that belongs to nobody. **`127.0.0.1`, not `localhost`** — `adb reverse` forwards IPv4 only, and a phone that resolves `localhost` to `::1` gets a connection refused whose message reads like a server that is down.

The demo is a `tool/`, so it is not in the app, not in a bundle, and not behind a flag anybody could turn on in production: a fake-content mode *inside* the app would be a second way for every screen to draw, and this is not. Its routes are the shapes `lib/src/api/models.dart` reads, taken from `docs/openapi/kavita-openapi-0.9.0.0.json` — pinned in this repository — and a route it does not know is a 404, so a screen that starts calling a new endpoint fails loudly on the next run instead of looking subtly wrong. It logs every request: that log is the first thing to read when a screen comes out wrong, and it is what showed that the app reached the reader and that the download never started.

## Where the run stands

**It has been run — about ten times, on a real phone, against the demo — and it is not finished.** It signs in, forces the language, reaches the profile picker, opens a series, marks a chapter read, opens the reader, and writes screenshots: `1-home.png` and `2-profiles.png` came out real.

One step is still broken, and it is the reason a run does not get to the end: **a tap on a bottom-bar destination is not delivered when the test synthesises it.** `adb shell input tap` at the same point switches tab; `tester.tapAt` and `tester.tap` at that same point are refused — the framework reports the point as not hit-testing the widget, as a warning rather than a failure, so the run carries on and dies two screens later. Until that is understood the last three screens are not photographed, and the language step is dead in the water because it is reached through that bar.

Everything the first runs taught is in the recipe as comments where it bit: the sign-in form is submitted through the keyboard's *done* (the soft keyboard covers the button), the profile face is a `ProfileAvatar` and not a Material icon, a saved copy is a **check**, not the word "Saved" (that is only its tooltip), `pumpAndSettle` never returns on a screen that is loading, and every navigation waits for the thing it navigated to.

**Where the files go, and why they are committed.** `store/screenshots/<locale>/` — one directory per listing, since the recipe forces the language before its first shot, and the numbering is the upload order: the two stores show screenshots in the order they were given, and `1-home.png` sorts where it belongs. They are committed like the generated app icons, because what a store is showing is a thing the repository should answer for when it changes.

## The check a run has to pass

Both stores take the time to name their sizes; nobody rereads them. So the shapes are checked where they are produced rather than trusted:

| | |
|---|---|
| Play — icon | 512×512, PNG with alpha chosen and the *channel* kept, ≤ 1 MB |
| Play — feature graphic | 1024×500, no alpha |
| Play — screenshots | 2 to publish, 4 at ≥ 1080 px in 9:16 for the large formats |
| App Store | 6.9" iPhone (1320×2868) **and** 13" iPad (2064×2752), because the app runs on iPad; no alpha, 1–10 of them |
| Both | alt text on every asset Play is given |