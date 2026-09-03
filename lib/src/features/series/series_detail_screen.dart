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
import '../../entity_naming.dart';
import '../../theme.dart';
import '../../widgets/cover.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/save_pill.dart';
import '../library/library_screen.dart';

final volumesProvider = FutureProvider.autoDispose.family<List<Volume>, int>(
  retry: serverRetry,
  (ref, seriesId) {
    return ref.watch(kavitaClientProvider).volumes(seriesId);
  },
);

/// Progress the user has just set by hand, before the server has confirmed it.
///
/// A swipe has to land at once — waiting for a round trip to redraw a row
/// makes the gesture feel broken — and re-fetching instead would drop the whole
/// list to its skeleton for the length of the request. So the change is held
/// here, on top of the fetch, and the fetch is left alone. The map lives and
/// dies with the screen: on the next visit the server is the authority again.
class ReadOverridesNotifier extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => const {};

  void set(int chapterId, int pagesRead) =>
      state = {...state, chapterId: pagesRead};

  /// Drops an override, either because the server refused it or because
  /// something truer is about to arrive.
  void clear(int chapterId) => state = {...state}..remove(chapterId);
}

final readOverridesProvider =
    NotifierProvider.autoDispose<ReadOverridesNotifier, Map<int, int>>(
      ReadOverridesNotifier.new,
    );

/// The volumes as the screen shows them: what the server last said, with any
/// unconfirmed mark-read applied on top.
final seriesVolumesProvider = Provider.autoDispose
    .family<AsyncValue<List<Volume>>, int>((ref, seriesId) {
      final overrides = ref.watch(readOverridesProvider);
      final volumes = ref.watch(volumesProvider(seriesId));
      if (overrides.isEmpty) return volumes;
      return volumes.whenData(
        (volumes) => [
          for (final volume in volumes)
            volume.withChapters([
              for (final chapter in volume.chapters)
                overrides.containsKey(chapter.id)
                    ? chapter.copyWith(pagesRead: overrides[chapter.id])
                    : chapter,
            ]),
        ],
      );
    });

final seriesProvider = FutureProvider.autoDispose.family<Series, int>(
  retry: serverRetry,
  (ref, seriesId) => ref.watch(kavitaClientProvider).series(seriesId),
);

final seriesMetadataProvider = FutureProvider.autoDispose
    .family<SeriesMetadata, int>(
      retry: serverRetry,
      (ref, seriesId) =>
          ref.watch(kavitaClientProvider).seriesMetadata(seriesId),
    );

/// The three buckets Kavita splits a series into, from the one call we make.
///
/// Kavita exposes them ready-made on `GET /api/Series/series-detail`, but that
/// endpoint is documented as internal ("may change without hesitation") and
/// returns labels already formatted in the *server account's* locale, which
/// would fight our own. So we take `/api/Series/volumes` and apply its rules
/// ourselves: the pseudo-volumes are told apart by the sign of their number,
/// and every list is ordered by `sortOrder`, never by the order of the array.
typedef _Buckets = ({
  List<Volume> numberedVolumes,
  List<Chapter> loose,
  List<Chapter> specials,
});

_Buckets _split(List<Volume> volumes) {
  final numberedVolumes = <Volume>[];
  final loose = <Chapter>[];
  final specials = <Chapter>[];
  for (final volume in volumes) {
    final numbered = !volume.isLooseLeaf && !volume.isSpecials;
    if (numbered) numberedVolumes.add(volume);
    for (final chapter in volume.chapters) {
      if (chapter.isSpecial) {
        specials.add(chapter);
      } else if (!numbered) {
        // Neither pseudo-volume is a place to hide a chapter: Kavita flags
        // everything it files under specials, but one that arrives without
        // the flag must still have a row, or it could be neither read nor
        // saved. Kavita lists it too.
        loose.add(chapter);
      }
    }
  }
  loose.sort(_bySortOrder);
  specials.sort(_bySortOrder);
  return (numberedVolumes: numberedVolumes, loose: loose, specials: specials);
}

