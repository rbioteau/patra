# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Patra is a Flutter mobile client (iOS + iPadOS + Android) for [Kavita](https://www.kavitareader.com/), a self-hosted manga/comics/book server. Login (multi-server), home shelves, library grid, series detail, an image reader with three reading directions, and offline downloads work. EPUB reading is still on the roadmap (see README.md).

## Commands

```sh
flutter pub get          # install dependencies
flutter analyze          # lint — must stay at zero issues
flutter test             # run all tests
flutter test test/x_test.dart   # run a single test file
flutter run -d linux     # fastest local run
```

On this dev machine the Flutter SDK lives in `~/development/flutter` (PATH set in `~/.zshrc`); in non-interactive shells use `export PATH="$HOME/development/flutter/bin:$PATH"` first. Android SDK is at `~/Android/Sdk`. The app targets iOS + Android; Linux desktop is enabled purely as a fast local dev target. `compileSdk` is pinned to 37 in `android/app/build.gradle.kts` because `flutter_secure_storage` requires it. iOS builds only happen in CI (`.github/workflows/build.yml`); there is no Mac here, and nothing about iOS can be reproduced locally. CI leaves a sideloadable artifact for a push to `main`, never for a pull request; what reaches a **store** is only ever a tag.

**Releases are cut by a tag, not by a push**, and the tag *is* the version — it is passed to `--build-name`, so a shipped binary cannot disagree with the tag it was built from. Three prohibitions that cost a wasted release each:

- Cutting a release is `git tag v0.2.0 && git push origin v0.2.0` and nothing else — no commit, nothing in the repository to bump.
- Push the **one** tag by name, never `--tags`: GitHub creates no event at all for a push carrying more than three tags, so a backlog of local tags ships nothing and says nothing.
- Never use GitHub's own **re-run** to recover a half-failed release: it keeps its run number, which both stores reject as one they have already seen. `gh workflow run build.yml --ref v0.2.0` is the recovery hatch.

The whole of what CI then does — the tag's accepted shape, `github.run_number` as the build number, the signed and unsigned paths of both platform jobs, the Play internal track, and every signing secret — is in the **`.github/CLAUDE.md`**, which loads whenever the workflow itself is touched. Read it before touching `.github/workflows/build.yml`, signing, or store upload.

## Agent skills

### Issue tracker

