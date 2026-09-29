import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/kavita_client.dart';
import '../api/models.dart';
import '../auth/session.dart';
import '../downloads/downloads_provider.dart';
import 'catalogue_store.dart';

/// Where every profile's catalogue lives, which the **device** owns — null
/// meaning the documents directory, as the store resolves it itself.
///
/// Overridable so a test can hand the store a temp directory while still
/// letting the providers below do the profile scoping, which is the part
/// worth exercising. Mirrors `downloadsRootProvider`, and for the same
/// reasons.
final catalogueRootProvider = Provider<Directory?>((ref) => null);

/// The catalogue of any profile this device remembers, by [Profile.id].
///
/// Settings needs one for a profile nobody is signed in as: removing a face
/// deletes its catalogue, and that has to work for an account deleted on the
/// server, which nothing could ever enter again.
/// The store `main()` warmed, if any, is handed in as an override of this
/// family's one key — which is the whole reason the spine it awaited before
/// `runApp` is worth awaiting: the session goes on to read that same
/// instance, already holding it, rather than a second one that would have to
/// read the file again.
final profileCatalogueProvider = Provider.family<CatalogueStore, String>(
  (ref, profileId) => CatalogueStore(
    root: ref.watch(catalogueRootProvider),
    profileId: profileId,
  ),
);

/// The store this container is reading through, kept for the same reason
/// [kavitaClientProvider] keeps its client: Riverpod flushes a dirty provider
/// that has listeners at the end of the frame, so a session going null
/// recomputes this while the shell is still on screen and still writing
/// through it. Per container, so it cannot hand one person's catalogue to the
/// next.
class _StoreHolder {
  CatalogueStore? store;
}

final _storeHolderProvider = Provider<_StoreHolder>((ref) => _StoreHolder());

/// The active profile's catalogue, and what every fetch writes into.
///
/// Scoped to the session for the reason the saved chapters are: what a person
/// may see is the server's answer to them alone, and two profiles at one
/// address would otherwise browse each other's shelves offline. Entering
/// somebody else builds the whole container again (`SessionScope`), so this
/// is resolved once per profile and never swapped under a screen.
final catalogueStoreProvider = Provider<CatalogueStore>(
  // The no-session StateError is control flow, not a transient failure.
  retry: (retryCount, error) => null,
  (ref) {
    final profileId = ref.watch(sessionProvider.select((s) => s?.id));
    final holder = ref.read(_storeHolderProvider);
    if (profileId == null) {
      final previous = holder.store;
      if (previous != null) return previous;
      throw StateError('No active session');
    }
    final store = ref.watch(profileCatalogueProvider(profileId));
    holder.store = store;
    return store;
  },
);

/// What this container has already filled the catalogue with: libraries,
/// and the series the device keeps copies of.
///
/// The prefetch below is triggered by the library list landing, and that list
/// lands again on every pull-to-refresh — so without this a household's
/// 2000-series library would be paged through again on every tug of the
/// Library tab. What is remembered is the *successes*: a library the prefetch
/// could not reach is tried again the next time the list lands, which is what
/// makes coming back online enough.
class CataloguePrefetch {
  CataloguePrefetch({required this.savedSeries});

  /// The series this profile holds a saved copy of — asked when a run starts
  /// rather than once, since a copy saved mid-session counts on the next run.
  final Future<Set<int>> Function() savedSeries;

  final _done = <int>{};
  final _seriesDone = <int>{};
  Future<void>? _run;

  /// Settles when no run is in flight — for a test, since the library list's
  /// write starts a run and never waits on it.
  @visibleForTesting
  Future<void> get idle => _run ?? Future.value();

  /// Fills what the catalogue is missing, **one request after another**, and
  /// writes each answer into [store]: first every series the device keeps a
  /// copy of, then the series list of every library.
  ///
  /// One trigger for both screens rather than a rule per tab: the Library tab
  /// and Home both ask for the library list, and this hangs off that answer
  /// wherever it happened. Sequential is the whole of "low priority" — the
  /// point is that a library nobody has opened is navigable offline, not that
  /// it is there quickly, and a burst of one request per library would be
  /// paid for by the screen the person is actually looking at.
  ///
  /// A library that fails is skipped rather than abandoning the run: they are
  /// separate answers, and one refused library says nothing about the next.
  Future<void> run({
    required KavitaClient client,
    required CatalogueStore store,
    required List<Library> libraries,
  }) {
    if (_run != null) return Future.value();
    return _run = _fill(
      client,
      store,
      libraries,
    ).whenComplete(() => _run = null);
  }

  Future<void> _fill(
    KavitaClient client,
    CatalogueStore store,
    List<Library> libraries,
  ) async {
    await _fillSavedSeries(client, store);
    for (final library in libraries) {
      if (_done.contains(library.id)) continue;
      try {
        await store.putSeriesList(
          library.id,
          await client.allSeriesForLibrary(library.id),
        );
        _done.add(library.id);
      } on Object {
        continue;
      }
    }
  }

  /// Stores the volumes, the row and the description of every series the
  /// device keeps a copy of, wherever the catalogue does not hold them yet.
  ///
  /// Volumes are otherwise a trace of what was *opened*, and that is not
  /// enough for a series somebody chose to keep: a version bump discards every
  /// stored series, and a copy saved before the catalogue existed was never
  /// written at all — so offline its series was a retry button over chapters
  /// sitting on the device. First, because these are a handful of small
  /// requests where a library can be forty pages of series.
  ///
  /// Only what is missing is asked for: a stored series is refreshed by
  /// opening it, like any other, and this is a floor rather than a sync.
  Future<void> _fillSavedSeries(
    KavitaClient client,
    CatalogueStore store,
  ) async {
    final Set<int> kept;
    try {
      kept = await savedSeries();
    } on Object {
      return;
    }
    for (final seriesId in kept) {
      if (_seriesDone.contains(seriesId)) continue;
      try {
        final held = await store.loadSeries(seriesId);
        if (held?.volumes == null) {
          await store.putVolumes(seriesId, await client.volumes(seriesId));
        }
        if (held?.series == null) {
          await store.putSeries(await client.series(seriesId));
        }
        if (held?.metadata == null) {
          await store.putSeriesMetadata(
            seriesId,
            await client.seriesMetadata(seriesId),
          );
        }
        _seriesDone.add(seriesId);
      } on Object {
        continue;
      }
    }
  }

  /// Marks a library as filled by somebody else — the Library tab's own
  /// fetch, which stores exactly what this would have gone and asked for.
  void markStored(int libraryId) => _done.add(libraryId);
}

/// The fill, reading which series are kept off the downloads store.
///
/// That store is read through its provider when a run starts, not before:
/// this provider lives as long as the session's container, so the `ref` is
/// still good by the time the library list has landed.
final cataloguePrefetchProvider = Provider<CataloguePrefetch>(
  (ref) => CataloguePrefetch(
    savedSeries: () async {
      final state = await ref.read(downloadsProvider.future);
      return {for (final copy in state.saved.values) copy.seriesId};
    },
  ),
);
