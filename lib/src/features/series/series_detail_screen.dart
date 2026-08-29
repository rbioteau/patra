import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/kavita_client.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../downloads/downloads_provider.dart';
import '../../downloads/downloads_service.dart';
import '../../theme.dart';
import '../../widgets/cover.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/save_pill.dart';

final volumesProvider = FutureProvider.autoDispose.family<List<VolumeDto>, int>(
  (ref, seriesId) {
    return ref.watch(kavitaClientProvider).volumes(seriesId);
  },
);

final seriesProvider = FutureProvider.autoDispose.family<SeriesDto, int>(
  (ref, seriesId) => ref.watch(kavitaClientProvider).series(seriesId),
);

final seriesMetadataProvider = FutureProvider.autoDispose
    .family<SeriesMetadataDto, int>(
      (ref, seriesId) =>
          ref.watch(kavitaClientProvider).seriesMetadata(seriesId),
    );

typedef _Entry = ({VolumeDto volume, ChapterDto chapter});

/// Every chapter in reading order — volumes first, then loose chapters, then
/// specials, the order the sections below are rendered in — each paired with
/// the volume it belongs to, which is what names a chapterless volume.
List<_Entry> _orderedChapters(List<VolumeDto> volumes) {
  final tomes = <_Entry>[];
  final loose = <_Entry>[];
  final specials = <_Entry>[];
  for (final volume in volumes) {
    for (final chapter in volume.chapters) {
      final entry = (volume: volume, chapter: chapter);
      if (volume.isSpecials || chapter.isSpecial) {
        specials.add(entry);
      } else if (volume.isLooseLeaf) {
        loose.add(entry);
      } else {
        tomes.add(entry);
      }
    }
  }
  return [...tomes, ...loose, ...specials];
}

