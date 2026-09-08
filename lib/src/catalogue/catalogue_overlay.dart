import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../api/models.dart';
import 'catalogue_provider.dart';
import 'catalogue_store.dart';

/// This session's catalogue, or null where nobody is reading yet.
///
/// The store throws a `StateError` with no session, which is control flow
/// there and has to stay control flow here: propagating it would put a
/// `StateError` on a shelf, where the honest answer is that the device
/// remembers nothing *for this session*.
CatalogueStore? _storeOrNull(Ref ref) {
  try {
    return ref.watch(catalogueStoreProvider);
  } on StateError {
    return null;
  }
}

/// Reads the spine off the device — the slow path, taken once per session.
///
/// Not retried, and for the same reason nothing about this store ever fails
/// loudly: the read is a local file the store already guards, so what
/// arrives here is at worst an empty spine, and a screen's answer to that is
/// to draw what the server says. Retrying a disk read that came back empty
/// would be waiting for a file to appear that only a fetch can write.
final _spineReadProvider = FutureProvider<Spine>(
  retry: (retryCount, error) => null,
  (ref) async => await _storeOrNull(ref)?.loadSpine() ?? const Spine(),
);

/// One list, laid over what the device remembers of it: [fetch] is the
/// request, and [held] picks that list out of the spine.
///
/// Called from an overlay provider's own body rather than being a provider
/// itself, and **that is what keeps the spine current**. The store replaces
/// its `Spine` on every write (`_writeSpine`), so a provider that cached one
/// would answer with the spine as it stood when it was first built — and the
/// ordinary case is exactly the one that breaks: browse a library online
/// (which writes the spine, and prefetches every other library into it),
/// then lose the connection and open a second library. Its fetch fails, and
/// a cached spine from launch has never heard of it. Read here, the spine is
/// re-read whenever the fetch moves, which is precisely when the answer
/// might change.
///
/// **Synchronous wherever the store already holds the spine**, which is the
/// ordinary case: `main()` awaits it before the first frame on the path
/// where a profile was already active, and every write since has kept it in
/// step. The read is still *watched*, because the path in from the picker
/// awaits nothing — without it, the failure a cold offline start drew would
/// never be replaced by the spine that landed a moment after it.
AsyncValue<T> spineOverlay<T>(
  Ref ref,
  ProviderListenable<AsyncValue<T>> fetch,
  T? Function(Spine spine) held,
) {
  final live = ref.watch(fetch);
  // Watched for its arrival, and used only where the store has nothing in
  // hand yet.
  final read = ref.watch(_spineReadProvider);
  final spine = _storeOrNull(ref)?.spine;
  return overlaid(
    live,
    spine == null ? read.whenData<T?>(held) : AsyncValue.data(held(spine)),
  );
}

/// Reads the On deck answer off the device — a one-shot, like the spine.
final _onDeckReadProvider = FutureProvider<List<Series>>(
  retry: (retryCount, error) => null,
  (ref) async => await _storeOrNull(ref)?.loadOnDeck() ?? const <Series>[],
);

/// An empty stored ranking is **nothing stored** rather than an answer,
/// exactly as an empty stored library list is: a shelf draws nothing either
/// way, so reading it as an answer would only tell Home's offline gate that
/// something came back and take `_OfflineHome` away from a device that really
/// does hold nothing.
///
/// Named once because the ranking arrives by two routes — off the disk and
/// out of the store's own copy — and a rule stated at each of them is a rule
/// that can disagree with itself.
List<Series>? _rankingOrNothing(List<Series> stored) =>
    stored.isEmpty ? null : stored;

/// The On deck shelf, laid over what the device remembers of it.
///
/// **The server's own ranking, not structure.** Kavita builds On deck from
/// `PagesRead > 0 && PagesRead < Pages` plus a recency clause, so a stored
/// one is a ranking that was true when it was fetched and may be hours old —
/// which is drawn with no decoration of any kind, because the app bar's
/// struck-through cloud already says the answer may be stale and a row is
/// never marked (ADR-0005).
///
/// Shaped like [spineOverlay], and the store's own copy is read on every
/// build for the same reason: a shelf a fetch wrote this session is what a
/// later failure has to fall back to, not the file as it stood when the
/// session started. Without that, a pull with the connection newly gone
/// could replace today's shelf with yesterday's.
AsyncValue<List<Series>> onDeckOverlay(
  Ref ref,
  ProviderListenable<AsyncValue<List<Series>>> fetch,
) {
  final live = ref.watch(fetch);
  // Watched for its arrival, and used only where the store has nothing in
  // hand yet.
  final read = ref.watch(_onDeckReadProvider);
  final held = _storeOrNull(ref)?.onDeck;
  final stored = held == null ? read : AsyncValue.data(held);
  return overlaid(live, stored.whenData<List<Series>?>(_rankingOrNothing));
}

