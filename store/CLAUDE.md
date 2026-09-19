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

- it **clears the app's data** first, so the run starts from the sign-in form rather than from whoever was reading last;
- it **refuses a screen that is not 9:16** — Play's recommended size is 1080×1920, Apple's is 1320×2868 for a 6.9" iPhone and 2064×2752 for a 13" iPad, and no phone ships with any of them. On an emulator: `adb shell wm size 1080x1920`;
- it **flattens** what comes out, because both stores refuse an alpha channel.

**The recipe has never been run.** It type-checks against the SDK's own `integration_test` API and every finder in it is either an icon or a string read out of `AppLocalizations`, so it should fail loudly and not silently — but the first run will also be the first debug, and the steps that reach the profile picker, the reader's chrome and the swiped row are the ones to watch. Nothing here is proven until a real run writes real files.

**What may be in the pictures is a rights question, not a design one.** A store screenshot is a publication: MangaDex covers, a publisher's page scans and Kavita's own demo library are all somebody else's, and a listing that shows them is showing what the app was pointed at, not what it is. Point the recipe at a library whose contents are the user's own or already free.

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