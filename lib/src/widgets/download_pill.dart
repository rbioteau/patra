import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../downloads/downloads_provider.dart';
import '../downloads/downloads_service.dart';
import '../theme.dart';
import 'download_stop.dart';

/// Download control for one chapter: the word for what the copy is doing, and
/// the one tap there is to make on it.
///
/// The word is the **state** and the glyph is the **action**, because the two
/// are not the same fact: a copy "Downloading" is stopped by a tap, a copy
/// "Paused" is sent on by one. Worded in every state, never icon-only — Save ·
/// Waiting · Preparing · Downloading · Paused · Stopped · Could not finish —
/// and the copy's own progress drawn **inside** the pill as a ring around the
/// glyph.
///
/// A ring and not a bar, because a bar on a cover is reading progress
/// ([CoverProgressBar]) and a download's progress must never be read for it.
/// The shape says which of the two facts is in front of you before the colour
/// does.
///
/// The one state that is **not** a control is the copy that is here: "Saved"
/// is a mark, and taking a copy off the device is a swipe on the row it sits
/// in — never a tap on something whose whole message is that all is well.
class DownloadPill extends ConsumerWidget {
  const DownloadPill({super.key, required this.request});

  /// Metadata to store with the pages; its `bytes` is filled in on save.
  final SavedChapter request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // The whole record, and one watch: the pill is about every fact in it —
    // the state, the pages it has, and whether the server has said how many
    // there are — and a page landing on this chapter has to move the ring.
    // Another chapter's pages leave it alone, the record being the same
    // instance after every queue write.
    final record = ref.watch(downloadRecordProvider(request.chapterId));

    // A copy that is here is a mark, not a control. The copy it is drawn for
    // is the one `saved` on the record rather than the status: a refresh that
    // failed leaves the copy it was replacing intact.
    if (record?.saved != null) {
      return Tooltip(
        message: l10n.savedPill,
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
      );
    }

    final stop = DownloadStop.of(record?.status, l10n);
    if (stop != null) {
      // What stopped, in the word for the **tap** — Resume, Retry — because
      // that is what a reader does with a copy that is not moving, and the
      // ring where it stopped, because a copy that stopped keeps every page it
      // has. Which stop it was is the row's own line and the colour here: the
      // glyph and the fill say a failure from a pause, and nothing has to be
      // read to tell them apart.
      return _Pill(
        label: stop.action,
        icon: stop.icon,
        color: stop.color,
        ring: record?.progress,
        onTap: () =>
            ref.read(downloadsProvider.notifier).retry(request.chapterId),
      );
    }

    if (record?.isInFlight ?? false) {
      // The ring is the copy's own progress in every state, so a copy waiting
      // its turn draws what it already has: a resumed copy comes back queued
      // with half its pages, and an empty ring would deny them. What it must
      // not do is **turn**: turning is the drawing for a copy whose page count
      // has not come back yet, which is a state of its own — and a ring stuck
      // at zero for those seconds says the fetch has stalled.
      final preparing =
          record!.status == DownloadQueueStatus.downloading &&
          record.totalPages == 0;
      return _Pill(
        label: _runningWord(l10n, record),
        icon: Icons.pause,
        color: patraOffline,
        ring: record.progress,
        spinning: preparing,
        tooltip: l10n.pauseDownload(request.label),
        onTap: () =>
            ref.read(downloadsProvider.notifier).pause(request.chapterId),
      );
    }

    return _Pill(
      label: l10n.savePill,
      icon: Icons.save_alt,
      color: patraTextMuted,
      onTap: () => ref.read(downloadsProvider.notifier).save(request),
    );
  }

  /// What a copy on its way says: which of the three moments of a fetch it is
  /// in. Queued and preparing are not one word, because one of them is not
  /// happening yet and the other is — the reader watching a batch wait on a
  /// count of pages has to be able to tell them apart.
  String _runningWord(AppLocalizations l10n, DownloadQueueRecord record) {
    if (record.status == DownloadQueueStatus.queued) {
      return l10n.downloadsWaiting;
    }
    return record.totalPages == 0
        ? l10n.downloadsPreparing
        : l10n.downloadsInProgress;
  }
}

/// The copy's own progress, as a **ring** around the glyph that does the one
/// thing there is to do with it.
///
/// Three drawings. A copy that has pages to fetch and a total to be a fraction
/// of fills; one merely queued draws the track alone, because it is not
/// happening yet and a turning ring there would be the app saying something
/// is; and one whose total the server has not given turns, because the request
/// is out and there is nothing to be a fraction of.
///
/// The ring is the offline blue in every state — it is a download's progress,
/// the blue every download wears — and the **glyph** is what takes the colour
/// of the state, which is what keeps a failure in danger.
class _RingedGlyph extends StatelessWidget {
  const _RingedGlyph({
    required this.icon,
    required this.color,
    this.value,
    this.spinning = false,
  });

  final IconData icon;

  /// What the glyph wears, which is the state's colour and not the ring's.
  final Color color;

  /// 0..1, or null where the ring turns instead of filling.
  final double? value;
  final bool spinning;

  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: _size,
            height: _size,
            child: CircularProgressIndicator(
              value: spinning ? null : value,
              strokeWidth: 2,
              backgroundColor: patraTrack,
              color: patraOffline,
            ),
          ),
          Icon(icon, size: 12, color: color),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.ring,
    this.spinning = false,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// The copy's progress, or null where there is no copy of this chapter on
  /// its way and nothing to be a fraction of.
  final double? ring;
  final bool spinning;

  /// What the tap does, where the word alone does not say it. A tooltip is a
  /// semantics **hint**: the reader hears the state, then what touching it
  /// will do.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final pill = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusPill),
      child: Padding(
        // **The tap area, and nothing else.** Eight either side and four above
        // and below the content make a 24pt ring and its word a 32pt target
        // with no box drawn round them.
        //
        // There were two boxes before this: a 1.5pt outline, from the
        // prototype's metrics, and then a fill in the state's colour. Either
        // was a third shape on a row that already carries a cover, a title and
        // the ring — and a chip is what made a *status* read as a button, the
        // confusion this whole control has been unpicking. What says "control"
        // here is the word in the state's colour at w600, and a tap area does
        // not have to be painted to be one.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ring != null || spinning)
              _RingedGlyph(
                icon: icon,
                color: color,
                value: ring,
                spinning: spinning,
              )
            else
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
    if (tooltip == null) return pill;
    return Tooltip(message: tooltip!, child: pill);
  }
}
