import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../resume_point.dart';
import '../../routes.dart';
import '../../theme.dart';
import '../../widgets/cover.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/patra_frond.dart';
import '../../widgets/patra_wordmark.dart';
import '../launch/launch_animation.dart';
import '../library/library_screen.dart';
import '../series/series_detail_screen.dart';
import 'continue_hero.dart';

final continueReadingProvider = FutureProvider.autoDispose<List<Series>>(
  retry: serverRetry,
  (ref) => ref.watch(kavitaClientProvider).currentlyReading(),
);

final onDeckProvider = FutureProvider.autoDispose<List<Series>>(
  retry: serverRetry,
  (ref) => ref.watch(kavitaClientProvider).onDeck(),
);

/// Whether there is a hero at all, and what it says.
///
/// Null means the hero is not drawn *and* the Continue shelf keeps its series
/// — the two are one decision, or a series that failed to be promoted would
/// vanish from the home screen entirely. It is null when nothing is in
/// progress, when the app is offline, and when the chapter fetch fails; it is
/// non-null with a null `point` while that fetch is still in flight, so the
/// card can show its cover and title without waiting.
final continueHeroProvider = Provider.autoDispose<ContinueHeroData?>((ref) {
  if (ref.watch(offlineProvider)) return null;
  final started = ref.watch(continueReadingProvider).value;
  final featured = featuredSeries(started ?? const []);
  if (featured == null) return null;
  // Deliberately the raw fetch and not `seriesVolumesProvider`, which lays
  // the series screen's optimistic mark-read over it: that override map is
  // autoDispose so that it dies with that screen and the next visit is the
  // server's word again, and a home screen watching it would keep it alive
  // for the life of the app. What keeps this honest instead is that every
  // path back from reading re-fetches — see `_refresh`.
  final volumes = ref.watch(volumesProvider(featured.id));
  if (volumes.hasError) return null;
  final point = volumes.value == null ? null : resumePoint(volumes.value!);
  if (volumes.hasValue && point == null) return null;
  return (series: featured, point: point);
});

/// Library type → icon, matching Kavita's own taxonomy.
IconData _libraryIcon(LibraryType type) => switch (type) {
  LibraryType.manga => Icons.menu_book,
  LibraryType.comic || LibraryType.comicVine => Icons.bolt,
  LibraryType.book => Icons.auto_stories,
  LibraryType.image => Icons.image_outlined,
  LibraryType.lightNovel => Icons.article_outlined,
};

/// The shelf without the series the hero has taken, so one series is never
/// two things on the same screen.
///
/// This is also what catches a hero that collapses: the removal is keyed on
/// the hero actually being there, so a card that could not be completed
/// leaves its series in the list rather than taking it off the screen.
AsyncValue<List<Series>> _without(AsyncValue<List<Series>> shelf, int? id) =>
    id == null
    ? shelf
    : shelf.whenData(
        (list) => [
          for (final series in list)
            if (series.id != id) series,
        ],
      );

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    // The hero's chapter is a fourth request, hanging off whichever series is
    // promoted. A pull has to reach it too, or the card would keep naming the
    // chapter the shelf has just stopped agreeing with.
    final featured = ref.read(continueHeroProvider)?.series.id;
    if (featured != null) ref.invalidate(volumesProvider(featured));
    ref.invalidate(continueReadingProvider);
    ref.invalidate(onDeckProvider);
    ref.invalidate(librariesProvider);
    await Future.wait([
      ref.read(continueReadingProvider.future),
      ref.read(onDeckProvider.future),
      ref.read(librariesProvider.future),
    ]).catchError((Object _) => const <List<Object>>[]);
    // The shelves have moved, so the promoted series may not be the one whose
    // chapter was invalidated above.
    final promoted = ref.read(continueHeroProvider)?.series.id;
    if (promoted != null && promoted != featured) {
      ref.invalidate(volumesProvider(promoted));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hero = ref.watch(continueHeroProvider);
    final started = ref.watch(continueReadingProvider);
    final onDeck = _without(ref.watch(onDeckProvider), hero?.series.id);
    final libraries = ref.watch(librariesProvider);

    // Every clause has to be a *resolved* emptiness. `hero == null` alone is
    // also true while the promotion is merely unknown — in flight, or offline
    // — so keying the copy on it flashes "nothing here" over a library that
    // has plenty. An unresolved provider has a null value and fails the test.
    final everythingEmpty =
        hero == null &&
        (started.value?.isEmpty ?? false) &&
        (onDeck.value?.isEmpty ?? false) &&
        (libraries.value?.isEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const _Wordmark(),
        actions: const [OfflineIndicator()],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.only(bottom: sectionGap),
            children: [
              if (everythingEmpty)
                Padding(
                  padding: const EdgeInsets.all(gutter * 1.5),
                  child: Text(
                    l10n.homeEmpty,
                    textAlign: TextAlign.center,
                    style: PatraText.body(color: patraTextMuted),
                  ),
                ),
              if (hero != null)
                ContinueHero(data: hero, onReturn: () => _refresh(ref)),
              // On deck is the only list. `currently-reading` still runs, but
              // only to decide the hero: it and On deck came back as very
              // nearly the same set of series, so two shelves of them was the
              // same library twice with two headings over it.
              _Shelf(
                label: l10n.onDeckSection,
                series: onDeck,
                showProgress: true,
                onReturn: () => _refresh(ref),
              ),
              _LibrariesSection(libraries: libraries),
            ],
          ),
        ),
      ),
    );
  }
}