class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({
    super.key,
    required this.seriesId,
    required this.seriesName,
    this.libraryId = 0,
  });

  final int seriesId;
  final String seriesName;

  /// Passed through from the caller so saved chapters know where they belong;
  /// 0 when unknown, which only costs offline progress attribution.
  final int libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final client = ref.watch(kavitaClientProvider);
    final volumes = ref.watch(volumesProvider(seriesId));

    return Scaffold(
      appBar: AppBar(
        // The hero below carries the serif title; the bar keeps a compact one.
        title: Text(
          seriesName,
          style: VersoText.rowTitle().copyWith(fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // One row open at a time, and scrolling closes it.
      body: SlidableAutoCloseBehavior(
        child: SafeArea(
          top: false,
          // The hero renders as soon as the cover URL is known, so the chapter
          // list loading underneath never blocks it.
          child: ListView(
            padding: const EdgeInsets.only(bottom: sectionGap),
            children: [
              const OfflineBanner(),
              _SeriesHero(
                seriesId: seriesId,
                seriesName: seriesName,
                volumes: volumes.value,
                onRead: (chapter) => _read(context, ref, chapter),
              ),
              ...switch (volumes) {
                AsyncData(:final value) => _buildSections(
                  context,
                  ref,
                  client,
                  l10n,
                  value,
                ),
                AsyncError() => [
                  Padding(
                    padding: const EdgeInsets.all(gutter),
                    child: Column(
                      children: [
                        Text(
                          ref.watch(offlineProvider)
                              ? l10n.offlineBanner
                              : l10n.serverUnreachable,
                          textAlign: TextAlign.center,
                          style: VersoText.body(color: versoTextMuted),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () =>
                              ref.invalidate(volumesProvider(seriesId)),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ],
                _ => [const _RowsSkeleton()],
              },
            ],
          ),
        ),
      ),
    );
  }

  /// Opens a chapter and refreshes what reading it may have changed.
  Future<void> _read(
    BuildContext context,
    WidgetRef ref,
    ChapterDto chapter,
  ) async {
    final started = chapter.pagesRead > 0 && chapter.pagesRead < chapter.pages;
    await context.push(
      '/reader/${chapter.id}?page=${started ? chapter.pagesRead : 0}',
    );
    ref.invalidate(volumesProvider(seriesId));
    ref.invalidate(seriesProvider(seriesId));
  }

  List<Widget> _buildSections(
    BuildContext context,
    WidgetRef ref,
    KavitaClient client,
    AppLocalizations l10n,
    List<VolumeDto> volumes,
  ) {
    final tomes = [
      for (final volume in volumes)
        if (!volume.isLooseLeaf && !volume.isSpecials) volume,
    ];
    final looseChapters = <ChapterDto>[];
    final specials = <ChapterDto>[];
    for (final volume in volumes) {
      if (!volume.isLooseLeaf && !volume.isSpecials) continue;
      for (final chapter in volume.chapters) {
        (chapter.isSpecial ? specials : looseChapters).add(chapter);
      }
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(gutter, sectionGap, gutter, 8),
      child: SectionLabel(text),
    );

    return [
      if (tomes.isNotEmpty) ...[
        header(l10n.volumesTitle),
        for (final volume in tomes)
          if (volume.chapters.length == 1 &&
              volume.chapters.single.isVolumePlaceholder)
            // No chapter breakdown: the volume itself is the reading unit.
            _ChapterRow(
              chapter: volume.chapters.single,
              label: l10n.volumeLabel(volume.name),
              coverUrl: client.volumeCoverUrl(volume.id),
              seriesId: seriesId,
              seriesName: seriesName,
              libraryId: libraryId,
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 4),
              child: Text(
                l10n.volumeLabel(volume.name),
                style: VersoText.rowTitle(color: versoTextMuted),
              ),
            ),
            for (final chapter in volume.chapters)
              _ChapterRow(
                chapter: chapter,
                coverUrl: client.chapterCoverUrl(chapter.id),
                seriesId: seriesId,
                seriesName: seriesName,
                libraryId: libraryId,
              ),
          ],
      ],
      if (looseChapters.isNotEmpty) ...[
        header(l10n.chaptersTitle),
        for (final chapter in looseChapters)
          _ChapterRow(
            chapter: chapter,
            coverUrl: client.chapterCoverUrl(chapter.id),
            seriesId: seriesId,
            seriesName: seriesName,
            libraryId: libraryId,
          ),
      ],
      if (specials.isNotEmpty) ...[
        header(l10n.specialsTitle),
        for (final chapter in specials)
          _ChapterRow(
            chapter: chapter,
            coverUrl: client.chapterCoverUrl(chapter.id),
            seriesId: seriesId,
            seriesName: seriesName,
            libraryId: libraryId,
          ),
      ],
    ];
  }
}

/// The hero the design opens the screen with: the series cover, who made it,
/// how much of it there is, and one button that resumes exactly where the
/// reader left off.
class _SeriesHero extends ConsumerWidget {
  const _SeriesHero({
    required this.seriesId,
    required this.seriesName,
    required this.volumes,
    required this.onRead,
  });

  final int seriesId;
  final String seriesName;

  /// Null while the chapter list is still loading: the button waits for it.
  final List<VolumeDto>? volumes;
  final void Function(ChapterDto chapter) onRead;

  static const _coverWidth = 124.0;
  static const _coverHeight = 182.0;

  /// The chapter the button opens: the first one not finished, else the first.
  ({_Entry entry, bool started, bool allRead})? _target() {
    final entries = volumes == null ? null : _orderedChapters(volumes!);
    if (entries == null || entries.isEmpty) return null;
    for (final entry in entries) {
      final chapter = entry.chapter;
      final read = chapter.pages > 0 && chapter.pagesRead >= chapter.pages;
      if (!read) {
        return (entry: entry, started: chapter.pagesRead > 0, allRead: false);
      }
    }
    return (entry: entries.first, started: false, allRead: true);
  }

  /// What to call the thing the button opens. A volume with no chapter
  /// breakdown is named after the volume: its placeholder chapter carries
  /// Kavita's -100000 sentinel, which must never reach the label.
  String _resumeLabel(_Entry entry, AppLocalizations l10n) {
    final chapter = entry.chapter;
    if (chapter.isVolumePlaceholder &&
        !entry.volume.isLooseLeaf &&
        !entry.volume.isSpecials) {
      return l10n.seriesContinueVolume(entry.volume.name);
    }
    if (chapter.titleName.isNotEmpty) return chapter.titleName;
    // Anything at sentinel scale is Kavita bookkeeping, not a chapter number.
    final number = num.tryParse(chapter.range)?.abs() ?? 0;
    if (chapter.range.isNotEmpty && number < ChapterDto.defaultNumber) {
      return l10n.seriesContinue(chapter.range);
    }
    return l10n.seriesStartReading;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final client = ref.watch(kavitaClientProvider);
    final series = ref.watch(seriesProvider(seriesId)).value;
    final metadata = ref.watch(seriesMetadataProvider(seriesId)).value;
    final target = _target();

    // "Author · Genre", dropping whichever half the server does not have.
    final credits = [
      if (metadata != null && metadata.writers.isNotEmpty)
        metadata.writers.take(2).join(', '),
      if (metadata != null && metadata.genres.isNotEmpty) metadata.genres.first,
    ].join(' · ');

    // A volume-organised series is counted in volumes: calling four volumes
    // "4 chapters" reads as wrong to anyone looking at the list below.
    final tally = switch (volumes) {
      null => null,
      final list when list.any((v) => !v.isLooseLeaf && !v.isSpecials) =>
        l10n.seriesVolumeCount(
          list.where((v) => !v.isLooseLeaf && !v.isSpecials).length,
        ),
      final list => l10n.seriesChapterCount(_orderedChapters(list).length),
    };
    final stats = [
      ?tally,
      if (series != null && series.libraryName.isNotEmpty) series.libraryName,
    ].join(' · ');

    final label = switch (target) {
      null => null,
      (:final entry, started: true, allRead: false) => _resumeLabel(
        entry,
        l10n,
      ),
      (allRead: true, entry: _, started: _) => l10n.seriesReadAgain,
      _ => l10n.seriesStartReading,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _coverWidth,
            height: _coverHeight,
            child: CoverImage(
              url: client.seriesCoverUrl(seriesId),
              headers: client.imageHeaders,
              progress: series == null || series.pages == 0
                  ? 0
                  : series.pagesRead / series.pages,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: _coverHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    seriesName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: VersoText.serifTitle(size: 21),
                  ),
                  const SizedBox(height: 6),
                  if (credits.isNotEmpty)
                    Text(
                      credits,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VersoText.metadata(size: 12),
                    )
                  else if (metadata == null)
                    const Skeleton(height: 11, width: 150),
                  const SizedBox(height: 6),
                  if (stats.isNotEmpty)
                    Text(stats, style: VersoText.metadata(size: 12))
                  else
                    const Skeleton(height: 11, width: 110),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: target == null
                          ? null
                          : () => onRead(target.entry.chapter),
                      child: Text(
                        label ?? l10n.seriesStartReading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

class _ChapterRow extends ConsumerWidget {
  const _ChapterRow({
    required this.chapter,
    required this.coverUrl,
    required this.seriesId,
    required this.seriesName,
    required this.libraryId,
    this.label,
  });

  final ChapterDto chapter;
  final String coverUrl;
  final int seriesId;
  final String seriesName;
  final int libraryId;

  /// Overrides the derived label, for a volume shown as a single row.
  final String? label;

  static const _coverWidth = 46.0;
  static const _coverHeight = 66.0;

  String _label(AppLocalizations l10n) {
    if (label != null) return label!;
    if (chapter.titleName.isNotEmpty) return chapter.titleName;
    if (chapter.isSpecial) return chapter.title;
    return l10n.chapterLabel(chapter.range);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final read = chapter.pages > 0 && chapter.pagesRead >= chapter.pages;
    final inProgress = chapter.pagesRead > 0 && !read;
    final progress = inProgress && chapter.pages > 0
        ? chapter.pagesRead / chapter.pages
        : 0.0;

    final savedCopy = ref.watch(savedChapterProvider(chapter.id));
    final saved = savedCopy != null;
    final offline = ref.watch(offlineProvider);

    // The server is the authority on progress; mirror it into the stored copy
    // so the Downloads tab knows it too, including for chapters saved before
    // this screen was ever opened.
    if (savedCopy != null && savedCopy.pagesRead != chapter.pagesRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(downloadsProvider.notifier)
            .recordProgress(chapter.id, chapter.pagesRead);
      });
    }
    // Offline, a chapter that is not stored locally cannot be opened.
    final openable = saved || !offline;

    final row = Container(
      // Rows are separated by a hairline, not by whitespace.
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _coverWidth,
            height: _coverHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(
                  url: coverUrl,
                  headers: ref.watch(kavitaClientProvider).imageHeaders,
                  radius: radiusThumb,
                  memCacheWidth: 138,
                ),
                // The spine: a hint of a closed book along the binding edge.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    color: Colors.black.withValues(alpha: .35),
                  ),
                ),
                if (read)
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: versoAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .6),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _label(l10n),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: VersoText.rowTitle(
                          color: read ? versoTextMuted : versoText,
                        ),
                      ),
                    ),
                    if (read) ...[
                      const SizedBox(width: 8),
                      Text(l10n.readTag, style: _readTagStyle),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  inProgress
                      ? l10n.pageProgress(chapter.pagesRead, chapter.pages)
                      : l10n.pageCount(chapter.pages),
                  style: VersoText.metadata(),
                ),
                // Progress belongs to the chapter being read, and only to it.
                if (inProgress) ...[
                  const SizedBox(height: 7),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(1),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.white.withValues(alpha: .07),
                        valueColor: const AlwaysStoppedAnimation(versoAccent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SavePill(
            request: SavedChapter(
              chapterId: chapter.id,
              seriesId: seriesId,
              volumeId: 0,
              libraryId: libraryId,
              seriesName: seriesName,
              title: _label(l10n),
              pages: chapter.pages,
              bytes: 0,
              pagesRead: chapter.pagesRead,
            ),
          ),
        ],
      ),
    );

    final tile = Opacity(
      opacity: openable ? 1 : 0.4,
      child: Builder(
        // Builder so the tap can ask the Slidable above it whether it is open.
        builder: (rowContext) => InkWell(
          onTap: openable ? () => _tap(rowContext, ref) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minHitTarget),
              child: row,
            ),
          ),
        ),
      ),
    );

    // Only a stored chapter has anything to reveal.
    if (!saved) return tile;
    return Slidable(
      key: ValueKey(chapter.id),
      groupTag: 'chapters',
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.24,
        children: [
          SlidableAction(
            onPressed: (actionContext) async {
              if (await _confirmRemove(actionContext, l10n)) {
                await ref.read(downloadsProvider.notifier).remove(chapter.id);
              }
            },
            backgroundColor: versoDanger.withValues(alpha: .16),
            foregroundColor: versoDanger,
            icon: Icons.delete_outline,
            label: l10n.removeDownload,
          ),
        ],
      ),
      child: tile,
    );
  }

  /// An open row closes on tap; only a closed one opens the reader.
  void _tap(BuildContext context, WidgetRef ref) {
    final slidable = Slidable.of(context);
    if (slidable != null && slidable.animation.value > 0) {
      slidable.close();
      return;
    }
    _open(context, ref);
  }

  Future<bool> _confirmRemove(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: versoSurface,
        title: Text(
          l10n.removeDownloadConfirm(
            [seriesName, _label(l10n)].where((p) => p.isNotEmpty).join(' — '),
          ),
          style: VersoText.body(),
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
              style: VersoText.body(color: versoDanger),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final started = chapter.pagesRead > 0 && chapter.pagesRead < chapter.pages;
    await context.push(
      '/reader/${chapter.id}?page=${started ? chapter.pagesRead : 0}',
    );
    // Progress changed while reading: the rows and the hero both show it.
    ref.invalidate(volumesProvider(seriesId));
    ref.invalidate(seriesProvider(seriesId));
  }
}

/// The READ mark: tracked text beside a finished chapter's title, in the
/// accent — the same colour as the badge on its cover, since both say the
/// same thing about reading progress.
final _readTagStyle = VersoText.metadata(
  color: versoAccent,
  size: 10.5,
).copyWith(fontWeight: FontWeight.w600, letterSpacing: .5);

class _RowsSkeleton extends StatelessWidget {
  const _RowsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        6,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 6),
          child: Row(
            children: [
              const Skeleton(width: 46, height: 66),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Skeleton(height: 12, width: 160),
                    SizedBox(height: 8),
                    Skeleton(height: 10, width: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
