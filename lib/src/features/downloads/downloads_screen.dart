import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/models.dart';
import '../../downloads/downloads_provider.dart';
import '../../downloads/downloads_service.dart';
import '../../auth/session.dart';
import '../../format.dart';
import '../../theme.dart';
import '../../widgets/cover.dart';
import '../../widgets/download_pill.dart';
import '../../widgets/download_stop.dart';
import '../../widgets/read_mark.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloadsTitle)),
      body: SafeArea(
        top: false,
        child: ref
            .watch(downloadsProvider)
            .when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: patraOffline),
              ),
              error: (error, _) => Center(
                child: Text(
                  '$error',
                  style: PatraText.body(color: patraTextMuted),
                ),
              ),
              data: (state) {
                // The tab shows the lot, so a queue with nothing finished yet
                // is not the empty state: it is work the reader is waiting on.
                if (state.records.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(gutter * 1.5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.download_outlined,
                            color: patraOffline,
                            size: 28,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.emptyDownloads,
                            textAlign: TextAlign.center,
                            style: PatraText.body(color: patraTextMuted),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                // Every child below is a `const` widget that watches one
                // provider of its own, so a page landing — which hands this
                // build a new state — rebuilds the list and nothing in it.
                // The rows that are not moving are left alone, which is the
                // whole point of the per-chapter providers.
                return ListView(
                  padding: EdgeInsets.only(bottom: sectionGap),
                  children: [
                    _StorageMeterCard(),
                    _QueueSection(),
                    _PausedSection(),
                    _PendingSection(),
                    _SavedSection(),
                  ],
                );
              },
            ),
      ),
    );
  }
}

/// The storage meter and the tally under it, reading the two numbers it is
/// about and nothing else.
///
/// Kept apart from the screen's own build so a page landing leaves it alone:
/// what it reports is how much saved reading is on the device, which a
/// download changes only when it finishes.
class _StorageMeterCard extends ConsumerWidget {
  const _StorageMeterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(
      downloadsProvider.select(
        (state) => (
          bytes: state.value?.totalBytes ?? 0,
          chapters: state.value?.saved.length ?? 0,
        ),
      ),
    );
    return _StorageMeter(bytes: storage.bytes, chapters: storage.chapters);
  }
}

/// The copies on the device, in the order the tab lists them.
///
/// What it watches is the list of ids, so a row is rebuilt when the copy it
/// draws changes and not when another chapter's pages land: each row reads
/// its own copy, and this list is left alone.
///
/// It has a **heading of its own**, and that is not decoration: it is the last
/// section of the tab and the only one that is not a state, so without it these
/// rows read as belonging to the section above — which is about copies that
/// stopped, and is not what a finished copy is. Muted, because every other
/// heading here names a state and wears that state's colour.
class _SavedSection extends ConsumerWidget {
  const _SavedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(savedChapterIdsProvider);
    return _section(
      heading: AppLocalizations.of(context).downloadsSavedSection,
      rows: [for (final id in ids) _SavedRow(key: ValueKey(id), chapterId: id)],
    );
  }
}

class _StorageMeter extends StatelessWidget {
  const _StorageMeter({required this.bytes, required this.chapters});