/// The chapters a numbered volume shows: a special inside one is listed under
/// Specials, and would otherwise appear twice on a screen that has sections
/// rather than tabs.
List<Chapter> _volumeChapters(Volume volume) => _sorted([
  for (final c in volume.chapters)
    if (!c.isSpecial) c,
]);

int _bySortOrder(Chapter a, Chapter b) =>
    a.sortOrder.compareTo(b.sortOrder);

List<Chapter> _sorted(List<Chapter> chapters) =>
    [...chapters]..sort(_bySortOrder);

typedef _Entry = ({Volume volume, Chapter chapter});

/// Every chapter in reading order — volumes first, then loose chapters, then
/// specials, the order the sections below are rendered in — each paired with
/// the volume it belongs to, which is what names a chapterless volume.
List<_Entry> _orderedChapters(List<Volume> volumes) {
  final inVolumes = <_Entry>[];
  final loose = <_Entry>[];
  final specials = <_Entry>[];
  for (final volume in volumes) {
    final numbered = !volume.isLooseLeaf && !volume.isSpecials;
    for (final chapter in _sorted(volume.chapters)) {
      final entry = (volume: volume, chapter: chapter);
      if (chapter.isSpecial) {
        specials.add(entry);
      } else if (numbered) {
        inVolumes.add(entry);
      } else {
        loose.add(entry);
      }
    }
  }
  for (final list in [loose, specials]) {
    list.sort((a, b) => _bySortOrder(a.chapter, b.chapter));
  }
  return [...inVolumes, ...loose, ...specials];
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
    final volumes = ref.watch(seriesVolumesProvider(seriesId));
    // What the parts of this series are called comes from the library type.
    final type = ref.watch(libraryTypeProvider(libraryId));

    return Scaffold(
      appBar: AppBar(
        // The hero below carries the serif title; the bar keeps a compact one.
        title: Text(
          seriesName,
          style: PatraText.rowTitle().copyWith(fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [OfflineIndicator()],
      ),
      // One row open at a time, and scrolling closes it.
      body: SlidableAutoCloseBehavior(
        child: SafeArea(
          top: false,
          // The rows run at the app's own margin, like every other screen.
          // A cap here centred a narrow column between two wide empty bands,
          // which read as more wrong than the gap it closed inside the row.
          // The answer to a tablet's width is a grid, not a narrower column.
          // The hero renders as soon as the cover URL is known, so the
          // chapter list loading underneath never blocks it.
          child: ListView(
            padding: const EdgeInsets.only(bottom: sectionGap),
            children: [
              _SeriesHero(
                seriesId: seriesId,
                seriesName: seriesName,
                type: type,
                volumes: volumes.value,
                onRead: (chapter) => _read(context, ref, chapter),
              ),
              ...switch (volumes) {
                AsyncData(:final value) => _buildSections(
                  context,
                  ref,
                  client,
                  l10n,
                  type,
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
                          style: PatraText.body(color: patraTextMuted),
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
    Chapter chapter,
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
    LibraryType type,
    List<Volume> volumes,
  ) {
    final buckets = _split(volumes);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(gutter, sectionGap, gutter, 8),
      child: SectionLabel(text),
    );

    Widget chapterRow(Chapter chapter, {String? label, String? coverUrl}) =>
        _ChapterRow(
          chapter: chapter,
          label: label,
          type: type,
          coverUrl: coverUrl ?? client.chapterCoverUrl(chapter.id),
          seriesId: seriesId,
          seriesName: seriesName,
          libraryId: libraryId,
        );

    // Volumes and volumeless chapters are one story told in order — Kavita
    // calls that the storyline, and hides it where it would lie: an issue run
    // is not a storyline, and a book library has no chapter level. It only
    // says anything when the series actually has both, so a run of volumes
    // stays "Volumes".
    final merged =
        type.hasStoryline &&
        buckets.numberedVolumes.isNotEmpty &&
        buckets.loose.isNotEmpty;

    return [
      if (buckets.numberedVolumes.isNotEmpty) ...[
        header(merged ? type.storylineTitle(l10n) : type.volumesTitle(l10n)),
        for (final volume in buckets.numberedVolumes)
          if (_volumeChapters(volume).length == 1 &&
              _volumeChapters(volume).single.isVolumePlaceholder)
            // No chapter breakdown: the volume itself is the reading unit.
            chapterRow(
              _volumeChapters(volume).single,
              label: type.volumeLabel(l10n, volume.name),
              coverUrl: client.volumeCoverUrl(volume.id),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 4),
              child: Text(
                type.volumeLabel(l10n, volume.name),
                style: PatraText.rowTitle(color: patraTextMuted),
              ),
            ),
            for (final chapter in _volumeChapters(volume)) chapterRow(chapter),
          ],
      ],
      if (buckets.loose.isNotEmpty) ...[
        // Inside the storyline the loose chapters simply follow the volumes,
        // exactly as Kavita orders them; they only get a header of their own
        // when they are a list apart.
        if (!merged) header(type.chaptersTitle(l10n)),
        for (final chapter in buckets.loose) chapterRow(chapter),
      ],
      if (buckets.specials.isNotEmpty) ...[
        header(type.specialsTitle(l10n)),
        for (final chapter in buckets.specials) chapterRow(chapter),
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
    required this.type,
    required this.volumes,
    required this.onRead,
  });

  final int seriesId;
  final String seriesName;

  /// Names the resume button in the library's own vocabulary.
  final LibraryType type;

  /// Null while the chapter list is still loading: the button waits for it.
  final List<Volume>? volumes;
  final void Function(Chapter chapter) onRead;

  static const _coverWidth = 124.0;
  static const _coverHeight = 182.0;

  /// The same hero, given a tablet's room: the cover keeps its proportions.
  static const _tabletCoverWidth = 160.0;
  static const _tabletCoverHeight = 235.0;

  /// The action button says two or three words. Let it fill a tablet's hero
  /// and it stops reading as a button at all — it becomes a banner.
  static const _actionMaxWidth = 280.0;

  /// The chapter the button opens: the first one not finished, else the first.
  ({_Entry entry, bool started, bool allRead})? _target() {
    final entries = volumes == null ? null : _orderedChapters(volumes!);
    if (entries == null || entries.isEmpty) return null;
    // "Started" is a fact about the *series*, not about the chapter the button
    // happens to land on. Finishing a volume leaves the next one untouched, so
    // reading it against the target alone made the button say "Start reading"
    // to someone halfway through a series. Kavita's own web client asks it of
    // the series too — `hasReadingProgress` is that client's concept and is
    // not an API field, so this mirrors its rule rather than reading a value.
    final started = entries.any((entry) => entry.chapter.pagesRead > 0);
    for (final entry in entries) {
      final chapter = entry.chapter;
      final read = chapter.pages > 0 && chapter.pagesRead >= chapter.pages;
      if (!read) {
        return (entry: entry, started: started, allRead: false);
      }
    }
    return (entry: entries.first, started: started, allRead: true);
  }

  /// What to call the thing the button opens, in the library's own unit.
  ///
  /// Only what is *numbered* gets named — a volume, a chapter, an issue, a
  /// book — because those are two words wide. A title is free text: a book's
  /// stretches the button across the hero, and a Book library would do it
  /// every time, since its files often carry a title and no number at all.
  /// There the button says only what it does; the title is already on the row
  /// it opens.
  String _resumeLabel(_Entry entry, AppLocalizations l10n) {
    final chapter = entry.chapter;

    // A special is never numbered, whatever the library counts in.
    if (chapter.isSpecial) return l10n.seriesContinuePlain;
    // A volume with no chapter breakdown is named after the volume: its
    // placeholder chapter carries Kavita's -100000 sentinel, which must never
    // reach the label.
    if (chapter.isVolumePlaceholder &&
        !entry.volume.isLooseLeaf &&
        !entry.volume.isSpecials) {
      return type.continueVolumeLabel(l10n, entry.volume.name);
    }
    // Anything at sentinel scale is Kavita bookkeeping, not a chapter number.
    // Compared on magnitude: the sentinels differ by sign, this check does not.
    final number = num.tryParse(chapter.range)?.abs() ?? 0;
    if (chapter.range.isNotEmpty && number < Chapter.defaultNumber.abs()) {
      return type.continueChapterLabel(l10n, chapter.range);
    }
    return l10n.seriesContinuePlain;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tablet = isTabletLayout(context);
    final coverWidth = tablet ? _tabletCoverWidth : _coverWidth;
    final coverHeight = tablet ? _tabletCoverHeight : _coverHeight;
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
            width: coverWidth,
            height: coverHeight,
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
              height: coverHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    seriesName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: PatraText.serifTitle(size: tablet ? 25 : 21),
                  ),
                  const SizedBox(height: 6),
                  if (credits.isNotEmpty)
                    Text(
                      credits,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PatraText.metadata(size: 12),
                    )
                  else if (metadata == null)
                    const Skeleton(height: 11, width: 150),
                  const SizedBox(height: 6),
                  if (stats.isNotEmpty)
                    Text(stats, style: PatraText.metadata(size: 12))
                  else
                    const Skeleton(height: 11, width: 110),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _actionMaxWidth,
                    ),
                    child: SizedBox(
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
    required this.type,
    required this.seriesId,
    required this.seriesName,
    required this.libraryId,
    this.label,
  });

  final Chapter chapter;
  final String coverUrl;

  /// Names the row in the library's own vocabulary.
  final LibraryType type;
  final int seriesId;
  final String seriesName;
  final int libraryId;

  /// Overrides the derived label, for a volume shown as a single row.
  final String? label;

  /// The swipe panes are sized in points, not in a share of the row.
  ///
  /// A ratio that gives a phone a sensible drawer slides a tablet's row a
  /// third of 820pt off screen, taking the cover and the title with it — so
  /// the swipe hides the very thing it is about to act on. These are the
  /// widths the ratios used to come to on a phone; `_paneRatio` turns them
  /// back into a ratio against whatever width the row actually got.
  static const _markPaneWidth = 116.0;
  static const _removePaneWidth = 94.0;

  /// Never wider than a third of the row (a narrow phone), never so narrow
  /// that the action's own label has nowhere to sit.
  static double _paneRatio(double target, double available) =>
      available <= 0 ? .3 : (target / available).clamp(.15, .34);

  String _label(AppLocalizations l10n) =>
      label ?? type.chapterTitle(l10n, chapter);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tablet = isTabletLayout(context);
    final coverWidth = tablet ? rowCoverWidthTablet : rowCoverWidth;
    final coverHeight = tablet ? rowCoverHeightTablet : rowCoverHeight;
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
    // EPUB and PDF are laid out, not paginated into images: the reader has
    // nothing to show and the server will not serve pages for them.
    final readable = chapter.format.isImageReadable;
    // Offline, a chapter that is not stored locally cannot be opened.
    final openable = readable && (saved || !offline);

    final row = Container(
      // Rows are separated by a hairline, not by whitespace.
      padding: EdgeInsets.symmetric(vertical: tablet ? 14 : 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: .06)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: coverWidth,
            height: coverHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(
                  url: coverUrl,
                  headers: ref.watch(kavitaClientProvider).imageHeaders,
                  radius: radiusThumb,
                  // Derived from the width actually drawn, never a constant:
                  // 138 was the phone's number (46pt at 3x) and left a tablet
                  // decoding an 80pt cover at half its size — the blur the
                  // bigger cover was meant to remove. Kavita's cover endpoint
                  // serves a fixed size, so asking past it costs nothing.
                  memCacheWidth:
                      (coverWidth * MediaQuery.devicePixelRatioOf(context))
                          .round(),
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
                    top: tablet ? 4 : 3,
                    right: tablet ? 4 : 3,
                    child: Container(
                      // The badge sits *on* the cover: left at 16 it goes
                      // back to being a pea on the bigger one.
                      width: tablet ? 20 : 16,
                      height: tablet ? 20 : 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: patraAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .6),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check,
                        size: tablet ? 13 : 10,
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
                        style: PatraText.rowTitle(
                          color: read ? patraTextMuted : patraText,
                          size: tablet ? 15 : 13.5,
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
                  style: PatraText.metadata(size: tablet ? 12 : 11),
                ),
                if (!readable) ...[
                  const SizedBox(height: 3),
                  Text(
                    l10n.formatNotSupported,
                    style: PatraText.metadata(color: patraTextMuted),
                  ),
                ],
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
                        valueColor: const AlwaysStoppedAnimation(patraAccent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (readable)
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

    // Marking read is a server operation; offline there is nothing to swipe
    // for. Removing a copy is local, so it stays available either way. A
    // format we cannot open is still markable — it was read somewhere else,
    // which is exactly when saying so by hand is worth something.
    final markable = !offline;
    if (!saved && !markable) return tile;
    return LayoutBuilder(
      // The panes are asked for as a ratio, so the row has to be measured
      // before they can be given a width that means the same thing on every
      // screen.
      builder: (context, constraints) => Slidable(
        key: ValueKey(chapter.id),
        groupTag: 'chapters',
        // Progress on the leading edge, destruction on the trailing one: a
        // swipe that reaches for one can never land on the other.
        startActionPane: markable
            ? ActionPane(
                motion: const DrawerMotion(),
                extentRatio: _paneRatio(_markPaneWidth, constraints.maxWidth),
                children: [
                  SlidableAction(
                    onPressed: (_) => _setRead(ref, read: !read),
                    // Reading progress is the accent's job, here as everywhere.
                    backgroundColor: patraAccent.withValues(alpha: .16),
                    foregroundColor: patraAccent,
                    icon: read ? Icons.remove_done : Icons.done_all,
                    label: read ? l10n.markUnread : l10n.markRead,
                  ),
                ],
              )
            : null,
        endActionPane: saved
            ? ActionPane(
                motion: const DrawerMotion(),
                extentRatio: _paneRatio(_removePaneWidth, constraints.maxWidth),
                children: [
                  SlidableAction(
                    onPressed: (actionContext) async {
                      if (await _confirmRemove(actionContext, l10n)) {
                        await ref
                            .read(downloadsProvider.notifier)
                            .remove(chapter.id);
                      }
                    },
                    backgroundColor: patraDanger.withValues(alpha: .16),
                    foregroundColor: patraDanger,
                    icon: Icons.delete_outline,
                    label: l10n.removeDownload,
                  ),
                ],
              )
            : null,
        // The pane takes its width out of the row rather than out from under
        // it: the row keeps its origin and every part of itself.
        child: _SqueezedByPane(child: tile),
      ),
    );
  }

  /// Marks the row read or unread on the server, which stays the authority on
  /// progress: the rows and the hero are rebuilt from what it says afterwards.
  Future<void> _setRead(WidgetRef ref, {required bool read}) async {
    final KavitaClient client;
    try {
      client = ref.read(kavitaClientProvider);
    } on StateError {
      return; // signed out from under the row
    }
    final pagesRead = read ? chapter.pages : 0;
    final overrides = ref.read(readOverridesProvider.notifier);
    // The row redraws on this line, not when the server answers.
    overrides.set(chapter.id, pagesRead);
    // Keep the stored copy in step: the Downloads tab has to show progress
    // with no server at all.
    if (ref.read(savedChapterProvider(chapter.id)) != null) {
      await ref
          .read(downloadsProvider.notifier)
          .recordProgress(chapter.id, pagesRead);
    }

    try {
      await client.markChapterRead(
        seriesId: seriesId,
        chapterId: chapter.id,
        read: read,
      );
    } on Exception {
      // Refused: put the row back where the server still has it. A request
      // that could not reach the server has already raised the offline
      // banner, which says more than a toast on one row would.
      //
      // Unless the screen is gone — leaving takes the override with it, and
      // an autoDispose notifier throws if it is written to after that.
      if (ref.context.mounted) overrides.clear(chapter.id);
      return;
    }
    // The cover's progress ring is series-wide and cannot be guessed from one
    // chapter. Re-fetching it is flash-free — the hero reads the value, which
    // survives a refresh — so it catches up on its own.
    if (ref.context.mounted) ref.invalidate(seriesProvider(seriesId));
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
        backgroundColor: patraSurface,
        title: Text(
          l10n.removeDownloadConfirm(
            [seriesName, _label(l10n)].where((p) => p.isNotEmpty).join(' — '),
          ),
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

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    // Reading is about to define progress properly; a mark-read held on top
    // of the fetch would overwrite whatever comes back.
    ref.read(readOverridesProvider.notifier).clear(chapter.id);
    final started = chapter.pagesRead > 0 && chapter.pagesRead < chapter.pages;
    await context.push(
      '/reader/${chapter.id}?page=${started ? chapter.pagesRead : 0}',
    );
    // Progress changed while reading: the rows and the hero both show it.
    ref.invalidate(volumesProvider(seriesId));
    ref.invalidate(seriesProvider(seriesId));
  }
}

/// Opens a swipe pane by *squeezing* the row instead of sliding it aside.
///
/// `Slidable` uncovers a pane by translating its whole child, which on a row
/// this wide carries the cover and the title off with it — the swipe hides the
/// very thing it is about to act on, and on a screen where the list is a
/// centred column the row slides out of that column and over the margin.
///
/// Here the pane takes its width *from* the row: the leading edge stays put
/// for a trailing pane (and the trailing edge for a leading one), nothing
/// leaves the screen, and the row is merely narrower while the pane is open.
///
/// It works from inside the translation the library already applies — undo
/// that, then hand the pane's edge the same width as padding. `ratio` is
/// signed (positive while the leading pane opens) and is a fraction of the
/// row, which is exactly what `SlideTransition` moves the child by.
class _SqueezedByPane extends StatelessWidget {
  const _SqueezedByPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = Slidable.of(context);
    if (controller == null) return child;
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: controller.animation,
        // The row itself is built once and reused on every frame of the
        // gesture; only the offset and the padding around it change.
        child: child,
        builder: (context, row) {
          final shift = controller.ratio * constraints.maxWidth;
          // A drag can pull the row well past the pane it is uncovering. Only
          // the pane's own width is squeezed out of the row; the rest of the
          // finger's travel stays the slide the library was going to make
          // anyway, which is what gives the over-drag its rubber band.
          final extent =
              (shift > 0
                  ? controller.startActionPaneExtentRatio
                  : controller.endActionPaneExtentRatio) *
              constraints.maxWidth;
          final open = shift.clamp(-extent, extent);
          return Transform.translate(
            offset: Offset(-open, 0),
            child: Padding(
              // Visual left/right rather than start/end: the library places
              // its panes visually too.
              padding: EdgeInsets.only(
                left: open > 0 ? open : 0,
                right: open < 0 ? -open : 0,
              ),
              child: row,
            ),
          );
        },
      ),
    );
  }
}

/// The READ mark: tracked text beside a finished chapter's title, in the
/// accent — the same colour as the badge on its cover, since both say the
/// same thing about reading progress.
final _readTagStyle = PatraText.metadata(
  color: patraAccent,
  size: 10.5,
).copyWith(fontWeight: FontWeight.w600, letterSpacing: .5);

class _RowsSkeleton extends StatelessWidget {
  const _RowsSkeleton();

  @override
  Widget build(BuildContext context) {
    // The skeleton stands in for the rows, so it grows with them.
    final tablet = isTabletLayout(context);
    return Column(
      children: List.generate(
        6,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 6),
          child: Row(
            children: [
              Skeleton(
                width: tablet ? rowCoverWidthTablet : rowCoverWidth,
                height: tablet ? rowCoverHeightTablet : rowCoverHeight,
              ),
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
