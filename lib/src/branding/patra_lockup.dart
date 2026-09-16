import 'package:flutter/material.dart';

import '../widgets/patra_wordmark.dart';
import 'patra_mark.dart';

/// The word beside the signature — the lockup every screen that names the app
/// draws: the home header, the two gate screens, and the about row in
/// Settings.
///
/// One definition rather than three Rows, for the reason [PatraWordmark] is
/// one. The word's height is a ratio of the signature's and the gap is
/// another ratio of the same, so two numbers that have to agree were living
/// in as many files as there were places to draw them, and stayed in step
/// only by being copied.
class PatraLockup extends StatelessWidget {
  const PatraLockup({super.key, required this.size, this.gapEm = _gapEm});

  /// The signature's size. The word is drawn at [PatraWordmark.markEm] of it.
  final double size;

  /// The gap between the two, in ems of the signature.
  ///
  /// The default everywhere but the gate screens, whose lockup is nearly
  /// twice the size: spacing that reads as one lockup at 22pt opens into a
  /// gulf when the same ratio is taken to 40pt, so the ratio falls as the
  /// lockup grows. What is being kept is that the two read as one thing.
  final double gapEm;

  static const _gapEm = 0.81;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PatraMark(height: size * PatraWordmark.markEm),
        SizedBox(width: size * gapEm),
        PatraWordmark(size: size),
      ],
    );
  }
}