  final int bytes;
  final int chapters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(gutter, gutter, gutter, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: patraSurface,
        borderRadius: BorderRadius.circular(radiusCard),
        border: Border.all(color: patraBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: patraOffline.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(radiusThumb),
            ),
            child: const Icon(
              Icons.sd_storage_outlined,
              color: patraOffline,
              size: 19,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.storageUsed(formatBytes(l10n, bytes)),
                  style: PatraText.rowTitle(color: patraOffline),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.downloadedChapters(chapters),
                  style: PatraText.metadata(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The copies still being fetched, with each one's own progress and its own
/// control.
///
/// One control per copy, and it is the pill's: a tap pauses it where it stands
/// and keeps every page it has. Dropping one is the smaller decision — a batch
/// is several chapters the reader asked for in one tap, and a pause is not a
/// destruction — so the bin beside the pill is what takes it off the device.
class _QueueSection extends ConsumerWidget {
  const _QueueSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final membership = ref.watch(downloadMembershipProvider);
    // Where the batch stands, on the heading's own line and at its trailing
    // edge: it is an answer about the section, not another row above it, and
    // a line of its own made the heading look like it belonged to the meter
    // instead. Null where there is nothing left to report — a count of zero
    // of nothing is a report about a batch that is over.
    final summary = ref.watch(batchSummaryProvider);
    return _section(
      heading: l10n.downloadsQueueSection,
      color: patraOffline,
      trailing: summary == null
          ? null
          : Text(
              l10n.downloadsBatchSummary(
                summary.done,
                summary.total,
                (summary.progress * 100).round(),
              ),
              style: PatraText.metadata(color: patraOffline),
            ),
      rows: [
        for (final chapterId in membership.inFlight)
          _CopyRow(chapterId: chapterId),
      ],
    );
  }
}

/// One copy that is not on the device yet — being fetched, paused, or waiting
/// to be given another go — with the tap that acts on it and the bin that
/// takes it off the device.
///
/// One row for all three, because they are one thing seen at three moments:
/// the heading above says which section it is in, and the pill at its trailing
/// edge says which state it is in and what the tap will do with it.
class _CopyRow extends ConsumerWidget {
  const _CopyRow({required this.chapterId});

  final int chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final request = ref.watch(
      downloadRecordProvider(chapterId).select((record) => record?.request),
    );
    if (request == null) return const SizedBox.shrink();
    // What this copy stopped as, where it stopped at all: the pill's own word
    // is the **action** — Resume, Retry — so the row is what says which stop
    // this was, and a failure and a process that died are deliberately not one
    // fact.
    final stop = DownloadStop.of(
      ref.watch(
        downloadRecordProvider(chapterId).select((record) => record?.status),
      ),
      l10n,
    );
    final tablet = isTabletLayout(context);
    // A copy of a volume with no chapter breakdown was stored before the
    // label was fixed, and is named after Kavita's sentinel: it names
    // nothing, so the row leads with the series alone.
    final title = request.resolvedTitle;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: gutter,
        vertical: tablet ? 9 : 6,
      ),
      child: Row(
        children: [
          _CopyCover(request: request),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.seriesName.isEmpty ? title : request.seriesName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PatraText.rowTitle(size: tablet ? 15 : 13.5),
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PatraText.metadata(size: tablet ? 12 : 11),
                  ),
                ],
                // Which stop this was, in the colour that state wears: the
                // pill beside it says what the tap does, and this says what
                // happened.
                if (stop != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    stop.state,
                    style: PatraText.metadata(
                      size: tablet ? 12 : 11,
                      color: stop.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // The state and the tap in one control, the progress as the ring
          // inside it: a copy's own progress is a ring everywhere, so this row
          // is read at its trailing edge rather than down a second column.
          DownloadPill(request: request),
          const SizedBox(width: 4),
          // The same bin the saved row carries, and the same word: taking a
          // copy off the device is one act, finished or not.
          IconButton(
            tooltip: l10n.removeDownload,
            icon: const Icon(Icons.delete_outline, size: 20),
            color: patraTextMuted,
            onPressed: () =>
                ref.read(downloadsProvider.notifier).remove(chapterId),
          ),
        ],
      ),
    );
  }
}

/// Fetched from the server, as the row's own cover is, and filed under the
/// shared cache key, so a chapter being fetched and the same chapter already
/// on the device are one picture on the disk rather than two.
///
/// **Nothing is drawn on it.** Its bottom edge belongs to the reading progress
/// a cover carries everywhere else (`CoverProgressBar`), and the download's own
/// progress is the ring inside the pill — the shape says which of the two facts
/// is in front of you, and a cover wearing both would say neither.
class _CopyCover extends ConsumerWidget {
  const _CopyCover({required this.request});

  /// The copy not yet on the device, which names the series and the chapter
  /// the cover belongs to.
  final SavedChapter request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(kavitaClientProvider);
    final tablet = isTabletLayout(context);
    return SizedBox(
      width: tablet ? rowCoverWidthTablet : rowCoverWidth,
      height: tablet ? rowCoverHeightTablet : rowCoverHeight,
      child: CoverImage(
        url: client.chapterCoverUrl(request.chapterId),
        headers: client.imageHeaders,
        seriesId: request.seriesId,
        seriesName: request.seriesName,
        radius: radiusThumb,
      ),
    );
  }
}

/// A section of the tab: the word above it, in the colour that word wears, and
/// the rows under it.
///
/// Every section on this screen is the same shape — the app's gutter, the
/// section gap, a label, then its rows — and four of them drew it one padding
/// at a time apart. What a section decides for itself is its heading, its
/// colour and which copies it lists, and that is all it passes.
///
/// It takes rows rather than ids because a section watches
/// `downloadMembershipProvider` **whole** and reads the one set it needs: that
/// value is compared by content, where a `select` returning a bare `Set`
/// answers "changed" on every page — the very trap the membership exists to
/// avoid, and the reason a page landing must not rebuild the world.
Widget _section({
  required String heading,
  Color? color,
  Widget? trailing,
  required List<Widget> rows,
}) => rows.isEmpty
    ? const SizedBox.shrink()
    : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, sectionGap, gutter, 8),
            child: SectionLabel(heading, color: color, trailing: trailing),
          ),
          ...rows,
        ],
      );

