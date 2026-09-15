import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../branding/patra_launch.dart';

/// Whether the app is being *opened* rather than merely built again.
///
/// A handover builds the whole tree a second time — entering another profile
/// constructs a new `SessionScope` — and the animation is mounted inside it,
/// so without this the mark would assemble itself a second time over someone
/// who has just tapped their own face. Nor is a resume a launch: the widget
/// takes itself out of the tree when it is done and is never rebuilt.
final isLaunchProvider = Provider<bool>((ref) => true);

/// The app's launch animation, from the brand kit.
///
/// It wraps the **whole app** from `MaterialApp.builder` rather than being a
/// route, so the app is mounted, laid out and fetching underneath from the
/// first frame: what fades up at the end is the real screen rather than a
/// skeleton appearing behind it.
class LaunchAnimation extends ConsumerStatefulWidget {
  const LaunchAnimation({super.key, required this.child, this.play = true});

  final Widget child;

  /// Whether there is a launch to animate. False where the app is being
  /// built again rather than opened — see [isLaunchProvider] — and the app is
  /// then handed over bare, with no frame of ink in front of it.
  final bool play;

  @override
  ConsumerState<LaunchAnimation> createState() => _LaunchAnimationState();
}

class _LaunchAnimationState extends ConsumerState<LaunchAnimation> {
  @override
  Widget build(BuildContext context) {
    return PatraLaunch(
      enabled: widget.play && ref.watch(isLaunchProvider),
      child: widget.child,
    );
  }
}
