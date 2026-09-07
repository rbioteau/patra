import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is not among what the main library exports, and this is the one
// place in the app that needs to name the type rather than write a literal.
import 'package:flutter_riverpod/misc.dart' show Override;

import 'auth/session.dart';
import 'features/launch/launch_animation.dart';

/// The app, on a container that lasts exactly as long as the profile it is
/// read as: entering somebody else builds the whole thing again.
///
/// It sits here rather than in `auth/` because it is app-level wiring like
/// `app.dart` and `routes.dart`, and reaches into a feature the way those do:
/// the app it rebuilds includes the launch animation, which has to be told
/// that a handover is not a launch.
///
/// The teardown is deliberate rather than selective, and that is the whole
/// point of doing it here. A list of profile-scoped providers to invalidate
/// keeps growing — two were added while this was being written — and a
/// forgotten entry does not show up as a stale number but as one person
/// seeing another person's library. Nothing is listed here, so nothing can be
/// left off: what survives a handover is only what is handed to it, which is
/// [overrides] (what the *device* owns) and the profiles themselves.
///
/// It is **entering** a second profile that starts the app over, not leaving
/// the first. Two reasons, and both are about the frame in between. A session
/// that has merely ended leaves a shell whose screens are on their way out
/// and still reading through [kavitaClientProvider]; rebuilding under them is
/// how they come to ask a container with no session for a client. And there
/// is nothing to hide in the meantime — the picker draws from the profile
/// list alone, so the only screens that could show the previous person's
/// library are gone before it appears.
///
/// Returning to the *same* profile is therefore not a handover at all: it
/// keeps its container, and its shelves are already there.
class SessionScope extends StatefulWidget {
  const SessionScope({
    super.key,
    required this.auth,
    required this.child,
    this.overrides = const [],
  });

  /// What the app opens in: read from the keychain before `runApp` and put
  /// through [AuthState.atLaunch] there.
  final AuthState auth;

  /// Everything else resolved before the app started, re-applied to every
  /// container this builds — so what they have in common is what the device
  /// owns rather than what a person does.
  ///
  /// [initialAuthStateProvider] and [isLaunchProvider] are this widget's own
  /// to supply and must not be among them: overriding a provider twice in one
  /// container is an error.
  final List<Override> overrides;

  final Widget child;

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  late ProviderContainer _container;
  ProviderSubscription<AuthState>? _watching;

  /// Which profile this container has been read as, kept even once that
  /// session has ended: a container that has served somebody is spent, and
  /// only somebody else's arrival spends it.
  String? _served;

  @override
  void initState() {
    super.initState();
    // The app started here, so this is the container that gets the splash.
    _container = _open(widget.auth, launching: true);
  }

  /// A container seeded with [auth], and the subscription that watches for
  /// somebody else arriving in it.
  ProviderContainer _open(AuthState auth, {required bool launching}) {
    final container = ProviderContainer(
      overrides: [
        ...widget.overrides,
        initialAuthStateProvider.overrideWithValue(auth),
        isLaunchProvider.overrideWithValue(launching),
      ],
    );
    _served = auth.active?.id;
    _watching = container.listen(authProvider, (_, next) => _entered(next));
    return container;
  }

  /// Called on every move the auth state makes, and interested in exactly
  /// one of them: somebody who is not who this container was built for has
  /// become the active profile.
  void _entered(AuthState next) {
    final entering = next.active?.id;
    if (entering == null || entering == _served) return;
    if (_served == null) {
      // The first profile this container serves. A cold start on a shared
      // device arrives with nobody active, so this is the ordinary way in
      // and not a handover — there is nothing here yet to tear down, and
      // tearing down anyway would restart the splash the app is still
      // playing.
      _served = entering;
      return;
    }
    _restart(next);
  }

  void _restart(AuthState next) {
    final spent = _container;
    _watching?.close();
    // Not launching: the splash is a launch and this is a handover.
    setState(() => _container = _open(next.handedOver, launching: false));
    // Disposed after the frame that stops reading it: the app above is being
    // built again on the new container, and the widgets coming down are
    // still holding this one until it has been.
    WidgetsBinding.instance.addPostFrameCallback((_) => spent.dispose());
  }

  @override
  void dispose() {
    _watching?.close();
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    // Keyed on the container, so this really is the app being built again
    // rather than a container swapped in under it. Two things need that: the
    // scope's own state registers itself with the container's scheduler in
    // `initState`, so a new container would otherwise never be handed a
    // Flutter frame — and every widget below would keep the state it holds
    // for the previous person, which is what the frame this exists to
    // prevent is made of.
    key: ObjectKey(_container),
    container: _container,
    child: widget.child,
  );
}
