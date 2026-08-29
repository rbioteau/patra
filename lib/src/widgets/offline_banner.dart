import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../auth/session.dart';
import '../theme.dart';

/// Shown wherever server data is displayed, once a request failed to reach
/// the server. Saved chapters stay readable, which is what the copy says.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(offlineProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: versoDanger.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(radiusCover),
        border: Border.all(color: versoDanger.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 18, color: versoDanger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l10n.offlineBanner, style: VersoText.metadata()),
          ),
        ],
      ),
    );
  }
}
