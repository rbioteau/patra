import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../keychain.dart';

/// Whether a download may start on mobile data without asking first.
///
/// Off by default: the app asks before each download away from Wi-Fi, and
/// the question's "Don't ask again" is what turns it on — as does the switch
/// under Settings › Storage, which is also the way back. The **device's**, not
/// a person's: the plan a download spends is the SIM's in this device,
/// whoever is reading on it. A row of the device's own in the keychain, like
/// [BatchSizeHintStore]'s, read the first time a download or the setting
/// asks.
class MobileDataDownloads extends AsyncNotifier<bool> {
  static const _key = 'downloadOnMobileData';

  @override
  Future<bool> build() async {
    try {
      return await ref.watch(keychainProvider).read(_key) == 'true';
    } on Exception {
      // Asking is the safe answer where the keychain cannot say.
      return false;
    }
  }

  Future<void> set(bool allowed) async {
    state = AsyncData(allowed);
    final keychain = ref.read(keychainProvider);
    try {
      allowed
          ? await keychain.write(_key, 'true')
          : await keychain.delete(_key);
    } on Exception {
      // Kept for the session; the next launch asks again, which costs a tap.
    }
  }
}

final mobileDataDownloadsProvider =
    AsyncNotifierProvider<MobileDataDownloads, bool>(MobileDataDownloads.new);
