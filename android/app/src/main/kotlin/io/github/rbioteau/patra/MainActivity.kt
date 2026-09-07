package io.github.rbioteau.patra

import io.flutter.embedding.android.FlutterFragmentActivity

// A FragmentActivity rather than Flutter's template FlutterActivity: the
// biometric prompt in front of a locked profile is androidx's BiometricPrompt,
// which is a fragment and can only be shown by one. Nothing else in the app
// depends on the difference, and local_auth fails at runtime without it — the
// prompt simply never appears, which reads as a device with no sensor.
class MainActivity : FlutterFragmentActivity()