/// Copies stopped deliberately, waiting for a tap to send them on.
///
/// Blue, and a section of its own rather than a line in the one below: a pause
/// is not a failure, and one of these is the reader's own doing — announcing it
/// in the same breath, under a heading in danger, would be the app telling them
/// something went wrong when they are the one who stopped it.
class _PausedSection extends ConsumerWidget {
  const _PausedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(downloadMembershipProvider);
    return _section(
      heading: AppLocalizations.of(context).downloadsPausedSection,
      color: patraOffline,
      rows: [
        for (final chapterId in membership.paused)
          _CopyRow(chapterId: chapterId),
      ],
    );
  }
}

/// Copies that stopped **without being asked** — a failure, or a process that
/// died under them — which stay listed with the tap that starts them again
/// instead of living in memory and disappearing.
///
/// A failure seen from anywhere but the series screen, or after a restart, is
/// a failure the reader never saw — so it is named here, in the one tab that is
/// about what is on the device, and it is named in danger because it is the one
/// thing in this tab nobody chose.
class _PendingSection extends ConsumerWidget {
  const _PendingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(downloadMembershipProvider);
    return _section(
      heading: AppLocalizations.of(context).downloadsPendingSection,
      color: patraDanger,
      rows: [
        for (final chapterId in membership.pending)
          _CopyRow(chapterId: chapterId),
      ],
    );
  }
}

class _SavedRow extends ConsumerWidget {
  const _SavedRow({super.key, required this.chapterId});

  final int chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Its own copy: a page landing on another chapter leaves this row alone,
    // and reading progress mirrored into this one redraws only this row.
    final chapter = ref.watch(savedChapterProvider(chapterId));
    if (chapter == null) return const SizedBox.shrink();
    final dir = ref.watch(chapterDirProvider(chapterId)).value;
    // The same row the series screen shows, and it grows the same way.
    final tablet = isTabletLayout(context);
    // What the server counts now, where that is not what this copy was made
    // with: the number the copy is out of step with, and the one a refresh
    // stores it again by.
    final recounted = chapter.serverPages;
    final offline = ref.watch(offlineProvider);

