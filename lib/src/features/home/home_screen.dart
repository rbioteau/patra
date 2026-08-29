import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../theme.dart';
import '../../widgets/cover.dart';
import '../../widgets/offline_banner.dart';
import '../library/library_screen.dart';

final continueReadingProvider = FutureProvider.autoDispose<List<SeriesDto>>(
  (ref) => ref.watch(kavitaClientProvider).currentlyReading(),
);

final onDeckProvider = FutureProvider.autoDispose<List<SeriesDto>>(
  (ref) => ref.watch(kavitaClientProvider).onDeck(),
);

/// Library type → icon, matching Kavita's own taxonomy.
IconData _libraryIcon(LibraryType type) => switch (type) {
  LibraryType.manga => Icons.menu_book,
  LibraryType.comic || LibraryType.comicVine => Icons.bolt,
  LibraryType.book => Icons.auto_stories,
  LibraryType.image => Icons.image_outlined,
  LibraryType.lightNovel => Icons.article_outlined,
};

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(continueReadingProvider);
    ref.invalidate(onDeckProvider);
    ref.invalidate(librariesProvider);
    await Future.wait([
      ref.read(continueReadingProvider.future),
      ref.read(onDeckProvider.future),
      ref.read(librariesProvider.future),
    ]).catchError((Object _) => const <List<Object>>[]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final continueReading = ref.watch(continueReadingProvider);
    final onDeck = ref.watch(onDeckProvider);
    final libraries = ref.watch(librariesProvider);

    final everythingEmpty =
        (continueReading.value?.isEmpty ?? false) &&
        (onDeck.value?.isEmpty ?? false) &&
        (libraries.value?.isEmpty ?? false);

    return Scaffold(
      appBar: AppBar(title: const _Wordmark()),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.only(bottom: sectionGap),
            children: [
              const OfflineBanner(),
              if (everythingEmpty)
                Padding(
                  padding: const EdgeInsets.all(gutter * 1.5),
                  child: Text(
                    l10n.homeEmpty,
                    textAlign: TextAlign.center,
                    style: VersoText.body(color: versoTextMuted),
                  ),
                ),
              _Shelf(
                label: l10n.continueSection,
                series: continueReading,
                showProgress: true,
              ),
              _Shelf(label: l10n.onDeckSection, series: onDeck),
              _LibrariesSection(libraries: libraries),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lowercase serif wordmark with the accent period.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'verso',
        style: VersoText.serifTitle(size: 22),
        children: [
          TextSpan(
            text: '.',
            style: VersoText.serifTitle(size: 22, color: versoAccent),
          ),
        ],
      ),
    );
  }
}

/// A horizontal shelf of covers. Renders nothing at all when the section is
/// empty, so the home screen stays quiet rather than showing empty labels.
class _Shelf extends ConsumerWidget {
  const _Shelf({
    required this.label,
    required this.series,
    this.showProgress = false,
  });

  final String label;
  final AsyncValue<List<SeriesDto>> series;
  final bool showProgress;

  static const _tileWidth = 112.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (series.hasValue && series.requireValue.isEmpty) {
      return const SizedBox.shrink();
    }
    if (series.hasError && !series.hasValue) return const SizedBox.shrink();

    final client = series.hasValue ? ref.watch(kavitaClientProvider) : null;
    final items = series.value ?? const <SeriesDto>[];

    return Padding(
      padding: const EdgeInsets.only(top: sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: gutter),
            child: SectionLabel(label),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _tileWidth / coverAspectRatio + 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              itemCount: client == null ? 4 : items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (client == null) {
                  return const SizedBox(
                    width: _tileWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: coverAspectRatio,
                          child: Skeleton(radius: radiusCover),
                        ),
                        SizedBox(height: 8),
                        Skeleton(height: 10),
                      ],
                    ),
                  );
                }
                final s = items[index];
                final progress = showProgress && s.pages > 0
                    ? s.pagesRead / s.pages
                    : 0.0;
                return SizedBox(
                  width: _tileWidth,
                  child: CoverTile(
                    url: client.seriesCoverUrl(s.id),
                    headers: client.imageHeaders,
                    title: s.name,
                    serifTitle: true,
                    progress: progress,
                    onTap: () async {
                      await context.push(
                        Uri(
                          path: '/series/${s.id}',
                          queryParameters: {
                            'name': s.name,
                            'library': '${s.libraryId}',
                          },
                        ).toString(),
                      );
                      ref.invalidate(continueReadingProvider);
                      ref.invalidate(onDeckProvider);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LibrariesSection extends ConsumerWidget {
  const _LibrariesSection({required this.libraries});

  final AsyncValue<List<LibraryDto>> libraries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = libraries.value;
    if (items != null && items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: gutter),
            child: SectionLabel(l10n.librariesTitle),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: gutter),
            child: items == null
                ? const Row(
                    children: [
                      Expanded(child: Skeleton(height: 64, radius: radiusCard)),
                      SizedBox(width: 12),
                      Expanded(child: Skeleton(height: 64, radius: radiusCard)),
                    ],
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final library in items)
                        _LibraryCard(
                          library: library,
                          onTap: () {
                            ref
                                .read(selectedLibraryProvider.notifier)
                                .select(library.id);
                            context.go('/library');
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({required this.library, required this.onTap});

  final LibraryDto library;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - gutter * 2 - 12) / 2;
    return SizedBox(
      width: width,
      child: Material(
        color: versoSurface,
        borderRadius: BorderRadius.circular(radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusCard),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radiusCard),
              border: Border.all(color: versoBorder),
            ),
            child: Row(
              children: [
                Icon(_libraryIcon(library.type), size: 18, color: versoAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    library.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VersoText.rowTitle(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
