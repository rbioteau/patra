/// The six questions the catalogue answers, and the one thing derived from
/// them.
///
/// These used to be declared at the top of the three screens that draw them —
/// the Library tab, the series screen and Home — which is how the fetch behind
/// each came to be public: pull-to-refresh had to reach it from the screen,
/// and there was nowhere else for it to live. It also meant Home imported a
/// 1194-line series screen to reach one provider, and that the module holding
/// the overlay rule held none of the reads that apply it.
///
/// They live here now, and the fetches are private. What a screen imports is
/// this file; what it can reach is [CatalogueRead]'s three handles. See
/// `catalogue_read.dart` for why they are handles.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../auth/session.dart';
import 'catalogue_provider.dart';
import 'catalogue_read.dart';

/// The libraries this profile can see.
///
/// The catalogue is written **in this body** rather than by a listener beside
/// it: a listener would keep the fetch pure, but it cannot be built for the
/// `.family` providers below without every screen registering its own, since
/// a family's live keys cannot be enumerated. Writing here also means the
/// write cannot be skipped — the only way to get a fetched list is through
/// the body that stores it.
final _librariesFetchProvider = FutureProvider.autoDispose<List<Library>>(
  retry: serverRetry,
  (ref) async {
    final client = ref.watch(kavitaClientProvider);
    // Both resolved **before** the request: this provider is autoDispose, so
    // a screen left while its fetch is in flight disposes it mid-body, and a
    // `ref` read after that throws rather than answering.
    final store = ref.read(catalogueStoreProvider);
    final prefetch = ref.read(cataloguePrefetchProvider);
    final libraries = await client.libraries();
    // Replaces: a library this profile has lost access to has to disappear,
    // and merging would keep it for good.
    await store.putLibraries(libraries);
    // And the series of every one of them, so a library never opened is
    // still navigable offline. Hung off the answer rather than off a tab,
    // because Home asks for this list too and one trigger is what keeps the
    // two from being two rules.
    unawaited(prefetch.run(client: client, store: store, libraries: libraries));
    return libraries;
  },
);

/// The libraries as the Library tab and Home draw them: the server's answer
/// where there is one, and otherwise what the device remembers.
///
/// **One question both tabs ask**, deliberately, so they cannot disagree
/// about which libraries exist — which is also why Home's own offline gate
/// consults the catalogue from the moment this read exists.
///
/// An empty stored library list counts as nothing stored rather than as an
/// answer: a profile with no libraries at all has nothing to navigate
/// offline, and the screen it lands on is the same one either way.
final libraries = CatalogueRead.spine<List<Library>>(
  fetch: _librariesFetchProvider,
  held: (spine) => spine.libraries.isEmpty ? null : spine.libraries,
);

/// The type of one library, which decides what its series are made of and what
/// those parts are called. Falls back to manga while the list is in flight —
/// the wording settles as soon as it lands, and no screen has to wait on it.
///
/// Derived rather than fetched, so it is a plain provider and has no request
/// of its own to refresh. It reads [libraries] and not its fetch, or offline
/// a comic library would say "chapitre".
final libraryTypeProvider = Provider.autoDispose.family<LibraryType, int>((
  ref,
  libraryId,
) {
  final list = ref.watch(libraries.provider).value;
  if (list == null) return LibraryType.manga;
  for (final library in list) {
    if (library.id == libraryId) return library.type;
  }
  return LibraryType.manga;
});

/// Every series in one library, and the catalogue's copy of that list.
///
/// **Only a complete answer replaces**, and the paging loop is what says so:
/// `allSeriesForLibrary` returns only once a short page has ended the run,
/// and rejects otherwise — so a run that dies on page 3 never reaches this
/// body at all, and cannot replace 250 stored series with 200.
final _seriesForLibraryFetchProvider = FutureProvider.autoDispose
    .family<List<Series>, int>(retry: serverRetry, (ref, libraryId) async {
      final client = ref.watch(kavitaClientProvider);
      // See `_librariesFetchProvider` for why these are in hand before
      // the request.
      final store = ref.read(catalogueStoreProvider);
      final prefetch = ref.read(cataloguePrefetchProvider);
      final series = await client.allSeriesForLibrary(libraryId);
      await store.putSeriesList(libraryId, series);
      // The eager fill has no reason to page this library again: opening the
      // tab asks for the library list and for the selected library at once.
      prefetch.markStored(libraryId);
      return series;
    });

/// One library's series as the grid draws them.
///
/// A library stored as **empty** is an answer here and not an absence: an
/// empty library is a state that screen has copy for, and falling through to
/// the failure would replace that copy with a retry button.
final seriesForLibrary = CatalogueRead.spinePerKey<List<Series>, int>(
  fetch: _seriesForLibraryFetchProvider,
  held: (spine, libraryId) => spine.series[libraryId],
);

