import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

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
