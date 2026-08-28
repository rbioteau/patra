import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/kavita_client.dart';
import '../../api/models.dart';
import '../../auth/session.dart';

final volumesProvider = FutureProvider.autoDispose.family<List<VolumeDto>, int>(
  (ref, seriesId) {
    return ref.watch(kavitaClientProvider).volumes(seriesId);
  },
);

/// One card in the detail grid: a volume, a loose chapter, or a special.
class _Entry {
  const _Entry({
    required this.coverUrl,
    required this.label,
    required this.pages,
    required this.pagesRead,
    required this.chapters,
  });

  final String coverUrl;
  final String label;
  final int pages;
  final int pagesRead;

  /// Chapters behind this card: one for chapter cards and chapterless
  /// volumes, several for a volume with a chapter breakdown (tap then picks).
  final List<ChapterDto> chapters;

  double get progress => pages > 0 ? pagesRead / pages : 0;
  bool get read => pages > 0 && pagesRead >= pages;
}

class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({
    super.key,
    required this.seriesId,
    required this.seriesName,
  });

  final int seriesId;
  final String seriesName;

  String _chapterLabel(ChapterDto chapter, AppLocalizations l10n) =>
      chapter.titleName.isNotEmpty
      ? chapter.titleName
      : chapter.isSpecial
      ? chapter.title
      : l10n.chapterLabel(chapter.range);

  /// Sections in display order: volumes, loose chapters, specials.
  List<(String?, List<_Entry>)> _sections(
    List<VolumeDto> volumes,
    KavitaClient client,
    AppLocalizations l10n,
  ) {
    final tomes = <_Entry>[];
    final chapters = <_Entry>[];
    final specials = <_Entry>[];

    for (final volume in volumes) {
      if (volume.isLooseLeaf || volume.isSpecials) {
        for (final chapter in volume.chapters) {
          (chapter.isSpecial ? specials : chapters).add(
            _Entry(
              coverUrl: client.chapterCoverUrl(chapter.id),
              label: _chapterLabel(chapter, l10n),
              pages: chapter.pages,
              pagesRead: chapter.pagesRead,
              chapters: [chapter],
            ),
          );
        }
      } else {
        tomes.add(
          _Entry(
            coverUrl: client.volumeCoverUrl(volume.id),
            label: l10n.volumeLabel(volume.name),
            pages: volume.pages,
            pagesRead: volume.pagesRead,
            chapters: volume.chapters,
          ),
        );
      }
    }
    // The API returns volumes sorted by number; sentinel volumes (negative
    // numbers) were routed to other buckets, so each bucket is in order.
    final sections = [
      if (tomes.isNotEmpty) (l10n.volumesTitle, tomes),
      if (chapters.isNotEmpty) (l10n.chaptersTitle, chapters),
      if (specials.isNotEmpty) (l10n.specialsTitle, specials),
    ];
    // A single section needs no header.
    return sections.length == 1 ? [(null, sections.single.$2)] : sections;
  }

  void _open(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    _Entry entry,
  ) {
    // A volume placeholder chapter or a plain chapter card: straight to the
    // reader. A volume with a real chapter breakdown: pick the chapter.
    final chapters = entry.chapters;
    if (chapters.isEmpty) return; // mid-scan or metadata-only volume
    if (chapters.length == 1 || chapters.first.isVolumePlaceholder) {
      _read(context, ref, chapters.first);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final chapter in chapters)
              ListTile(
                title: Text(_chapterLabel(chapter, l10n)),
                subtitle: Text(
                  chapter.pagesRead > 0 && chapter.pagesRead < chapter.pages
                      ? l10n.pageProgress(chapter.pagesRead, chapter.pages)
                      : l10n.pageCount(chapter.pages),
                ),
                trailing:
                    chapter.pages > 0 && chapter.pagesRead >= chapter.pages
                    ? Icon(
                        Icons.check_circle,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _read(context, ref, chapter);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _read(
    BuildContext context,
    WidgetRef ref,
    ChapterDto chapter,
  ) async {
    final started = chapter.pagesRead > 0 && chapter.pagesRead < chapter.pages;
    await context.push(
      '/reader/${chapter.id}?page=${started ? chapter.pagesRead : 0}',
    );
    // Progress changed while reading; refresh the cards.
    ref.invalidate(volumesProvider(seriesId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final client = ref.watch(kavitaClientProvider);
    final volumes = ref.watch(volumesProvider(seriesId));
    return Scaffold(
      appBar: AppBar(title: Text(seriesName)),
      body: volumes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          final sections = _sections(items, client, l10n);
          return CustomScrollView(
            slivers: [
              for (final (header, entries) in sections) ...[
                if (header != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        header,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 150,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _EntryCard(
                        entry: entry,
                        headers: client.imageHeaders,
                        onTap: () => _open(context, ref, l10n, entry),
                      );
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.headers,
    required this.onTap,
  });

  final _Entry entry;
  final Map<String, String> headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: entry.coverUrl,
                    httpHeaders: headers,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: colors.surfaceContainerHighest),
                    errorWidget: (_, _, _) => Container(
                      color: colors.surfaceContainerHighest,
                      child: const Icon(Icons.menu_book),
                    ),
                  ),
                ),
                if (entry.read)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.check_circle,
                      color: colors.primary,
                      shadows: const [Shadow(blurRadius: 4)],
                    ),
                  ),
              ],
            ),
          ),
          if (entry.progress > 0 && !entry.read)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: LinearProgressIndicator(
                value: entry.progress,
                minHeight: 3,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            entry.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
