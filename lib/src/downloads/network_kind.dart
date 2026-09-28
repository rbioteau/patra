import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device is reaching the network over mobile data right now,
/// asked of the platform when a download is about to start.
///
/// Mobile data is only what the device has **and nothing better**: a phone
/// on Wi-Fi keeps its cellular link up, and a download there costs no plan.
/// Where the platform cannot say, the answer is no — a question asked on
/// every tap because the device could not be read is a nag, not a warning.
/// Read on the device and sent nowhere (`site/privacy.html`).
typedef OnMobileData = Future<bool> Function();

Future<bool> _fromPlatform() async {
  try {
    final links = await Connectivity().checkConnectivity();
    return links.contains(ConnectivityResult.mobile) &&
        !links.contains(ConnectivityResult.wifi) &&
        !links.contains(ConnectivityResult.ethernet);
  } on Exception {
    return false;
  }
}

/// A seam rather than a call, so a test says which network it is on.
final onMobileDataProvider = Provider<OnMobileData>((ref) => _fromPlatform);
