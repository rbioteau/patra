import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../catalogue/catalogue_overlay.dart';
import '../../catalogue/catalogue_provider.dart';
import '../../downloads/downloads_provider.dart';
import '../../resume_point.dart';
import '../../routes.dart';
import '../../theme.dart';
import '../../widgets/cover.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/patra_frond.dart';
import '../../widgets/patra_wordmark.dart';
import '../../widgets/profile_avatar.dart';
import '../launch/launch_animation.dart';
import '../library/library_screen.dart';
import '../series/series_detail_screen.dart';
import 'continue_hero.dart';

/// The next thing to read in each series — the "On deck" shelf, and the
/// candidates the Continue hero is promoted from.
///
/// **One request answers both, because it is one question.** Kavita builds
/// this from `PagesRead > 0 && PagesRead < Pages` plus a recency clause
/// (`LatestReadDate >= now - OnDeckProgressDays`, or a chapter added inside
/// `OnDeckUpdateDays`), which is exactly "started, unfinished, and still
/// live". The hero used to come from `/api/Series/currently-reading`
/// instead, on the reading that its name is the question — and it is not:
/// Kavita builds *that* from `ReadLast GreaterThan OnDeckProgressDays`, a
/// comparison `SeriesFilter.HasReadLast` deliberately inverts into
/// `MaxDate < now - N`. It is the pile you started and have not touched in
/// over a month, the **complement** of this one, so anybody reading
/// regularly had no hero at all while this very shelf listed what they were
/// reading.
final onDeckFetchProvider = FutureProvider.autoDispose<List<Series>>(
  retry: serverRetry,
  (ref) async {
    final client = ref.watch(kavitaClientProvider);
    // In hand before the request: see `librariesFetchProvider`.
    final store = ref.read(catalogueStoreProvider);
    final series = await client.onDeck();
    await store.putOnDeck(series);
    return series;
  },
);

/// The shelf as Home draws it: the server's ranking where there is one, and
/// otherwise the last one the device was given.
///
/// This is the provider to watch — see `librariesProvider` for the whole of
/// why, and `onDeckOverlay` for what a stored ranking is and is not. It is
/// **not decorated**: the app bar's struck-through cloud already says the
/// answer may be old, and per ADR-0005 an individual row never carries a
/// mark of its own.
///
/// An offline Home that says "nothing here, try Downloads" while the device
/// knows perfectly well what was being read is the inconsistency the
/// catalogue exists to remove — so `_OfflineHome` below now stands only
/// where the catalogue is empty too.
final onDeckProvider = Provider.autoDispose<AsyncValue<List<Series>>>(
  (ref) => onDeckOverlay(ref, onDeckFetchProvider),
);

