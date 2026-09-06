import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../features/launch/launch_animation.dart';
import '../theme.dart';
import 'patra_frond.dart';
import 'patra_wordmark.dart';

/// The lockup at the top of the two screens the app can open on — the picker
/// and the sign-in form — and the place the launch animation lands.
///
/// Both halves are slots, and the wordmark being one is the point: it is
/// drawn at the splash's own size, so the word does not shrink into place, it
/// travels — the splash's lockup simply becomes the screen's. The frond is
/// the same five-blade mark as the header's, in the same proportion to the
/// word beside it.
///
/// Shared rather than drawn twice, for the reason [PatraWordmark] is one
/// definition: the animation lands its own lockup on whichever of these
/// screens is up, and spacing that drifted between them would show as a shift
/// at the one moment the two are compared directly.
class PatraMasthead extends StatelessWidget {
  const PatraMasthead({super.key, this.showTagline = true});

  /// Whether the line under the lockup says what Patra is.
  ///
  /// The sign-in form says it: someone typing an address may be meeting the
  /// app for the first time. The picker does not — it asks a question of its
  /// own there, and a device with faces on it is past being introduced.
  final bool showTagline;

  static const _size = 40.0;

  /// The header's lockup at this screen's scale: the mark stands a little
  /// taller than the word so the five blades stay open.
  static const _markHeight = _size * 24 / 22;

  /// The gap is **tighter** here than the header's 0.81em, and deliberately so
  /// rather than by drift: spacing that reads as one lockup at 22pt opens into
  /// a gulf when the same ratio is scaled to 40pt. The mark and the word have
  /// to stay one thing at both sizes, which is the point being kept, not the
  /// number.
  static const _gap = _size * 0.65;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LaunchLogoSlot(child: PatraFrond(height: _markHeight)),
            SizedBox(width: _gap),
            LaunchWordmarkSlot(child: PatraWordmark(size: _size)),
          ],
        ),
        if (showTagline) ...[
          const SizedBox(height: 8),
          Text(
            l10n.appTagline,
            style: PatraText.metadata(size: 13).copyWith(height: 1.5),
          ),
        ],
      ],
    );
  }
}