    return InkWell(
      // Resume where the reader left off: opening at page 0 would post
      // that back as the new progress and lose the reader's place.
      onTap: () => context.push(
        '/reader/${chapter.chapterId}'
        '${chapter.isRead ? '' : '?page=${chapter.pagesRead}'}',
      ),
      child: ReadRail(
        read: chapter.isRead,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: gutter,
            vertical: tablet ? 9 : 6,
          ),
          child: Row(
            children: [
              // The first stored page doubles as the thumbnail — or a book's
              // cover, kept with it: no server needed.
              SizedBox(
                width: tablet ? rowCoverWidthTablet : rowCoverWidth,
                height: tablet ? rowCoverHeightTablet : rowCoverHeight,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radiusThumb),
                  child: _LocalThumb(chapter: chapter, dir: dir),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // The work leads; the volume is the detail underneath.
                    Text(
                      chapter.seriesName.isEmpty
                          ? chapter.title
                          : chapter.seriesName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PatraText.rowTitle(size: tablet ? 15 : 13.5),
                    ),
                    if (chapter.seriesName.isNotEmpty &&
                        chapter.title.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        chapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PatraText.metadata(size: tablet ? 12 : 11),
                      ),
                    ],
                    const SizedBox(height: 3),
                    // The same line and the same words the series screen's
                    // rows carry, with the copy's own size after them — in
                    // the muted tone, because how big a file is says nothing
                    // about reading progress.
                    PageCountLine(
                      pages: chapter.pages,
                      read: chapter.isRead,
                      size: tablet ? 12 : 11,
                      trailing: formatBytes(l10n, chapter.bytes),
                    ),
                    // Progress is what tells you which volumes are done with
                    // and can go.
                    // A copy keeps the pagination it was made with (ADR-0009),
                    // so the count the server gives now is a fact about it:
                    // where the two disagree the copy says so, and is offered
                    // for another go — never silently refetched, and never
                    // silently left to resume at the wrong page.
                    if (recounted != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.copyOutOfDate(recounted),
                        style: PatraText.metadata(
                          size: tablet ? 12 : 11,
                          color: patraDanger,
                        ),
                      ),
                      // Only where it can be answered: storing a copy again is
                      // the server's pages, and there are none without one.
                      if (!offline) ...[
                        const SizedBox(height: 7),
                        _RefreshCopy(chapter: chapter),
                      ],
                    ],
                    if (!chapter.isRead && chapter.progress > 0) ...[
                      const SizedBox(height: 7),
                      _CopyProgress(
                        value: chapter.progress,
                        color: patraAccent,
                        width: 180,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.removeDownload,
                icon: const Icon(Icons.delete_outline, size: 20),
                color: patraTextMuted,
                onPressed: () async {
                  if (await _confirmRemove(context, l10n, chapter.label)) {
                    await ref
                        .read(downloadsProvider.notifier)
                        .remove(chapter.chapterId);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Asked before a copy is deleted, naming the copy: what is about to go has
  /// to be said before it goes, since nothing can reach these files after.
  Future<bool> _confirmRemove(
    BuildContext context,
    AppLocalizations l10n,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: patraSurface,
        title: Text(l10n.removeDownloadConfirm(title), style: PatraText.body()),
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
    return confirmed ?? false;
  }
}

/// The refresh a copy out of step with the server is offered: stored again,
/// with the pages the server counts now.
///
/// Worded rather than a glyph, and of a width of its own — a control that
/// grew with the row would stop reading as a control. `patraOffline`, which
/// is the token for downloads: making a copy again is one.
class _RefreshCopy extends ConsumerWidget {
  const _RefreshCopy({required this.chapter});

  final SavedChapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Only this chapter's record, and only the part of it that changes as
    // pages land: a refresh in progress on one copy is not a reason to
    // rebuild every other row on the screen.
    final stored = ref.watch(
      downloadRecordProvider(chapter.chapterId).select(
        (record) => record?.isInFlight ?? false ? record?.progress : null,
      ),
    );

    if (stored != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: patraOffline,
              value: stored == 0 ? null : stored,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.refreshingCopy,
            style: PatraText.metadata(color: patraOffline),
          ),
        ],
      );
    }
    return InkWell(
      onTap: () => ref.read(downloadsProvider.notifier).refresh(chapter),
      borderRadius: BorderRadius.circular(radiusPill),
      child: Container(
        // Prototype metrics, like the pill on a chapter row: 30 tall, never
        // narrower than 84 — the word and its icon, and no more.
        constraints: const BoxConstraints(minHeight: 30, minWidth: 84),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: patraOffline.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh, size: 14, color: patraOffline),
            const SizedBox(width: 7),
            Text(
              l10n.refreshCopy,
              style: PatraText.metadata(color: patraOffline),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalThumb extends StatelessWidget {
  const _LocalThumb({required this.chapter, required this.dir});

  final SavedChapter chapter;
  final Directory? dir;

  @override
  Widget build(BuildContext context) {
    final directory = dir;
    if (directory == null) return const ColoredBox(color: patraSurface);
    // A book is stored as the pages the server laid its words out into, so
    // its first stored page is a page of HTML and not a picture to show: the
    // copy keeps the chapter's cover beside it instead (#129). A copy saved
    // before it did, or whose cover the server refused, has none.
    final file = File(
      '${directory.path}/'
      '${chapter.content == ChapterContent.reflowable ? DownloadsService.coverFileName : DownloadsService.pageFileName(0)}',
    );
    if (!file.existsSync()) return _noPicture;
    return Image.file(file, fit: BoxFit.cover, cacheWidth: 138);
  }

  /// What stands in for a cover this device has no picture of.
  Widget get _noPicture => ColoredBox(
    color: patraSurface,
    child: Icon(Icons.menu_book_outlined, size: 18, color: patraTextMuted),
  );
}

/// The **reading** progress of a copy on the device, as a bar under it.
///
/// A bar and not a ring, because a copy's *download* progress is the ring
/// inside its pill and the two must not be read for one another — this wears
/// the accent every reading bar in the app wears. It was drawn in three places
/// once, the offline blue on a cover and under a title among them, and the
/// ring replaced those two: this is what is left.
class _CopyProgress extends StatelessWidget {
  const _CopyProgress({
    required this.value,
    required this.color,
    this.width = 180,
  });

  /// 0..1, or null where there is nothing to be a fraction of yet.
  final double? value;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusTrack / 2),
        child: LinearProgressIndicator(
          value: value,
          minHeight: radiusTrack,
          backgroundColor: patraTrack,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}
