# ADR-0005 — The catalogue is what the device remembers, and it is files

**Status:** accepted · **Date:** 2026-09-08

## Context

Nothing about a profile's structure is persisted. `librariesProvider`,
`seriesForLibraryProvider`, `volumesProvider`, `seriesProvider`,
`seriesMetadataProvider` and `onDeckProvider` are all
`FutureProvider.autoDispose` straight onto the client, so offline they resolve
into failures and each screen draws its own version of nothing: Home draws
`_OfflineHome` pointing at Downloads, the Library tab a cloud-off state, the
series screen a banner over rows that cannot be opened.

The device already remembers a fragment of the structure, in every saved
chapter's `meta.json` — `libraryId`, `seriesId`, `volumeId`, `chapterId`,
`seriesName`, `title`, `pages`, `pagesRead`. That is enough to *reach* a saved
chapter and not enough to *navigate*: no library name, no library type, no
cover, no sibling chapters. So a person who saved four chapters for a train has
them in the Downloads tab and an app that otherwise claims to know nothing.

Two stores already exist and the docs insist they must not be confused: **saved
chapters**, chosen deliberately and never evicted, and the **image cache**,
which the device owns, is capped, and the OS may reclaim. This adds a third.

## Decision

The device keeps a **catalogue** per profile: the libraries, the series in them,
and the volumes, chapters and description of every series that has been opened.
It is **files split by level** under `<documents>/catalogue/<profile>/` —
`spine.json`, `series/<id>.json`, `ondeck.json` — written from our own models'
`toJson`, behind a version stamp that **discards rather than migrates**.

It is read **cache-first**, through an overlay provider per list, with one
precedence rule: *live wins; otherwise stored data draws as data, not as
loading; otherwise the live error; otherwise loading.*

## Why files, and not a database

Measured against what a database would buy here, and the shortlist is real:
**drift** 2.34.4 runs under `flutter test` via `NativeDatabase.memory()`, needs
no apt package on `ubuntu-latest` since it moved to Dart build hooks, and its
`destructiveFallback` *is* the discard policy above. So the usual objection —
that a database costs the test suite — is stale, and is not the reason.

The reason is that **nothing asks for one**. A database's decisive advantage
over files is querying a collection without loading it: search a profile's
whole library by title, filter by format or read state, sort by last read.
Search here is Kavita's job, called over the API, so that advantage has no
buyer. The rest of what a catalogue might grow into does not need SQL either:
EPUB progress and `bookScrollId` are one small value per chapter, collections
and reading lists have exactly the shape libraries and series already have, and
a replay journal is an append-only queue.

And the option stays cheap. **The catalogue is the one store in this app whose
data is worthless** — every byte of it is refetchable, which is why a version
mismatch discards it. So "we can change our minds later", normally a lie about
persistence, is true: swapping files for a database costs the write path and
nothing else, against data nobody would miss and a migration nobody has to
write. Paying now buys an option we can buy just as cheaply the day something
wants it.

The cost of paying now is not zero either, and it lands on the part of this
repository that is handled most carefully. drift introduces `build_runner`
codegen, which nothing here uses; the `sqlite3` build hook **downloads** a
prebuilt SQLite from GitHub releases at build time, adding a network dependency
to the Android job, the iOS job and every release tag; and iOS code assets
carry no debug symbols, which surfaces as an App Store Connect warning on
upload. For a pipeline whose recovery hatch is a `workflow_dispatch` at a tag —
because GitHub's own re-run reuses a run number both stores would reject — that
is a poor trade for an option with no buyer.

`sqflite` would have been the wrong shape regardless: its own docs say testing
with `flutter_test` is unsupported, and the workaround needs
`sqflite_common_ffi` with a separate `databaseFactoryFfiNoIsolate` for
`testWidgets`, which is nearly every test here. Of the rest, **Realm Flutter**
reached EOL on 2025-09-30, **Isar** has had no stable release since April 2023,
and **ObjectBox** needs `install.sh` before it runs on the Dart VM. **hive_ce**
is the one near-free alternative — pure Dart, no native libraries, `Hive.init`
in a test — and it was a defensible answer: it buys typed boxes and atomic
writes and no whole-file rewrites, but no queries, which makes it files with an
index. Files won on having nothing to add to `pubspec.yaml`.

Split by level rather than one file per profile because sizes make it matter: a
2000-series library is ~500KB and a series' volumes ~50KB, so one file per
profile would rewrite megabytes every time a series is opened. Under
**documents** rather than the system cache directory because a store the OS may
silently empty cannot be the thing that makes navigation consistent — that is
what the image cache already is, and the point of this is not to be that.

## Cost, accepted

**A stale list is drawn as if current**, for the second or so before the
refresh lands. That is the price of cache-first, and it is the staleness this
app already accepts everywhere else: a library is only ever as current as its
last scan, and `isAdmin` is only as fresh as the last sign-in.

**The shared image cache's invariant is eroded.** It rests on *"the app only
ever builds an image URL for content the server has already listed for the
profile asking"*, which becomes *"…has listed for the profile asking, at some
point"*. If a profile's access to a library is revoked in Kavita then offline
its catalogue still lists it and still builds its cover URLs, and the device's
shared image cache may hand back covers another profile fetched. Online it
cannot outlive one fetch, because a successful fetch replaces the list. There
is no offline fix: asking the server whether access still stands is precisely
what an offline device cannot do. What leaks is a *cover picture* of a series
whose existence that profile had already been told about; every page is behind
a request that will be refused.

**Offline reading still does not reach the server.** `_saveProgress` mirrors
into the saved copy and posts on a queue whose failure is swallowed, so the
server never learns what was read on a train. The catalogue therefore
**overlays** rather than absorbs: the series screen shows the saved copy's true
progress, the grid shows the server's last word. Absorbing it would make every
screen agree offline and then walk visibly backwards on reconnect, when the
server's older answer replaces it. A replay journal is the real fix, is its own
piece of work, and is the one future store that would *not* be discardable —
which is what would finally argue for a database.

## Consequences

**`isResolvedFailure` means something new.** It has meant "draw nothing, the app
bar says why"; it now means "draw nothing *if the catalogue has nothing
either*". Where the catalogue is empty — a first launch offline, a library never
opened — today's screens stand untouched, so the change is additive.

**Only a complete answer replaces.** `allSeriesForLibrary` pages until a short
page comes back; a run that fails on page 3 must not replace 250 stored series
with 200, or the store loses exactly what it exists to keep.

**A cover is never pinned.** Covers stay in the image cache, one copy per
device, so a stored series list routinely outlives the pictures of it. The
answer is a real placeholder — the cover's radius, a 45° hatch in two tones
derived from the series id, and the series' initial in the serif, which is the
app's existing answer to "no picture of this thing" on the picker. Pinning
would fork `imageCacheKey` into a copy per profile, or put a hole in the trim
sweep's budget.

**It dies with its profile**, in the confirmation that already takes the lock,
the preferences and the saved chapters — and is not named in that copy, which
lists what a person chose to keep and what it costs them. No expiry, because an
old catalogue is strictly better than none. No cap and no Settings row, because
it is hundreds of KB against an image cache measured in hundreds of MB and a
clear button could only make the app worse offline. Clearing the image cache
must not touch it.

See [ADR-0003](./0003-a-profile-is-a-kavita-account.md) for why the store is
per profile at all.