/// Reads what the device holds about one series — its volumes, its own row
/// and its description — off the device, once per series.
///
/// `autoDispose` where the spine's read is not: this is the trace of what has
/// actually been opened, so a long session would otherwise hold every series
/// it ever looked at in memory.
///
/// **And that lifetime is why this level needs no in-memory copy**, where the
/// spine and the On deck ranking both do. Those two are read once per session
/// and written by somebody *else* — the eager fill fills the spine for
/// libraries no screen asked for — so a fallback frozen at the first read
/// goes stale under them, which is what `spineOverlay` and `onDeckOverlay`
/// say at length. Here each of the three parts has exactly one writer, its
/// own fetch: a part whose fetch succeeded has a live value and never
/// consults this at all, and a part whose fetch failed has had nothing
/// written for it. This read also dies with that fetch, so a screen coming
/// back re-reads the file rather than answering from a snapshot. Pinned by
/// the two tests in `test/catalogue_overlay_test.dart` under "one series'
/// volumes", which is where a store-side cache would have been argued for.
final _seriesReadProvider = FutureProvider.autoDispose
    .family<StoredSeries?, int>(
      retry: (retryCount, error) => null,
      (ref, seriesId) async => await _storeOrNull(ref)?.loadSeries(seriesId),
    );

/// One part of a stored series, laid under [fetch]: [held] picks that part
/// out of the file, and any of the three may be missing, since they arrive
/// from three different fetches.
///
/// The [spineOverlay] of the level below it, and the same rules apply — the
/// fetch is passed in rather than named here, so nothing outside this file
/// ever watches one.
///
/// It answers with **two facts rather than one**, because a screen sometimes
/// has to know which of them it got. **Progress is that case**: a row drawn
/// from memory has a *newer* word about itself sitting in the saved copy
/// beside it — offline reading mirrors into `meta.json` and posts on a queue
/// whose failure is swallowed, so the server never learns what was read on a
/// train, and the catalogue deliberately never absorbs it (ADR-0005). A row
/// the server has just answered for is the other way round: there the server
/// is the authority and the saved copy is what gets corrected from it. See
/// `seriesVolumesProvider`, the only caller that asks.
Overlaid<T> storedSeriesOverlay<T>(
  Ref ref,
  int seriesId,
  ProviderListenable<AsyncValue<T>> fetch,
  T? Function(StoredSeries stored) held,
) {
  final live = ref.watch(fetch);
  final read = ref.watch(_seriesReadProvider(seriesId));
  final value = overlaid(
    live,
    read.whenData((stored) => stored == null ? null : held(stored)),
  );
  return (
    value: value,
    // `!live.hasValue` alone is not it: a fetch still in flight has answered
    // with nothing either way, and a screen drawing a skeleton must not be
    // told the device's memory is what it is drawing.
    fromCatalogue: !live.hasValue && value.hasValue,
  );
}

/// What an overlay answered with, and whether the device's memory is what
/// answered — see [storedSeriesOverlay], which is the one seam that needs
/// to say so.
typedef Overlaid<T> = ({AsyncValue<T> value, bool fromCatalogue});

/// The one rule for how a stored answer and a live fetch coexist.
///
/// **Live wins; otherwise stored data draws as data, not as loading;
/// otherwise the live error; otherwise loading.**
///
/// Written once and shared rather than open-coded per list, because the four
/// branches are the whole feature: getting the third one wrong loses the
/// offline empty states, and getting the second one wrong draws a shimmer
/// over shelves the device is holding.
///
/// Two things it has to get right that read like details and are not:
///
/// - **`hasValue`, not `isLoading`, is what "live wins" asks.** A refresh in
///   flight carries the answer it is refreshing, and falling through to the
///   catalogue there would swap the list under the person pulling it.
/// - **A catalogue still being read counts as loading**, never as an absence.
///   Otherwise a cold offline start draws its error state and replaces it
///   with the shelves one frame later. This is a fifth branch the issue's
///   four did not name, and it is deliberate: the alternative is not a
///   simpler rule but a visible flash.
AsyncValue<T> overlaid<T>(AsyncValue<T> live, AsyncValue<T?> stored) {
  if (live.hasValue) return live;
  final held = stored.value;
  if (held != null) return AsyncValue.data(held);
  if (stored.isLoading) return AsyncValue<T>.loading();
  if (live.hasError) return live;
  return AsyncValue<T>.loading();
}
