import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../downloads/downloads_provider.dart';
import '../downloads/downloads_service.dart';
import '../theme.dart';

/// Download control for one chapter, in three worded states (never icon-only):
/// Save → percentage (tap cancels) → Saved (tap removes).
class SavePill extends ConsumerWidget {
  const SavePill({super.key, required this.request});

  /// Metadata to store with the pages; its `bytes` is filled in on save.
  final SavedChapter request;

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: patraSurface,
        title: Text(
          l10n.removeDownloadConfirm(request.label),
          style: PatraText.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.removeDownload,
              style: PatraText.body(color: patraDanger),
            ),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(downloadsProvider.notifier).remove(request.chapterId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Each of the three states is watched as the one fact it is about, and
    // the percentage as the one number that moves: a page landing on any
    // other chapter — or on this one — no longer hands every row on the
    // screen a new state to rebuild from.
    final progress = ref.watch(
      downloadRecordProvider(request.chapterId).select(
        (record) => record?.isInFlight ?? false ? record?.progress : null,
      ),
    );
    final saved = ref.watch(
      downloadMembershipProvider.select(
        (m) => m.saved.contains(request.chapterId),
      ),
    );
    final retryable = ref.watch(
      downloadsProvider.select(
        (state) =>
            (state.value?.failed.contains(request.chapterId) ?? false) ||
            (state.value?.interrupted.contains(request.chapterId) ?? false),
      ),
    );

    final l10n = AppLocalizations.of(context);

    if (progress != null) {
      return _Pill(
        label: l10n.downloadingPct((progress * 100).round()),
        icon: Icons.arrow_downward,
        color: patraOffline,
        onTap: () =>
            ref.read(downloadsProvider.notifier).cancel(request.chapterId),
      );
    }
    if (saved) {
      // Once saved there is nothing left to explain: the word gives its room
      // back to the chapter title, and the state stays legible as a mark.
      return Tooltip(
        message: l10n.savedPill,
        child: InkWell(
          onTap: () => _confirmRemove(context, ref, l10n),
          borderRadius: BorderRadius.circular(radiusPill),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: patraOffline.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 16, color: patraOffline),
          ),
        ),
      );
    }
    // A failed download says so and offers the retry, instead of quietly
    // reverting to "Save" as if nothing had happened.
    return _Pill(
      label: retryable ? l10n.retry : l10n.savePill,
      icon: retryable ? Icons.refresh : Icons.save_alt,
      color: retryable ? patraDanger : patraTextMuted,
      onTap: () => ref.read(downloadsProvider.notifier).save(request),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusPill),
      child: Container(
        // Prototype metrics for the worded states: 32 tall, never narrower
        // than 72, 1.5 border.
        constraints: const BoxConstraints(minHeight: 32, minWidth: 72),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radiusPill),
          border: Border.all(width: 1.5, color: color.withValues(alpha: .55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: PatraText.metadata(
                color: color,
                size: 11.5,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