/// The app's own logo: the frond, then the lowercase serif wordmark with its
/// accent period.
///
/// The frond is the full five-blade fan — the same mark as the app icon and as
/// the one the launch animation unfurls — and it is measured by the mark itself
/// rather than by the tile it is drawn on. It is also the place that animation
/// hands off to, so it is held back until the flying frond is on top of it —
/// see [LaunchLogoSlot].
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  static const _size = 22.0;

  /// The mark stands taller than the wordmark's own letters, which is what it
  /// takes for the five-blade fan to stay open: below about 20pt the blades and
  /// the gaps between them close into a blob and the mark stops being the one
  /// on the app icon. The gap is the lockup's, in ems of the wordmark.
  static const _markHeight = 24.0;
  static const _gap = _size * 0.81;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        LaunchLogoSlot(child: PatraFrond(height: _markHeight)),
        SizedBox(width: _gap),
        PatraWordmark(size: _size),
      ],
    );
  }
}

/// A horizontal shelf of covers. Renders nothing at all when the section is
/// empty, so the home screen stays quiet rather than showing empty labels.
class _Shelf extends ConsumerWidget {
  const _Shelf({
    required this.label,
    required this.series,
    required this.onReturn,
    this.showProgress = false,
  });

  final String label;
  final AsyncValue<List<Series>> series;
  final bool showProgress;

  /// What to ask again once a tile's screen has been popped. The screen owns
  /// its providers, so the shelf does not name them.
  final Future<void> Function() onReturn;

  static const _tileWidth = 112.0;

  /// A shelf runs edge to edge on any screen — that is what a shelf is — so a
  /// tablet spends its width on bigger covers rather than on margins.
  static const _tabletTileWidth = 152.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (series.hasValue && series.requireValue.isEmpty) {
      return const SizedBox.shrink();
    }
    if (series.hasError && !series.hasValue) return const SizedBox.shrink();

    final client = series.hasValue ? ref.watch(kavitaClientProvider) : null;
    final items = series.value ?? const <Series>[];
    final tileWidth = isTabletLayout(context) ? _tabletTileWidth : _tileWidth;

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
            height: tileWidth / coverAspectRatio + 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              itemCount: client == null ? 4 : items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                if (client == null) {
                  return SizedBox(
                    width: tileWidth,
                    child: const Column(
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
                  width: tileWidth,
                  child: CoverTile(
                    url: client.seriesCoverUrl(s.id),
                    headers: client.imageHeaders,
                    title: s.name,
                    serifTitle: true,
                    progress: progress,
                    onTap: () async {
                      await context.push(seriesLocation(s));
                      // Reading changes progress, and which series is
                      // promoted follows from it — so the hero's chapter has
                      // to be asked about again too, not just the shelves.
                      await onReturn();
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

  final AsyncValue<List<Library>> libraries;

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
                : LayoutBuilder(
                    // A card holds a name and an icon: two of them across a
                    // tablet are two long empty bars. The row gains cards
                    // instead, and the cards keep the size they are drawn at.
                    builder: (context, constraints) {
                      final width = _cardWidth(constraints.maxWidth);
                      return Wrap(
                        spacing: _cardSpacing,
                        runSpacing: _cardSpacing,
                        children: [
                          for (final library in items)
                            _LibraryCard(
                              library: library,
                              width: width,
                              onTap: () {
                                ref
                                    .read(selectedLibraryProvider.notifier)
                                    .select(library.id);
                                context.go('/library');
                              },
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

const _cardSpacing = 12.0;

/// The width a library card is drawn at, past which the row takes another
/// card rather than stretching the ones it has. Two across on a phone, as the
/// handoff draws it, whatever the phone's width.
const _cardMaxWidth = 200.0;

double _cardWidth(double available) {
  final columns = ((available + _cardSpacing) / (_cardMaxWidth + _cardSpacing))
      .ceil()
      .clamp(2, 8);
  return (available - _cardSpacing * (columns - 1)) / columns;
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.library,
    required this.width,
    required this.onTap,
  });

  final Library library;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: patraSurface,
        borderRadius: BorderRadius.circular(radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusCard),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radiusCard),
              border: Border.all(color: patraBorder),
            ),
            child: Row(
              children: [
                Icon(_libraryIcon(library.type), size: 18, color: patraAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    library.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PatraText.rowTitle(),
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