Issues live as GitHub issues in `rbioteau/patra`, driven through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles, each label string equal to its name (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Design system — the handoff is the source of truth

This UI implements a Claude Design handoff kept at `.claude/design/HANDOFF.md` — **untracked on purpose**, so it is there on this machine and absent from a fresh clone. Read it before changing anything visual — **except its §3 and §5**. §3 still says the reader's top bar carries a single reading-direction pill and "NO separate mode/direction toggles"; the rule against splitting *how pages advance* into a mode plus a direction still stands, but the pill itself is now a cog (see `lib/src/features/reader/CLAUDE.md`). §5 still describes the retired "unfinished page" mark and is superseded by `.claude/design/icons/README.md` (the frond), by the icon notes in the `patra-design` skill and by `lib/src/features/launch/CLAUDE.md`; where it is missing, `lib/src/theme.dart` and the notes below are the reference. `lib/src/theme.dart` holds every token (colors, radii, spacing, type scale) plus shared primitives (`SectionLabel`, `CoverProgressBar`, `Skeleton`); shared widgets live in `lib/src/widgets/`. Never hardcode a color or a radius in a screen.

Two hard rules from the handoff:
- **`patraAccent` (purple) = reading progress and identity. `patraOffline` (teal) = downloads and offline. Never swap them.**
- Serif (`PatraText.serifTitle`, Source Serif 4) is only for titles of works, the wordmark, and reader page numerals. Everything else is Space Grotesk.
- **A swipe pane and a button must never scale with the screen.** `flutter_slidable` asks for an `extentRatio`, so `_ChapterRow` measures the row and converts a *width in points* into one; the resume and sign-out buttons stop at 280. A ratio slides a tablet's row far enough to hide the cover and title the swipe is about to act on, and a button given a whole hero to fill stops reading as a button. Pinned at 820x1180 by `test/tablet_layout_test.dart`, `test/series_hero_test.dart` and `test/series_sections_test.dart`.
- **`./tool/gen_app_icons.sh` reads only from `assets/icon/`, never from `.claude/design/`** — that folder is untracked, and a fresh clone has to be able to regenerate.

The rest of the design system — the three shapes a tablet's width is answered with (`isTabletLayout`), what must never scale with the screen, the empty-library and scan-request states, `CoverPlaceholder`'s derived tones, the palm-frond icon pipeline and its size rule, and the launch screen the OS paints — is in the **`patra-design` skill** (`.claude/skills/patra-design/SKILL.md`). Read it before changing anything visual. The launch *animation* is in `lib/src/features/launch/CLAUDE.md`.

## Rules that apply everywhere

These are resident because a session can break any of them while working in a directory whose own `CLAUDE.md` is not loaded. Each names the file holding the argument behind it.

- **Every `CachedNetworkImage` in the app is drawn with `imageCacheKey`** (`kavita_client.dart`) — the URL with the credential taken out — and never keyed on the raw URL, or a household of four fetches and stores the same cover four times under the one budget they share. `test/shared_image_cache_test.dart` reads `lib/` and fails on an image drawn without one. → `lib/src/settings/CLAUDE.md`
- **Never write "LTR"/"RTL" in UI copy**; use the full localized phrases. And **never rename a value of `ReadingDirection` without adding the old name to `_legacyNames`** — the enum name *is* the persisted preference and an unrecognised string falls back to left-to-right silently, which is how a setting resets itself on somebody's device and says nothing. → `lib/src/features/reader/CLAUDE.md`
- **Clearing the image cache must never touch the documents directory.** The two stores are not interchangeable: saved chapters are chosen by the user and never evicted, the image cache is `cached_network_image`'s own store and the OS may reclaim it. → `lib/src/downloads/CLAUDE.md`
- **Never hardcode "chapter" or "volume" in a screen** — go through `LibraryTypeNaming`, and never hardcode a color or a radius either; every token is in `lib/src/theme.dart`.

The app ships a single dark theme (`themeMode: ThemeMode.dark`): the reader canvas is pure black and the whole chrome is built around it.


## Architecture

A screen declares the providers that are its own — what it has selected, what it is asking the server to do, what somebody has just changed by hand — and never a **read** of the catalogue: those live in `lib/src/catalogue/`, beside the write path and the overlay rule.

### Where the rest of this lives

These sections moved out of this file so they load only when they are relevant. Each is a `CLAUDE.md` beside the code it governs, and each says at the top that this file is still the entry point:

| What | Where |
|---|---|
| The Kavita API client (hand-written, and why) + reaching the server, cleartext, `ConnectionFailure` | `lib/src/api/CLAUDE.md` |
| The catalogue — what the device remembers of a profile's shelves | `lib/src/catalogue/CLAUDE.md` |
| Auth — several profiles, one active session; the profile lock | `lib/src/auth/CLAUDE.md` |
| Preferences — what follows the person, what stays with the device | `lib/src/settings/CLAUDE.md` |
| Downloads and offline; the two stores | `lib/src/downloads/CLAUDE.md` |
| The reader | `lib/src/features/reader/CLAUDE.md` |
| The launch animation | `lib/src/features/launch/CLAUDE.md` |
| Cutting a release, and what CI does | `.github/CLAUDE.md` |
| The design system beyond the two hard rules | `.claude/skills/patra-design/SKILL.md` |

They were written as one continuous argument and still cross-reference each other by name. **When work crosses two of them, read both** — a nested file loads on the directory being touched, not on the subject being reasoned about.

### The keychain

**One seam for every row the device keeps out of the open.** `lib/src/keychain.dart` is `Keychain` — `read`, `readAll`, `write`, `delete`, the plugin's own shape — with `SecureKeychain` in production and a `MemoryKeychain` in tests. `main()` builds one and overrides `keychainProvider` so it and the tree cannot disagree about which one that is.

It holds the auth keys, the profile locks, each person's preferences, the device's own defaults and the install's device id. Per ADR-0004 an auth key is a **whole Kavita account**, so a device remembering four profiles keeps four complete account credentials here — which is why this is a seam worth naming rather than a convenience.

**There were seven `FlutterSecureStorage()`s**, across `auth/`, `settings/`, `lock/` and `api/`: two behind a seam of their own — two seams, in fact, declaring the identical `read`/`write`/`clear` under two names, with two memory fakes that were the same class renamed — and five behind nothing at all. A store that creates its own platform dependency cannot be exercised without one, so tests reached *under* five of them through a mock of the plugin's **method channel**; on a test binding that plugin has no platform behind it, and on Linux a write reaches for libsecret and **hangs the test rather than failing it**. Fourteen suites carried that mock, `auth_test.dart` among them — for a test of pure state, because `AuthNotifier._commit` called a static `SessionStorage.save`.

**What a test overrides is one thing.** The four stateless stores (`SessionStorage`, `ReadingSettingsStore`, `LocaleSettingsStore`, `ImageCacheSettingsStore`) are *derived* from `keychainProvider`, so a second instance of one costs nothing and there is no reason for `main()` and the tree to agree about which instance exists — only about which keychain does. The two that hold their loaded state (`ProfileLockStore`, `ProfilePreferencesStore`) still arrive as instances built in `main()`, for the reason they always did: what a person changes mid-session has to survive a handover.

**Nothing is swallowed in the adapter.** Every store already decides what a failure costs — `SessionStorage.save` keeps a running session over a write it could not make, `ProfileLockStore` refuses to fail a startup over a read it could not make — and those are different answers to different questions. An adapter that caught for them would take the choice away and leave each unable to tell "nothing stored" from "could not be read". `SecureKeychain` passes no options, because all seven built a bare `const FlutterSecureStorage()` and a difference introduced now would apply to rows written without it.

`ClientIdentity` came along because it was the seventh site, and its **device id had no test at all**: the id was read and created through a storage object built inside the method that needed it, so the only reachable path was the `on Exception` fallback. What it prevents is Kavita's own fallback fingerprint — client type plus platform plus device type — collapsing every Android install into one registered device. Covered by `test/client_identity_test.dart`.


### The library type names everything

`LibraryType` (Manga 0 · Comic 1 · Book 2 · Image 3 · LightNovel 4 · ComicVine 5) decides what a series is made of and what its parts are called — Kavita words its whole series page from it, and `lib/src/entity_naming.dart` mirrors that `EntityNamingService`: a comic has **issues** where a manga has **chapters**, and a book library calls a volume a **book** at both levels. Never hardcode "chapter" or "volume" in a screen; go through `LibraryTypeNaming`, and get the type from `libraryTypeProvider(libraryId)` (it falls back to manga while the library list is in flight, so no screen waits on it).

The **French glossary is fixed**: specials = hors-série, volume = tome, chapter = chapitre, issue = numéro (avec le croisillon, `Numéro #12` et `Reprendre — #12`, comme Kavita), storyline = arc narratif. `test/entity_naming_test.dart` pins it in both languages.

The hero's button asks whether the *series* is under way, not the chapter it lands on: finishing a volume leaves the next one untouched, so reading progress off the target alone said "Commencer la lecture" to someone halfway through a series. It is Kavita's own web client that asks the question that way, of the series rather than the chapter; `hasReadingProgress` is that client's concept and appears nowhere in the API, so this mirrors a rule rather than reading a field.

It names only what is **numbered** — `Reprendre — tome 1`, `— ch. 3`, `— #12`, `— livre 2`. A title never reaches it: free text stretches the button across the hero, and a Book library would do it every time, since its files often carry a title and no number at all. Where there is no number (a special, or a lone chapter carrying the sentinel) the button says just `Reprendre`; the title is already on the row it opens.

**What a hero pictures is the chapter it is inside, not the series it belongs to.** Both heroes — the series screen's and Home's Continue card — swap their cover for the resumed chapter's whenever `entryUnderWay` (`resume_point.dart`) says there is a chapter genuinely under way: started, not everything read, and its own `pagesRead > 0`. That is the same predicate the series hero already used to decide whether to draw a page behind itself, hoisted into the file that decides where reading resumes, so neither screen can pick a different chapter from the other. It is the *cover* that both screens agree on; the backdrops still differ, and deliberately — Home draws the resume point's chapter as soon as there is one, page 0 included, where the series screen refuses an unopened page — so on Home a series whose next chapter is untouched shows the series cover over a page. Everything else keeps the series cover, and the two cases it covers are different facts rather than one: on Home the chapter is merely **not known yet** (the card is drawn as soon as its series is, and fills the chapter in behind), while on either screen a button that *starts* a series or offers it *again* has no chapter you are inside — and the first page of something unread is a spoiler, which is why the backdrop refuses it too. A **volume with no chapter breakdown is drawn by its volume cover** (`entryCoverUrl`), the choice the rows below already make: the volume is the reading unit there, and asking for the placeholder chapter's cover instead would fetch and store a second copy of the picture on the row the hero opens, since the shared image cache keys on the URL. The **ring follows the picture** — a bar under a cover means "how far through the thing pictured", the rule every chapter row and library tile obeys — so it is the chapter's progress while the cover is the chapter's, and series-wide only when the cover is. Covered by `test/home_hero_test.dart` and `test/series_hero_test.dart`.

Naming one chapter follows Kavita's own rules: a special is known by its title alone and is never numbered; a title is *appended* to the number (`Chapitre 12 - Le duel`), not swapped for it, and only when it says something the number does not.

Volumes and volumeless chapters read as one story — Kavita calls that the **storyline** and shows it only for Manga and Image libraries (an issue run is not a storyline; a book library has no chapter level). Our series screen has sections, not tabs, so the storyline is the header over the volumes *and* the loose chapters when a series has both; with only volumes it stays "Tomes". Specials always close the screen. Covered by `test/series_sections_test.dart`.

We deliberately do **not** call `GET /api/Series/series-detail`, which returns these buckets ready-made: it is documented as internal ("may change without hesitation") and its labels come pre-formatted in the *server account's* locale, which would fight our own fr/en. We take `/api/Series/volumes` and apply its rules ourselves.


### Navigation

Four tabs (Home / Library / Downloads / Settings) via `StatefulShellRoute.indexedStack`; `/series/:id` and `/reader/:chapterId` are declared **outside** the shell so they are full-screen. Use `context.push()` to drill down — it stacks the screen, giving the AppBar back arrow and correct Android back-button behavior — and `context.go()` only for switching branch or for login/logout redirects. Using `go` for drill-down makes the system back button exit the app.

**Two screens stand in front of the app, and `signedOutLocation` (`routes.dart`) is the whole of which one.** The **picker** (`/profiles`, `features/profiles/`) asks who is reading; the **sign-in form** (`/login`) asks for a password. A device with no profile gets the form; a device with exactly one profile that needs a password gets the form *with that profile already in it* — no picker, because being asked a question with one answer is a tap that device never had to make; everything else gets the picker. The redirect keys off that one function, with a single exception written into it: **`/login` is always reachable while signed out**, because adding a profile and signing a refused one back in are both reached *from* the picker and would otherwise be bounced straight back to it. The router's `refreshListenable` therefore watches the **profile count** as well as the session — forgetting the last profile but one turns the picker into the form while nothing about the session moved.

**A link waits for a profile** (`PendingLink`, in `routes.dart` beside the builders that make these locations). A link names content and a profile names who is reading, and identity comes first: followed as it arrives, a link would open in whichever session was last used, which on a shared device is a coin toss. So go_router's own initial location is **not** followed — `initialLocation: '/'` with `overridePlatformDefaultLocation`, and the platform's `defaultRouteName` is read into a `PendingLink` instead. The app then opens at its gate and the first redirect that finds somebody reading spends the link. That is one branch for every way in, because the wait can be a picker, a password, or no wait at all: a lone profile holding its key is already active at `atLaunch`, so its link opens with no picker — the same rule as everywhere else rather than a case of its own. A **link is what the two builders build**: `/series/<id>` or `/reader/<id>`, with an id that really is one. Everything else is the app's own furniture, and the id is checked because both screens parse theirs out of the path — `/series/nowhere` is not a link that opens nothing, it is a link that opens a crash.

Three things it must not do. It is **pushed, not returned** from the redirect: what a redirect returns *replaces* the stack, and a series with nothing under it draws no back arrow while the reader's own close button is a `maybePop`, which on a lone page does nothing at all — a link would open the app into a room with no door. So the app is built at Home and the link arrives on top of it, a frame later, exactly where a tap would have put it. **A launch is the only thing that may fill one**, and that is a rule about who rather than about tidiness: the redirect meets a content location again whenever a session ends under somebody still reading one, so holding it there would keep person A's screen and push it at person B on the next sign-in — the same coin toss, an hour later. What that costs is a link reaching an app already running and signed out, which goes where go_router takes it and is not held. And it is held **per router, seeded only where `isLaunchProvider` is true**: `defaultRouteName` still names the link that started the process, so the container a handover builds (`SessionScope`) gets `PendingLink.none()` or one person's link opens in the next person's app. A link is spent by being taken, so switching profile later opens Home like any other switch.

Nothing new is needed for a link to content the chosen profile cannot see: what that produces is a refused request, which the screen it lands on already wears — though the series hero's own skeletons had to learn to stop with it (`isResolvedFailure`, the same rule Home follows), since a tally that is never coming was shimmering for good. The splash needs nothing either: the linked screen offers no logo slot, so the frond fades where it stands, which is what the outro already does for any screen without one. Covered by `test/deep_link_test.dart`, which drives the real platform route name (`defaultRouteNameTestValue`) rather than a location typed into the router, and by `test/series_hero_test.dart` for the skeletons.

The picker **never appears on a timer**: the ways here are the app being opened, the face on the trailing edge of the Home bar (beside the offline indicator — a status is a passing thing and the face is the one piece of furniture saying whose app this is), and the server card in Settings. All three do the same one thing, `switchProfile`, so there is no second way to leave a session. Nothing in the reader may ever add a fourth.

Everything the picker draws comes off the `Profile` — a cached avatar (`Profile.avatarUrl`, fetched by account id with the key as the query parameter) or the person's initial on `Profile.color`, the colour Kavita's own web UI paints that account in. Both are learned at sign-in and **written down**, because this screen has to draw before the first request and often without one ever succeeding; a picker that waited on a server would be what stands between someone on a train and the chapters they saved for it. The one thing that reaches the network is a **tap**, and even that has an answer offline. `ProfileAvatar` lives in `widgets/` rather than in the feature, because #12 puts the same face in the Home bar. A profile whose key the server has stopped accepting is **dimmed, badged and worded**: a struck-through key on the avatar in `patraAccent` — where a reader choosing between faces is actually looking — plus the existing "Sign in" under the name, because the handoff's rule is that a cost is always worded and never icon-only, and a glyph says nothing to a screen reader. Accent rather than danger: nothing has gone wrong and nothing is being destroyed, the profile still opens, and what it costs is a password. The badge is **not** drawn while that face's sign-in is in flight, where the spinner already says what is happening. Being stale is only ever *known*, never probed: a key is dropped when a resume or a mid-session renewal earns a bare 401, and the picker marks whatever is already keyless. It does not validate keys in the background — that would make this screen ask a server, which is the one thing it must never do — so a key rotated in Kavita while the app was closed still costs one tap to discover.

The bottom bar **measures its labels before showing them** (`_PatraShell._labelsFit`): French labels are much longer than English ones and a large system font makes any of them overflow the bar, so when they do not fit in their share of the width the bar falls back to icons plus tooltips. Keep `PatraText.navLabel` as the single definition of that style — the theme and the measurement must agree, or the check is meaningless.

Reading changes progress on the server, so a screen that pushed the reader invalidates its own provider when the push returns.

A pane **squeezes** the row rather than sliding it (`_SqueezedByPane`). `Slidable` uncovers a pane by translating its whole child, which carries the cover and the title off the leading edge — the swipe hides the very thing it is about to act on, and in a centred column the row slides out of the column and over the margin. The wrapper works from inside that translation: it undoes it and hands the pane's edge the same width as padding, so the row keeps its origin and every part of itself and is merely narrower while the pane is open. Only the pane's own width is squeezed out; a drag that pulls further keeps the library's slide, which is where the over-drag gets its rubber band. Pinned by `test/series_sections_test.dart` — without it the title's left edge goes from 78pt to -16pt.

A chapter row swipes both ways, and the two edges never mean the same kind of thing: **leading = progress** (mark read / unread, in `patraAccent`), **trailing = destruction** (remove the saved copy, in `patraDanger`). Marking goes through `markChapterRead`, which posts to `mark-multiple-read` / `mark-multiple-unread` — there is no single-chapter *unread* endpoint, and that pair takes one body shape for both directions. It needs the server, so the leading pane is gone offline; it does *not* need a readable format, since a file read elsewhere is exactly what one marks by hand. The stored copy's progress is mirrored alongside, or the Downloads tab would disagree with no server to ask.

The write is **optimistic**: `readOverridesProvider` holds the new progress and `seriesVolumesProvider` lays it over the fetch, so the row redraws on the gesture rather than on the round trip. Re-fetching instead would be worse than slow — the screen pattern-matches `AsyncData`, so any `invalidate` of `volumesProvider` drops the whole list to its skeleton. A refused write clears the override and the row goes back. The map is autoDispose and dies with the screen, so the next visit is the server's word again; `_open` clears the chapter's override too, since reading is about to define progress properly. The hero's cover ring re-fetches `seriesProvider` — flash-free, because the hero reads `.value`, which survives a refresh — because where the cover is the series' the ring is series-wide and cannot be guessed from one chapter. Where a chapter is under way both the cover and its ring are that chapter's (see above) and the override alone moves them, so marking the resumed chapter read walks the hero on to the next one in the same frame as the row.


### Localization

The app is localized (English = template/fallback, French). Never hardcode user-facing strings: add the key to both `lib/l10n/app_en.arb` and `lib/l10n/app_fr.arb`, run `flutter gen-l10n` (also runs automatically on build/test), and use `AppLocalizations.of(context)` (import `lib/l10n/generated/app_localizations.dart`; the getter is non-nullable, configured in `l10n.yaml`). Generated files are committed. Widget tests run under the `en` locale — note `SectionLabel` uppercases its text, so tests match `'CONTINUE'`, not `'Continue'`.

**The language can be forced from Settings**, and "follow the device" is a value rather than the absence of one: `localeProvider` holds a `Locale?` and null is exactly what `MaterialApp`'s `locale` takes to mean "resolve against the system", so the default option needs no separate representation. It is restored before `runApp` like every other preference (`LocaleSettingsStore` for the device's own, `ProfilePreferencesStore` for each person's — see `lib/src/settings/CLAUDE.md`, including why null then had to mean two things and how they are told apart), and a stored code the build no longer ships resolves back to the device rather than to a language with no translations behind it. The picker is built from `supportedLocales`, so a new translation appears in it by existing — the one thing a new locale needs by hand is a line in `languageEndonym`, because **a language is listed under its own name and never translated**: someone who has landed in a language they cannot read has to be able to find their way out of it. `intl` ships no endonyms, so there is nothing to derive it from; `test/locale_settings_test.dart` fails if a shipped locale has no name of its own.

A test that *writes* a preference stands in for the keychain — `testKeychain()` from `test_support.dart`, or a `MemoryKeychain` handed to the store directly. See **The keychain** above for why that is now one override rather than a mock of the plugin's method channel.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

## The tracked graph and its merge driver

`graphify-out/graph.json` is **committed** — it is what a `graphify query` reads, and rebuilding it from nothing costs an LLM run — so two branches that each rebuilt it meet as a conflict in tens of thousands of lines of machine-written JSON. The union merge driver graphify ships is what resolves that, and it comes in **two halves that travel differently**: `.gitattributes` names it (`graphify-out/graph.json merge=graphify`) and is tracked, while the command behind the name is `merge.graphify.driver` in the clone's **own** `git config`, which is not cloned and cannot be committed. A clone with only the first half falls back to an ordinary conflict, silently, at the one moment the driver was meant to help.

`test/graphify_merge_driver_test.dart` is the check. It asserts the attribute and that the graph it names is really tracked — the two are one decision, and a driver declared for an untracked file is as wrong as a tracked graph with no driver — then, **only where `graphify` is on PATH**, that this clone has registered the driver and that what the driver points at still exists. That last one is not paranoia: graphify pins the interpreter by absolute path so the driver works when its launcher is not on PATH at merge time, which is exactly what a pyenv or uv upgrade moves out from under it, and nothing reports it until a merge fails. Where graphify is absent — CI, a clone that only reads the graph — there is nothing to register and the check skips rather than reddening a build over a setup nobody there needs. Every failure is local setup rather than code, and `graphify hook install` is the one command that fixes all of them (`graphify hook status` reports them).

The generated files around the graph are **not** tracked: the AST/semantic cache, `manifest.json` (mtimes, so it churns on every build), `cost.json`, the 1.5MB `graph.html` viewer, and the two dotfiles recording this machine's repo root and Python interpreter. What is tracked is only what cost something to make — the graph, `GRAPH_REPORT.md`, and `.graphify_labels.json`, the community names.
