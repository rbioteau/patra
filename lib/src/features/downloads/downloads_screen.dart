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
class _SavedSection extends ConsumerWidget {
  const _SavedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(savedChapterIdsProvider);
    return Column(
      children: [
        for (final id in ids) _SavedRow(key: ValueKey(id), chapterId: id),
      ],
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
/// cancel control.
///
/// Cancelling one leaves the rest running: a batch is several chapters the
/// reader asked for in one tap, and dropping one of them is a smaller
/// decision than dropping the lot.
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
    if (membership.inFlight.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(gutter, sectionGap, gutter, 8),
          child: SectionLabel(
            l10n.downloadsQueueSection,
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
          ),
        ),
        for (final chapterId in membership.inFlight)
          _DownloadingRow(chapterId: chapterId),
      ],
    );
  }
}

/// One in-flight copy: the work the reader asked for, how far it has got,
/// and the one control that takes it out of the batch.
class _DownloadingRow extends ConsumerWidget {
  const _DownloadingRow({required this.chapterId});

  final int chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final request = ref.watch(
      downloadRecordProvider(chapterId).select((record) => record?.request),
    );
    if (request == null) return const SizedBox.shrink();
    // A queued copy has pages to fetch and none fetched yet, so there is no
    // total to be a fraction of: it says what it is waiting for rather than
    // reporting zero.
    final hasPageTotal = ref.watch(
      downloadRecordProvider(chapterId)
          .select((record) => (record?.totalPages ?? 0) > 0),
    );
    // The one number a landing page moves. Everything else in the row is
    // resubscribed to things that do not, so it is left alone.
    final progress = ref.watch(downloadProgressProvider(chapterId));
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
          // The cover of what is being fetched, which is the whole of how a
          // reader recognises a row in a batch of five. It comes from the
          // server, as the row's own does, and it is left clean: the row
          // carries the download's progress on its trailing edge, where the
          // heading above it is, and two bars for one fetch would only say
          // the same thing twice.
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
              ],
            ),
          ),
          const SizedBox(width: 10),
          // On the trailing edge, where the section heading above these rows
          // is: a column of copies in flight is read down that one edge,
          // rather than across rows whose bars begin wherever their titles
          // happen to end. A width of its own, so every bar in the section
          // ends on the same line however long the titles beside it are.
          if (hasPageTotal)
            _CopyProgress(
              value: progress,
              color: patraOffline,
              width: tablet ? 120 : 72,
            ),
          if (!hasPageTotal)
            Text(
              l10n.downloadsWaiting,
              style: PatraText.metadata(color: patraOffline),
            ),
          IconButton(
            tooltip: l10n.cancelDownload(title),
            icon: const Icon(Icons.cancel_outlined, size: 20),
            color: patraTextMuted,
            onPressed: () =>
                ref.read(downloadsProvider.notifier).cancel(chapterId),
          ),
        ],
      ),
    );
  }
}

/// The cover of a copy that has not landed, which is the whole of how a
/// reader recognises one row of a batch from another.
///
/// Fetched from the server, as the row's own cover is, and filed under the
/// shared cache key, so a chapter being fetched and the same chapter already
/// on the device are one picture on the disk rather than two. It carries no
/// bar of its own: a download's progress is read on the trailing edge, where
/// the heading above these rows is, and a bar pinned to the cover as well
/// would say the same thing twice in two places.
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

/// Copies that stopped before they were finished, which stay listed with a
/// Retry instead of living in memory and disappearing.
///
/// A failure seen from anywhere but the series screen, or after a restart, is
/// a failure the reader never saw — so it is named here, in the one tab that
/// is about what is on the device.
class _PendingSection extends ConsumerWidget {
  const _PendingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = ref.watch(
      downloadMembershipProvider.select((membership) => membership.pending),
    );
    if (pending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(gutter, sectionGap, gutter, 8),
          child: SectionLabel(l10n.downloadsPendingSection, color: patraDanger),
        ),
        for (final chapterId in pending) _PendingRow(chapterId: chapterId),
      ],
    );
  }
}

/// One copy that stopped short, with the control that starts it again —
/// from the pages it kept, not from the beginning.
class _PendingRow extends ConsumerWidget {
  const _PendingRow({required this.chapterId});

  final int chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Its own record, so a page landing on another chapter leaves this row —
    // and the fact that it is waiting — alone.
    final record = ref.watch(downloadRecordProvider(chapterId));
    if (record == null) return const SizedBox.shrink();
    final request = record.request;
    final tablet = isTabletLayout(context);
    final title = request.resolvedTitle;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: gutter,
        vertical: tablet ? 9 : 6,
      ),
      child: Row(
        children: [
          // The same cover the row would have once it has landed: what is
          // waiting to be given another go is recognisable or it is not
          // worth listing.
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
                const SizedBox(height: 3),
                // The two are different facts: one was refused or lost the
                // server, the other lost the app. Both keep their pages and
                // both are one tap from going on.
                Text(
                  record.status == DownloadQueueStatus.failed
                      ? l10n.downloadsFailed
                      : l10n.downloadsStoppedShort,
                  style: PatraText.metadata(
                    size: tablet ? 12 : 11,
                    color: patraDanger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Worded, and of a width of its own: the same control the row's
          // refresh is, so a retry reads as a tap on a word and not on the
          // row it sits in.
          InkWell(
            onTap: () => ref
                .read(downloadsProvider.notifier)
                .retry(record.request.chapterId),
            borderRadius: BorderRadius.circular(radiusPill),
            child: Container(
              constraints: const BoxConstraints(minHeight: 30, minWidth: 84),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: patraDanger.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(radiusPill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, size: 14, color: patraDanger),
                  const SizedBox(width: 7),
                  Text(
                    l10n.retry,
                    style: PatraText.metadata(color: patraDanger),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
              // The first stored page doubles as the thumbnail: no server needed.
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
    // A book is stored as the pages the server laid its words out into, so
    // its first stored page is a page of HTML and not a picture to show.
    if (chapter.content == ChapterContent.reflowable) return _noPicture;
    final directory = dir;
    if (directory == null) return const ColoredBox(color: patraSurface);
    final file = File('${directory.path}/${DownloadsService.pageFileName(0)}');
    if (!file.existsSync()) return _noPicture;
    return Image.file(file, fit: BoxFit.cover, cacheWidth: 138);
  }

  /// What stands in for a cover this device has no picture of.
  Widget get _noPicture => ColoredBox(
    color: patraSurface,
    child: Icon(Icons.menu_book_outlined, size: 18, color: patraTextMuted),
  );
}

/// A progress bar under a copy, in the token every other bar in the app uses.
///
/// One widget because the Downloads tab draws it in three places — a copy on
/// the device in the accent, a copy on its way in the offline blue — and a
/// radius or a colour written twice is a radius or a colour that drifts.
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