/// The next thing to read in each series — the "On deck" shelf, and the
/// candidates the Continue hero is promoted from.
///
/// **One request answers both, because it is one question.** Kavita builds
/// this from `PagesRead > 0 && PagesRead < Pages` plus a recency clause
/// (`LatestReadDate >= now - OnDeckProgressDays`, or a chapter added inside
/// `OnDeckUpdateDays`), which is exactly "started, unfinished, and still
/// live". The hero used to come from `/api/Series/currently-reading`
/// instead, on the reading that its name is the question — and it is not:
/// Kavita builds *that* from `ReadLast GreaterThan OnDeckProgressDays`, a
/// comparison `SeriesFilter.HasReadLast` deliberately inverts into
/// `MaxDate < now - N`. It is the pile you started and have not touched in
/// over a month, the **complement** of this one, so anybody reading
/// regularly had no hero at all while this very shelf listed what they were
/// reading.
final _onDeckFetchProvider = FutureProvider.autoDispose<List<Series>>(
  retry: serverRetry,
  (ref) async {
    final client = ref.watch(kavitaClientProvider);
    // In hand before the request: see `_librariesFetchProvider`.
    final store = ref.read(catalogueStoreProvider);
    final series = await client.onDeck();
    await store.putOnDeck(series);
    return series;
  },
);

/// The shelf as Home draws it: the server's ranking where there is one, and
/// otherwise the last one the device was given.
///
/// See `onDeckOverlay` for what a stored ranking is and is not. It is **not
/// decorated**: the app bar's struck-through cloud already says the answer may
/// be old, and per ADR-0005 an individual row never carries a mark of its own.
final onDeck = CatalogueRead.onDeck(fetch: _onDeckFetchProvider);

/// A series' volumes and their chapters, and the catalogue's copy of them.
///
/// Volumes stay a **trace of what was actually opened**: nothing prefetches
/// them, because a device that browsed a 2000-series library would otherwise
/// hold every chapter of all of it. See `_librariesFetchProvider` for why the
/// write is in the body.
final _volumesFetchProvider = FutureProvider.autoDispose
    .family<List<Volume>, int>(retry: serverRetry, (ref, seriesId) async {
      final client = ref.watch(kavitaClientProvider);
      // In hand before the request: leaving the screen disposes this provider
      // while its fetch is in flight, and a `ref` read after that throws.
      final store = ref.read(catalogueStoreProvider);
      final volumes = await client.volumes(seriesId);
      await store.putVolumes(seriesId, volumes);
      return volumes;
    });

/// The volumes as anything that draws them sees them: the server's answer
/// where there is one, and otherwise what the device remembers of the series.
///
/// A [StoredRead], because the series screen's rows need the second fact —
/// what is laid over a row depends on whether the server answered for it. Its
/// `overlaid` handle is the only one anything asks for; Home's Continue card
/// takes the value.
///
/// That card is why this is shared rather than duplicated: it is picked out of
/// the On deck answer and resumes from these volumes, so a card offline draws
/// exactly where the featured series happens to have been opened before. Where
/// it has not, the overlay resolves into the fetch's failure and the shelf
/// keeps its series.
final volumes = CatalogueRead.storedPerSeries<List<Volume>>(
  fetch: _volumesFetchProvider,
  held: (stored) => stored.volumes,
);

final _seriesFetchProvider = FutureProvider.autoDispose.family<Series, int>(
  retry: serverRetry,
  (ref, seriesId) async {
    final client = ref.watch(kavitaClientProvider);
    final store = ref.read(catalogueStoreProvider);
    final series = await client.series(seriesId);
    await store.putSeries(series);
    return series;
  },
);

/// The series' own row — its library name, and the series-level tally the
/// hero's ring is drawn from.
final series = CatalogueRead.storedPerSeries<Series>(
  fetch: _seriesFetchProvider,
  held: (stored) => stored.series,
);

final _seriesMetadataFetchProvider = FutureProvider.autoDispose
    .family<SeriesMetadata, int>(retry: serverRetry, (ref, seriesId) async {
      final client = ref.watch(kavitaClientProvider);
      final store = ref.read(catalogueStoreProvider);
      final metadata = await client.seriesMetadata(seriesId);
      await store.putSeriesMetadata(seriesId, metadata);
      return metadata;
    });

/// Who made the series and what it is about.
final seriesMetadata = CatalogueRead.storedPerSeries<SeriesMetadata>(
  fetch: _seriesMetadataFetchProvider,
  held: (stored) => stored.metadata,
);
