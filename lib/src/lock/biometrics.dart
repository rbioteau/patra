/// The device's own way of recognising its owner, behind an interface small
/// enough to have no opinion about which one it is.
///
/// Two methods, because two things are asked at two different moments: can
/// this device do it at all (which decides whether the unlock surface even
/// offers it), and please do it now. Everything else `local_auth` exposes —
/// which sensor, how many are enrolled — would only let a caller draw a
/// fingerprint where the device shows a face.
///
/// It is injected like the lock store's vault, and for the same reason: a
/// plugin has nothing behind it on a test binding, so a rule that had to go
/// through the real one could not be tested at all.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

abstract class Biometrics {
  /// Whether this device can be asked. False is the ordinary answer on a
  /// tablet with nothing enrolled, and it is never an error.
  Future<bool> available();

  /// Asks, and answers whether the person was recognised. [reason] is what
  /// the OS prompt says it is for.
  Future<bool> prompt(String reason);
}

/// The real one.
///
/// **Biometrics only, deliberately.** The alternative — letting the platform
/// fall back to the device's own passcode — would put the lock screen's PIN
/// in front of a profile, which is the wrong secret: on a family tablet every
/// person who shares it knows that one, and it is the very thing this lock
/// exists to be different from. The fallback here is the profile's own PIN,
/// which the surface behind the prompt is already showing.
///
/// Every call is guarded, and not out of habit: a device with no sensor, a
/// build with the plugin missing and a prompt the OS refuses to show all
/// arrive here as exceptions, and every one of them means the same thing to
/// the caller — this is not a way in, use the PIN.
class DeviceBiometrics implements Biometrics {
  const DeviceBiometrics();

  /// **Enrolled, not merely present.** `canCheckBiometrics` answers whether
  /// the *hardware* is there, which is true of a phone whose owner has never
  /// registered a finger — and the prompt then fails every time it is shown.
  /// What that would draw is a key on the pad that never works and never
  /// says why, since a refusal here is deliberately silent. The enrolment
  /// question is `getAvailableBiometrics`.
  @override
  Future<bool> available() async {
    try {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) return false;
      return (await auth.getAvailableBiometrics()).isNotEmpty;
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> prompt(String reason) async {
    try {
      return await LocalAuthentication().authenticate(
        localizedReason: reason,
        biometricOnly: true,
        // The prompt is not a purchase: a confirmation step after a face is
        // recognised would make the fast path slower than typing four digits,
        // which is the only reason to offer it.
        sensitiveTransaction: false,
      );
    } on Exception {
      return false;
    }
  }
}

/// A device that cannot be asked. Named rather than written as a stub in each
/// place that needs one — the picker and Settings both have to be testable
/// without a sensor, and so does a platform the plugin does not cover.
class NoBiometrics implements Biometrics {
  const NoBiometrics();

  @override
  Future<bool> available() async => false;

  @override
  Future<bool> prompt(String reason) async => false;
}

final biometricsProvider = Provider<Biometrics>(
  (ref) => const DeviceBiometrics(),
);
