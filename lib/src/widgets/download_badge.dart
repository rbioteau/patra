import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../downloads/downloads_provider.dart';
import '../downloads/downloads_service.dart';
import '../theme.dart';
import 'download_stop.dart';

/// Where on a cover the badge is laid, which decides what it is drawn on.
///
/// A row's cover is small, so its badge hangs off the **corner**, half over
/// the page behind — drawn on a disc of the page's own colour, so it reads as
/// cut out of the cover. A tile's cover is large enough to carry it inside,
/// on a scrim of the offline blue's night that reads on any artwork.
enum DownloadBadgePlacement { rowCorner, tileCorner }

/// What the device has of one chapter, as a mark on its cover — never a
/// control: a check where the copy is here, a ring while one is on its way
/// or stopped, and **nothing** where there is no copy at all.
///
/// A mark and not the pill that used to sit at the end of every row. A pill
/// on each of forty rows saying "Save" is forty offers nobody asked for;
/// saving is a gesture (a swipe on one row, a long-press to select several)
/// and what is left at rest is only what is true.
///
/// A **ring**, for the reason the pill drew one: a bar on a cover is reading
/// progress ([CoverProgressBar]), and a download's progress must never be read
/// for it. The ring is the offline blue while the copy is coming or paused,
/// and takes the danger colour of a copy that stopped without being asked.
class DownloadBadge extends ConsumerWidget {
  const DownloadBadge({
    super.key,
    required this.chapterId,
    required this.placement,
  });

  final int chapterId;
  final DownloadBadgePlacement placement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final record = ref.watch(downloadRecordProvider(chapterId));
    if (record == null) return const SizedBox.shrink();
    final tile = placement == DownloadBadgePlacement.tileCorner;

    // The copy the badge is about is the one `saved` on the record rather
    // than the status: a refresh that failed leaves the copy it was
    // replacing intact, and that copy is still here.
    if (record.saved != null) {
      return Tooltip(
        message: l10n.savedPill,
        child: tile
            ? _Disc(
                size: 22,
                color: patraOfflineScrim,
                child: const Icon(Icons.check, size: 13, color: patraOffline),
              )
            : Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: patraOffline,
                  shape: BoxShape.circle,
                  border: Border.all(color: patraBg, width: 2),
                ),
                child: const Icon(Icons.check, size: 12, color: patraBg),
              ),
      );
    }

    final stop = DownloadStop.of(record.status, l10n);
    final preparing =
        record.status == DownloadQueueStatus.downloading &&
        record.totalPages == 0;
    final ringSize = tile ? 16.0 : 18.0;
    return Tooltip(
      message: stop?.state ?? l10n.downloadsInProgress,
      child: _Disc(
        size: 22,
        color: tile ? patraOfflineScrim : patraBg,
        child: SizedBox(
          width: ringSize,
          height: ringSize,
          child: CircularProgressIndicator(
            // Turning only while the server has not said how many pages
            // there are — a ring stuck at nought then says the fetch stalled.
            value: preparing ? null : record.progress,
            strokeWidth: 3,
            backgroundColor: patraTrack,
            color: stop?.color ?? patraOffline,
          ),
        ),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.color, required this.child});

  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: child,
  );
}

/// The circle a selectable entry wears while the screen is selecting: filled
/// in the offline blue with a check where it is selected — a selection here
/// is always for a download — and an empty ring where it is not.
///
/// [onArt] is for the circle laid over a cover rather than beside it: the
/// empty ring is then drawn in the page's ink over a faint scrim, since an
/// outline tuned for a flat panel disappears on artwork.
class SelectionMark extends StatelessWidget {
  const SelectionMark({super.key, required this.selected, this.onArt = false});

  final bool selected;
  final bool onArt;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected
          ? patraOffline
          : onArt
          ? patraOnArtShade
          : null,
      border: selected
          ? null
          : Border.all(
              color: onArt ? patraOnArtOutline : patraOutline,
              width: 2,
            ),
    ),
    child: selected ? const Icon(Icons.check, size: 16, color: patraBg) : null,
  );
}
