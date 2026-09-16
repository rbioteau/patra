import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../branding/patra_lockup.dart';
import '../theme.dart';

/// The lockup at the top of the two screens the app can open on — the picker
/// and the sign-in form.
///
/// The same two halves, in the same proportion, as the home header's: the
/// word beside the Latin signature. Shared rather than drawn twice because the
/// two gate screens are seen back to back, and spacing that drifted between
/// them would show.
class PatraMasthead extends StatelessWidget {
  const PatraMasthead({super.key, this.showTagline = true});

  /// Whether the line under the lockup says what Patra is.
  ///
  /// The sign-in form says it: someone typing an address may be meeting the
  /// app for the first time. The picker does not — it asks a question of its
  /// own there, and a device with faces on it is past being introduced.
  final bool showTagline;

  static const _size = 40.0;

  /// Tighter than [PatraLockup]'s default, and deliberately so rather than by
  /// drift: spacing that reads as one lockup at 22pt opens into a gulf when
  /// the same ratio is taken to 40pt. The word and the signature have to stay
  /// one thing at both sizes, which is the point being kept, not the number.
  static const _gateGapEm = 0.65;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PatraLockup(size: _size, gapEm: _gateGapEm),
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
