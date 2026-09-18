import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the OS says the app is doing: in the foreground, or not.
///
/// A provider rather than a `WidgetsBindingObserver` inside whatever listens
/// to it, because a test binding cannot drive a real background transition:
/// a test reports a state here and everything downstream answers exactly as
/// it would on a device, where `PatraApp` reports the real ones.
///
/// It opens at `resumed`, because the app is built before the platform has
/// said anything at all: one that assumed otherwise would pause a queue on
/// its own first frame.
final appLifecycleProvider =
    NotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
      AppLifecycleNotifier.new,
    );

class AppLifecycleNotifier extends Notifier<AppLifecycleState> {
  @override
  AppLifecycleState build() => AppLifecycleState.resumed;

  /// What the app's own observer saw. Not the setter itself: what the OS says
  /// is not something anything else may decide, and a platform repeats itself
  /// — `inactive` arrives more than once around one trip to the app switcher,
  /// and a repeat is not news.
  void report(AppLifecycleState state) {
    if (this.state != state) this.state = state;
  }
}