/// Whether there is a hero at all, and what it says.
///
/// Null means the hero is not drawn *and* the On deck shelf keeps its series
/// — the two are one decision, or a series that failed to be promoted would
/// vanish from the home screen entirely. It is null when nothing is in
/// progress and when the volumes can be neither fetched nor remembered; it is
/// non-null with a null `point` while they are still being looked for, so the
/// card can show its cover and title without waiting.
///
/// **Being offline is no longer one of those cases.** It used to short-circuit
/// on `offlineProvider`, which was the honest answer while the volumes could
/// only come from a server; now the card comes along for free with the
/// catalogue, drawing wherever the featured series' volumes happen to have
/// been stored. Where they have not, nothing new is needed — the volumes
/// overlay resolves into its fetch's failure, `hasError` is what it always
/// was, and the series stays in the shelf below.
final continueHeroProvider = Provider.autoDispose<ContinueHeroData?>((ref) {
  final started = ref.watch(onDeckProvider).value;
  final featured = featuredSeries(started ?? const []);
  if (featured == null) return null;
  // Deliberately one layer down from `seriesVolumesProvider`, which lays the
  // series screen's optimistic mark-read on top of this: that override map is
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
    // The hero's chapter is a third request, hanging off whichever series is
    // promoted. A pull has to reach it too, or the card would keep naming the
    // chapter the shelf has just stopped agreeing with.
    final featured = ref.read(continueHeroProvider)?.series.id;
    if (featured != null) ref.invalidate(volumesFetchProvider(featured));
    ref.invalidate(onDeckFetchProvider);
    ref.invalidate(librariesFetchProvider);
    await Future.wait([
      ref.read(onDeckFetchProvider.future),
      ref.read(librariesFetchProvider.future),
    ]).catchError((Object _) => const <List<Object>>[]);
    // The shelves have moved, so the promoted series may not be the one whose
    // chapter was invalidated above.
    final promoted = ref.read(continueHeroProvider)?.series.id;
    if (promoted != null && promoted != featured) {
      ref.invalidate(volumesFetchProvider(promoted));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hero = ref.watch(continueHeroProvider);
    final onDeck = _without(ref.watch(onDeckProvider), hero?.series.id);
    final libraries = ref.watch(librariesProvider);

    // Every clause has to be a *resolved* emptiness. `hero == null` alone is
    // also true while the promotion is merely unknown — in flight, or offline
    // — so keying the copy on it flashes "nothing here" over a library that
    // has plenty. An unresolved provider has a null value and fails the test.
    final everythingEmpty =
        hero == null &&
        (onDeck.value?.isEmpty ?? false) &&
        (libraries.value?.isEmpty ?? false);

    // Nothing arrived and nothing is still coming: every shelf has resolved,
    // and resolved into a failure. Offline that is the ordinary state of a
    // device on a train rather than a fault — but a screen with nothing
    // whatever on it explains nothing, so it says so and names the one tab
    // that still has something.
    //
    // This is **not** the banner this app removed. That one said the
    // indicator's own sentence across the top of content that existed, on
    // three screens at once; this is an empty state, drawn only when there is
    // no content at all, in words of its own — which is what keeps the
    // indicator's sentence unique to the indicator
    // (`test/offline_indicator_test.dart`).
    final offline = ref.watch(offlineProvider);
    final nothingCameBack =
        hero == null &&
        onDeck.isResolvedFailure &&
        libraries.isResolvedFailure;

    return Scaffold(
      appBar: AppBar(
        title: const _Wordmark(),
        // The face last, on the very edge: being offline is a passing
        // status, and this is the one piece of furniture that says whose
        // app this is.
        actions: const [OfflineIndicator(), _ProfileFace()],
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
              if (nothingCameBack && offline) const _OfflineHome(),
              if (hero != null)
                ContinueHero(data: hero, onReturn: () => _refresh(ref)),
              // On deck is the only list, and the hero is drawn from the very
              // same answer — see `onDeckProvider`. Nothing else is fetched
              // for the promotion, so the card and the shelf under it can
              // never disagree about what is being read.
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

/// What Home says when the server is out of reach and there is nothing to
/// draw.
///
/// The way out is drawn in `patraOffline`, because that is what teal means
/// in this app: downloads and offline. Never the accent, which is reading progress and
/// identity.
///
/// The way out is offered **only where it leads somewhere** — a device with
/// nothing saved is told plainly that there is nothing saved, rather than
/// handed a button onto an empty tab. That is the whole reason this reads
/// the downloads at all.
class _OfflineHome extends ConsumerWidget {
  const _OfflineHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(downloadsProvider).value?.saved.isNotEmpty ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: gutter,
        vertical: sectionGap * 1.5,
      ),
      // One stop for a screen reader: the sentence and the way out are one
      // thing to hear, not two.
      child: MergeSemantics(
        child: Column(
          children: [
            // No icon. The bar already carries the struck-through cloud, and
            // a second one under it is the same status said twice; Home's
            // other empty state is words alone for the same reason. The
            // button below keeps a glyph because it is about where it goes,
            // not about what has happened.
            Text(
              saved ? l10n.homeOfflineWithSaved : l10n.homeOfflineNothingSaved,
              textAlign: TextAlign.center,
              style: PatraText.body(color: patraTextMuted),
            ),
            if (saved) ...[
              const SizedBox(height: 20),
              ConstrainedBox(
                // A button given a whole screen to fill stops reading as a
                // button, which is the rule the resume and sign-out buttons
                // already follow.
                constraints: const BoxConstraints(maxWidth: 280),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/downloads'),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: Text(l10n.seeDownloads),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: patraOffline,
                      side: BorderSide(
                        color: patraOffline.withValues(alpha: .45),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
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

/// Whoever is reading, and the way to hand the app over.
///
/// It does exactly one thing: it opens the picker. Switching keeps every
/// credential, so what it costs the person leaving is a tap to come back and
/// never a password; the other verb, removing a profile, is in Settings.
///
/// **It is drawn on a device holding one profile too**, and that is not the
/// tap `AuthState.atLaunch` exists to spare — that rule is about a cold
/// start, about being asked a question with one answer rather than about
/// answering one deliberately. With no sign-out button left, this face is
/// the *only* way a one-profile device ever becomes a two-profile device:
/// the add slot lives on the picker, and this is the door to it.
/// `signedOutLocation` is where a lone profile landing on the picker is
/// already reasoned about.
class _ProfileFace extends ConsumerWidget {
  const _ProfileFace();

  /// Small enough to sit in a 56pt bar beside the wordmark, big enough for a
  /// letter to be read at arm's length. An IconButton's own 48pt box is what
  /// makes it a target.
  static const _size = 30.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    // Nothing to draw with no session: this bar is behind the redirect, but
    // it can be built once more on the way out of one.
    if (session == null) return const SizedBox.shrink();

    return IconButton(
      // The tooltip is the semantics label too, which is what a face on its
      // own says to nobody.
      tooltip: l10n.switchProfile,
      icon: ProfileAvatar(profile: session, size: _size),
      onPressed: () => ref.read(authProvider.notifier).switchProfile(),
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
    if (series.isResolvedFailure) return const SizedBox.shrink();

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
    // A resolved failure is not a slow answer, and this section used to ask
    // only `value == null`, which is both — so offline it shimmered for an
    // answer that was never coming. The shelves already asked the right
    // question; this is now the same one, named once.
    if (libraries.isResolvedFailure) return const SizedBox.shrink();

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
