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

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final downloads = ref.watch(downloadsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloadsTitle)),
      body: SafeArea(
        top: false,
        child: downloads.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: patraOffline),
          ),
          error: (error, _) => Center(
            child: Text('$error', style: PatraText.body(color: patraTextMuted)),
          ),
          data: (state) {
            final saved = state.saved.values.toList()
              ..sort((a, b) {
                final bySeries = a.seriesName.compareTo(b.seriesName);
                return bySeries != 0 ? bySeries : a.title.compareTo(b.title);
              });
            if (saved.isEmpty && state.inFlight.isEmpty) {
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
            return ListView(
              padding: const EdgeInsets.only(bottom: sectionGap),
              children: [
                _StorageMeter(bytes: state.totalBytes, chapters: saved.length),
                for (final chapter in saved) _SavedRow(chapter: chapter),
              ],
            );
          },
        ),
      ),
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

class _SavedRow extends ConsumerWidget {
  const _SavedRow({required this.chapter});

  final SavedChapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dir = ref.watch(chapterDirProvider(chapter.chapterId)).value;
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${l10n.pageCount(chapter.pages)} · '
                          '${formatBytes(l10n, chapter.bytes)}',
                          style: PatraText.metadata(size: tablet ? 12 : 11),
                        ),
                      ),
                      if (chapter.isRead) ...[
                        const SizedBox(width: 8),
                        Text(l10n.readTag, style: _readTagStyle),
                      ],
                    ],
                  ),
                  // Progress is what tells you which volumes are done with
                  // and can go.
                  if (!chapter.isRead && chapter.progress > 0) ...[
                    const SizedBox(height: 7),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: LinearProgressIndicator(
                          value: chapter.progress,
                          minHeight: 2,
                          backgroundColor: Colors.white.withValues(alpha: .07),
                          valueColor: const AlwaysStoppedAnimation(patraAccent),
                        ),
                      ),
                    ),
                  ],
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
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: l10n.removeDownload,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: patraTextMuted,
              onPressed: () async {
                if (await _confirmRemove(context, l10n)) {
                  await ref
                      .read(downloadsProvider.notifier)
                      .remove(chapter.chapterId);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmRemove(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: patraSurface,
        title: Text(
          l10n.removeDownloadConfirm(chapter.label),
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
    final stored = ref.watch(
      downloadsProvider.select(
        (state) => state.value?.inFlight[chapter.chapterId],
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

/// Same quiet accent mark the series rows use for a finished chapter.
final _readTagStyle = PatraText.metadata(
  color: patraAccent,
  size: 10.5,
).copyWith(fontWeight: FontWeight.w600, letterSpacing: .5);

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
