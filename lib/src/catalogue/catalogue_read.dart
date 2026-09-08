/// One question the catalogue answers, and the only way to ask it again.
///
/// A **read** is a pair: the request, and the device's memory laid under it by
/// [overlaid]. The pair used to be declared in whichever screen happened to
/// draw it, which put the fetch in every screen's reach — and the fetch is the
/// one thing no screen may watch, since watching it skips the catalogue
/// entirely and shows a shimmer over shelves the device is holding. The rule
/// was kept by a test that read all of `lib/` looking for the mistake.
///
/// Here the fetch is **private to the read** instead, and what a caller gets
/// is three handles: [CatalogueRead.provider] to watch, [refreshable] to ask
/// again and await the answer, [invalidatable] to ask again without waiting.
/// The rule is then the compiler's, and the source scan in
/// `test/catalogue_overlay_test.dart` has been narrowed to the mistake still
/// available — declaring a fetch outside this folder.
///
/// The three handles are handles rather than methods because `Ref`,
/// `WidgetRef` and `ProviderContainer` are three unrelated sealed types over
/// two `@internal` bases, so no one parameter type could serve a provider, a
/// screen and a test. `refresh` and `invalidate` are already methods on all
/// three; what they were missing is something safe to be handed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show
        FutureProviderFamily,
        ProviderListenable,
        ProviderOrFamily,
        Refreshable;

import '../api/models.dart';
import 'catalogue_overlay.dart';
import 'catalogue_store.dart';

/// A read for one key, or for none.
///
/// Keyed reads hand out one of these **per key** ([KeyedRead]) and never a
/// handle to the whole family: `invalidate` accepts a family and would drop
/// every key, which is not a thing any screen wants and is exactly the
/// mistake worth making unreachable rather than documenting.
class CatalogueRead<T> {
  const CatalogueRead._(this.provider, this._fetch);

  /// What a screen watches: the server's answer where there is one, and
  /// otherwise what the device remembers.
  final ProviderListenable<AsyncValue<T>> provider;

  final FutureProvider<T> _fetch;

  /// Ask again, and await what comes back — pull-to-refresh, and Home's own
  /// refresh, which waits on two of these at once.
  ///
  /// A `Refreshable` is also what `read` takes, so one handle covers both
  /// "ask again" and "wait for the answer already in flight".
  Refreshable<Future<T>> get refreshable => _fetch.future;

  /// Ask again without waiting — a retry button, and the invalidation every
  /// screen does on the way back from reading.
  ProviderOrFamily get invalidatable => _fetch;

  /// A read of the [Spine]: the libraries, and the series in each of them.
  static CatalogueRead<T> spine<T>({
    required FutureProvider<T> fetch,
    required T? Function(Spine spine) held,
  }) => CatalogueRead._(
    Provider.autoDispose<AsyncValue<T>>(
      (ref) => spineOverlay(ref, fetch, held),
    ),
    fetch,
  );

  /// A read of one part of the [Spine], per key.
  static KeyedRead<T, K> spinePerKey<T, K>({
    required FutureProviderFamily<T, K> fetch,
    required T? Function(Spine spine, K key) held,
  }) {
    final overlay = Provider.autoDispose.family<AsyncValue<T>, K>(
      (ref, key) => spineOverlay(ref, fetch(key), (spine) => held(spine, key)),
    );
    return (key) => CatalogueRead._(overlay(key), fetch(key));
  }

  /// The On deck ranking, which is the server's own order and not structure —
  /// see [onDeckOverlay] for what a stored one is and is not.
  ///
  /// Not generic, because there is one of these and its picker is a rule
  /// rather than a parameter: an empty stored ranking is nothing stored.
  static CatalogueRead<List<Series>> onDeck({
    required FutureProvider<List<Series>> fetch,
  }) => CatalogueRead._(
    Provider.autoDispose<AsyncValue<List<Series>>>(
      (ref) => onDeckOverlay(ref, fetch),
    ),
    fetch,
  );

  /// A read of one part of one series' own file, per series.
  ///
  /// These are the reads that answer with **two facts** — see [StoredRead].
  static StoredKeyedRead<T> storedPerSeries<T>({
    required FutureProviderFamily<T, int> fetch,
    required T? Function(StoredSeries stored) held,
  }) {
    final overlaid = Provider.autoDispose.family<Overlaid<T>, int>(
      (ref, seriesId) =>
          storedSeriesOverlay(ref, seriesId, fetch(seriesId), held),
    );
    // One hop down from [overlaid] rather than a second call into the
    // overlay, so the two can never disagree about the same series. `Overlaid`
    // is a record, so this notifies only when the answer itself moves.
    final value = Provider.autoDispose.family<AsyncValue<T>, int>(
      (ref, seriesId) => ref.watch(overlaid(seriesId)).value,
    );
    return (seriesId) =>
        StoredRead._(value(seriesId), fetch(seriesId), overlaid(seriesId));
  }
}

/// A read that also says **which** of the two answered.
///
/// Progress is the one case where a screen has to know: a row drawn from the
/// device's memory has a newer word about itself in the saved copy beside it,
/// where a row the server has just answered for is the other way round. Only
/// `seriesVolumesProvider` asks; the other two stored reads take [provider]
/// and never look.
class StoredRead<T> extends CatalogueRead<T> {
  const StoredRead._(super.provider, super.fetch, this.overlaid) : super._();

  /// The answer and whether the catalogue is what gave it.
  final ProviderListenable<Overlaid<T>> overlaid;
}

/// A read that takes a key, handing out one [CatalogueRead] per key.
///
/// A function rather than an object with a `call`, so there is no whole-family
/// handle to reach for in the first place.
typedef KeyedRead<T, K> = CatalogueRead<T> Function(K key);

/// The same, for the reads that answer with two facts.
typedef StoredKeyedRead<T> = StoredRead<T> Function(int seriesId);
