import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/kavita_client.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../catalogue/catalogue_reads.dart' as catalogue;
import '../../downloads/downloads_provider.dart';
import '../../downloads/downloads_service.dart';
import '../../entity_naming.dart';
import '../../resume_point.dart';
import '../../routes.dart';
import '../../settings/device_hints.dart';
import '../../settings/profile_preferences.dart';
import '../../theme.dart';
import '../../widgets/cover.dart';
import '../../widgets/download_badge.dart';
import '../../widgets/read_mark.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/series_hero.dart';
import '../../widgets/mobile_data_gate.dart';
import 'series_selection.dart';

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

/// How the rows under the hero are ordered — three answers, offered as pills.
///
/// [readingPosition] is the default and the prototype's argument for the
/// screen: the chapter under way first, then what comes next, with everything
/// already read folded away at the bottom, so the thing to read is above the
/// fold whatever the series' length. [oldest] is the storyline as Kavita
/// sections it — volumes, loose chapters, specials — and [newest] is the same
/// sections read backwards, for a series one follows as it is published.
enum ChapterSort { readingPosition, newest, oldest }

/// What the list under the hero is showing: which order, and whether the
/// finished chapters are unfolded.
///
/// Screen-scoped rather than a preference: it dies with the screen, so every
/// visit opens at the reading position with the read folded away — which is
/// the state the pills exist to make cheap to leave, not one worth carrying
/// from one series to the next.
typedef SeriesListView = ({ChapterSort sort, bool showRead});

class SeriesListViewNotifier extends Notifier<SeriesListView> {
  @override
  SeriesListView build() =>
      (sort: ChapterSort.readingPosition, showRead: false);

  void sortBy(ChapterSort sort) =>
      state = (sort: sort, showRead: state.showRead);

  void toggleRead() => state = (sort: state.sort, showRead: !state.showRead);
}

final seriesListViewProvider =
    NotifierProvider.autoDispose<SeriesListViewNotifier, SeriesListView>(
      SeriesListViewNotifier.new,
    );

/// The volumes as the screen shows them — three deep, and the order is the
/// whole of it: **what the device remembers, under what the server last
/// said, under any unconfirmed mark-read.**
///
/// The mark-read is on top because it is the newest word about a row and the
/// entire point of it is that the row redraws on the gesture rather than on
/// the round trip.
///
/// Between the two: **where the rows are the device's memory, the saved
/// copy's progress is laid over them.** There the saved copy is the newer
/// word — it is where offline reading writes, and the catalogue deliberately
/// never absorbs that (ADR-0005), so the stored volumes carry the server's
/// last word about a chapter somebody has since read on a train. Where the
/// server has answered, it is left alone: the server is the authority and
/// the saved copy is what gets corrected from it, which is the mirror in
/// [_ChapterRow]. Laying it here rather than in the row is what keeps the
/// hero's resume point and the row's own progress naming one number.
final seriesVolumesProvider = Provider.autoDispose
    .family<AsyncValue<List<Volume>>, int>((ref, seriesId) {
      final answer = ref.watch(catalogue.volumes(seriesId).overlaid);
      // Only where it applies: watching the saved chapters unconditionally
      // would rebuild every row of a live list on each tick of a download.
      final saved = answer.fromCatalogue
          ? ref.watch(downloadsProvider.select((s) => s.value?.saved))
          : null;
      final overrides = ref.watch(readOverridesProvider);
      if ((saved == null || saved.isEmpty) && overrides.isEmpty) {
        return answer.value;
      }
      return answer.value.whenData(
        (volumes) => [
          for (final volume in volumes)
            volume.withChapters([
              for (final chapter in volume.chapters)
                _withNewestProgress(chapter, saved, overrides),
            ]),
        ],
      );
    });

/// One chapter, carrying whichever of the three has the newest word about how
/// far through it is — see [seriesVolumesProvider] for why that order.
///
/// The saved copy wins over the stored volumes **unconditionally**: there is
/// no clock on either, and inventing one (or taking the larger number) would
/// get a mark-unread the server really did make exactly wrong. What keeps
/// that from walking a row backwards is `_ChapterRow`'s mirror, which in the
/// ordinary case has already carried the server's word into `meta.json` on
/// the same visit that wrote the catalogue.
Chapter _withNewestProgress(
  Chapter chapter,
  Map<int, SavedChapter>? saved,
  Map<int, int> overrides,
) {
  final override = overrides[chapter.id];
  if (override != null) return chapter.copyWith(pagesRead: override);
  final copy = saved?[chapter.id];
  if (copy == null) return chapter;
  return chapter.copyWith(pagesRead: copy.pagesRead);
}

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
    final numbered = volume.isNumbered;
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
  loose.sort(bySortOrder);
  specials.sort(bySortOrder);
  return (numberedVolumes: numberedVolumes, loose: loose, specials: specials);
}

/// The chapters a numbered volume shows: a special inside one is listed under
/// Specials, and would otherwise appear twice on a screen that has sections
/// rather than tabs.
List<Chapter> _volumeChapters(Volume volume) => sortedChapters([
  for (final c in volume.chapters)
    if (!c.isSpecial) c,
]);

/// One entry of the list under the hero, before either view draws it: the
/// chapter, what it is called where the chapter's own name is not the right
/// one, the cover it is drawn with, and the copy a save would make of it.
typedef _Entry = ({
  Chapter chapter,
  String label,
  String coverUrl,
  bool highlighted,
  SavedChapter request,
});

/// What the list is made of: headings, and the entries under them. The two
/// views differ only in how a run of entries is laid out — one row each, or
/// a grid of covers — so the headings, the groups and the orders are decided
/// once for both.
sealed class _Item {}

class _Heading extends _Item {
  _Heading(this.widget);
  final Widget widget;
}

class _EntryItem extends _Item {
  _EntryItem(this.entry);
  final _Entry entry;
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
    final type = ref.watch(catalogue.libraryTypeProvider(libraryId));
    final selecting = ref.watch(
      seriesSelectionProvider.select((selection) => selection != null),
    );
    SavedChapter request(Volume volume, Chapter chapter) =>
        _request(l10n, type, volume, chapter);

    return PopScope(
      // Back leaves the selection before it leaves the screen, which is what
      // back does wherever a mode stands in front of a page.
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(seriesSelectionProvider.notifier).clear();
      },
      child: Scaffold(
        appBar: selecting
            ? _SelectionAppBar(volumes: volumes.value)
            : AppBar(
                // The hero below carries the serif title; the bar keeps a
                // compact one.
                title: Text(
                  seriesName,
                  style: PatraText.rowTitle().copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: const [OfflineIndicator()],
              ),
        bottomNavigationBar: selecting
            ? _SelectionBar(
                volumes: volumes.value ?? const [],
                request: request,
              )
            : null,
        // One row open at a time, and scrolling closes it.
        body: SlidableAutoCloseBehavior(
          child: SafeArea(
            top: false,
            // The rows run at the app's own margin, like every other screen.
            // A cap here centred a narrow column between two wide empty
            // bands, which read as more wrong than the gap it closed inside
            // the row. The answer to a tablet's width is a grid, not a
            // narrower column. The hero renders as soon as the cover URL is
            // known, so the chapter list loading underneath never blocks it.
            child: ListView(
              padding: const EdgeInsets.only(bottom: sectionGap),
              children: [
                SeriesHero(
                  seriesId: seriesId,
                  seriesName: seriesName,
                  volumes: volumes,
                  onRead: (chapter, {required started}) =>
                      _read(context, ref, chapter, started: started),
                ),
                ...switch (volumes) {
                  AsyncData(:final value) => _buildList(
                    context,
                    ref,
                    client,
                    l10n,
                    type,
                    value,
                    request,
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
                            onPressed: () => ref.invalidate(
                              catalogue.volumes(seriesId).invalidatable,
                            ),
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
      ),
    );
  }

  /// The copy a save makes of [chapter], named the way its row is.
  SavedChapter _request(
    AppLocalizations l10n,
    LibraryType type,
    Volume volume,
    Chapter chapter,
  ) => SavedChapter(
    chapterId: chapter.id,
    seriesId: seriesId,
    volumeId: volume.id,
    libraryId: libraryId,
    seriesName: seriesName,
    // A volume with no chapter breakdown is the reading unit, so its copy is
    // named after the volume: the chapter carrying its pages is Kavita's
    // placeholder, whose number is the -100000 sentinel, and a copy named
    // "-100000" in the Downloads tab is a copy a reader cannot recognise. The
    // same choice the row's own label already makes.
    title: chapter.isVolumePlaceholder && volume.isNumbered
        ? type.volumeLabel(l10n, volume.name)
        : type.chapterTitle(l10n, chapter),
    pages: chapter.pages,
    bytes: 0,
    pagesRead: chapter.pagesRead,
    format: chapter.format,
    language: chapter.language,
  );

  /// Opens a chapter and refreshes what reading it may have changed.
  ///
  /// [started] is the hero's word, not this screen's: the hero knows which
  /// chapter it opens and whether it is under way, and it is the same hero the
  /// home screen draws — so the two cannot land on different pages of the
  /// same chapter.
  Future<void> _read(
    BuildContext context,
    WidgetRef ref,
    Chapter chapter, {
    required bool started,
  }) async {
    await context.push(readerLocation(chapter, started: started));
    ref.invalidate(catalogue.volumes(seriesId).invalidatable);
    ref.invalidate(catalogue.series(seriesId).invalidatable);
  }

  /// The header row, the one-time hint, and the entries under them in the
  /// view in force.
  List<Widget> _buildList(
    BuildContext context,
    WidgetRef ref,
    KavitaClient client,
    AppLocalizations l10n,
    LibraryType type,
    List<Volume> volumes,
    SavedChapter Function(Volume volume, Chapter chapter) request,
  ) {
    final listView = ref.watch(seriesListViewProvider);
    // A series nobody has switched follows what its contents make the
    // default; one somebody has switched is theirs from then on.
    final view =
        ref.watch(seriesViewsProvider.select((views) => views[seriesId])) ??
        defaultSeriesView(type, volumes);
    final selecting = ref.watch(
      seriesSelectionProvider.select((selection) => selection != null),
    );
    final hint =
        view == SeriesView.list &&
        !selecting &&
        (ref.watch(selectionHintVisibleProvider).value ?? false);

    final items = _items(context, ref, client, l10n, type, volumes, request);
    return [
      Padding(
        // The prototype's rhythm: a section gap above the header, 8 under
        // it. The controls' 44pt boxes already carry part of both around the
        // 36 they draw, so only the rest is padding here.
        padding: const EdgeInsets.fromLTRB(
          gutter,
          sectionGap - _SortButton.boxInset,
          gutter,
          8 - _SortButton.boxInset,
        ),
        // The header the prototype gives the list, and the edge its controls
        // hang off. It does **not** name the unit the way the prototype's
        // "Chapters" does: this list holds volumes, loose chapters and
        // specials at once, the repo already refuses to call four volumes
        // "4 chapters" in the hero's tally right above it, and the list heads
        // its own sections — so a unit here would both lie and say "Issues"
        // twice over in a comic library. It names the *series'* contents
        // instead, which is true whatever the sections turn out to be, and
        // collides with no header under it.
        child: SectionLabel(
          l10n.inThisSeries,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ViewSwitch(
                view: view,
                onPick: (picked) => ref
                    .read(seriesViewsProvider.notifier)
                    .set(seriesId, picked),
              ),
              const SizedBox(width: 8),
              _SortButton(
                sort: listView.sort,
                onPick: ref.read(seriesListViewProvider.notifier).sortBy,
              ),
            ],
          ),
        ),
      ),
      if (hint) const _SelectionHint(),
      ..._layout(context, items, view),
    ];
  }

  /// Lays the items out in [view]: one row per entry, or each run of entries
  /// between two headings cut into rows of covers.
  List<Widget> _layout(
    BuildContext context,
    List<_Item> items,
    SeriesView view,
  ) {
    Widget row(_Entry entry) => _ChapterRow(
      key: ValueKey(entry.chapter.id),
      entry: entry,
      seriesId: seriesId,
      seriesName: seriesName,
    );
    if (view == SeriesView.list) {
      return [
        for (final item in items)
          switch (item) {
            _Heading(:final widget) => widget,
            _EntryItem(:final entry) => row(entry),
          },
      ];
    }
    final columns = _gridColumns(context);
    final widgets = <Widget>[];
    var run = <_Entry>[];
    void flush() {
      for (var i = 0; i < run.length; i += columns) {
        widgets.add(
          _GridRow(
            columns: columns,
            first: i == 0,
            children: [
              for (final entry in run.skip(i).take(columns))
                _VolumeTile(
                  key: ValueKey(entry.chapter.id),
                  entry: entry,
                  seriesId: seriesId,
                  seriesName: seriesName,
                ),
            ],
          ),
        );
      }
      run = [];
    }

    for (final item in items) {
      switch (item) {
        case _Heading(:final widget):
          flush();
          widgets.add(widget);
        case _EntryItem(:final entry):
          run.add(entry);
      }
    }
    flush();
    return widgets;
  }

  /// Three covers across a phone, as the prototype draws them; a tablet is
  /// answered with more columns rather than larger covers — four to six, by
  /// how many ~140pt tiles its width holds.
  static int _gridColumns(BuildContext context) {
    if (!isTabletLayout(context)) return 3;
    final width = MediaQuery.sizeOf(context).width - 2 * gutter;
    return ((width + _GridRow.columnGap) / (140 + _GridRow.columnGap))
        .floor()
        .clamp(4, 6);
  }

  List<_Item> _items(
    BuildContext context,
    WidgetRef ref,
    KavitaClient client,
    AppLocalizations l10n,
    LibraryType type,
    List<Volume> volumes,
    SavedChapter Function(Volume volume, Chapter chapter) request,
  ) {
    final view = ref.watch(seriesListViewProvider);
    final resume = resumePoint(volumes);
    final volumeOf = {
      for (final volume in volumes)
        for (final chapter in volume.chapters) chapter.id: volume,
    };

    _Item header(String text) => _Heading(
      Padding(
        padding: const EdgeInsets.fromLTRB(gutter, sectionGap, gutter, 8),
        child: SectionLabel(text),
      ),
    );

    _Item chapterItem(
      Chapter chapter, {
      String? label,
      String? coverUrl,
      bool highlighted = false,
    }) => _EntryItem((
      chapter: chapter,
      label: label ?? type.chapterTitle(l10n, chapter),
      coverUrl: coverUrl ?? client.chapterCoverUrl(chapter.id),
      highlighted: highlighted,
      request: request(volumeOf[chapter.id]!, chapter),
    ));

    /// The item one entry stands for, with the two choices the placeholder
    /// volume forces made in one place: a volume with no chapter breakdown
    /// is the reading unit, so it is one entry named after the volume and
    /// drawn by the volume's own cover.
    _Item entryItem(ResumeEntry entry, {bool highlighted = false}) =>
        entry.isWholeVolume
        ? chapterItem(
            entry.chapter,
            label: type.volumeLabel(l10n, entry.volume.name),
            coverUrl: client.volumeCoverUrl(entry.volume.id),
            highlighted: highlighted,
          )
        : chapterItem(entry.chapter, highlighted: highlighted);

    /// A header inside a section — a volume's name over its chapters, or
    /// "Specials" where they follow the storyline inside a group.
    _Item subHeader(String text) => _Heading(
      Padding(
        padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 4),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PatraText.rowTitle(color: patraTextMuted),
        ),
      ),
    );

    /// Entries in the order given, with a sub-header wherever they change
    /// container: a volume with a chapter breakdown names itself over its
    /// chapters, the specials say what they are. Loose chapters and whole
    /// volumes need none — their own label already says everything.
    List<_Item> withSubHeaders(
      List<ResumeEntry> entries, {
      bool highlighted = false,
    }) {
      final items = <_Item>[];
      Object? container;
      for (final entry in entries) {
        final (key, sub) = switch (entry) {
          (:final chapter, volume: _) when chapter.isSpecial => (
            #specials,
            subHeader(type.specialsTitle(l10n)),
          ),
          _ when entry.isWholeVolume => (#volumes, null),
          (:final volume, chapter: _) when volume.isNumbered => (
            volume.id,
            subHeader(type.volumeLabel(l10n, volume.name)),
          ),
          _ => (#loose, null),
        };
        if (key != container && sub != null) items.add(sub);
        container = key;
        items.add(entryItem(entry, highlighted: highlighted));
      }
      return items;
    }

    /// The reading-position view: where you are, what comes next, and what
    /// is done — folded, because a long series' finished chapters are the
    /// bulk of it and never the reason the screen was opened.
    List<_Item> grouped() {
      final entries = orderedChapters(volumes);
      final now = entryUnderWay(resume);
      final next = [
        for (final e in entries)
          if (!e.chapter.isRead && e != now) e,
      ];
      // Most recently finished first, so the row just closed is the first
      // one under the fold.
      final done = [
        for (final e in entries.reversed)
          if (e.chapter.isRead) e,
      ];
      // A finished series has nothing above the fold: that group *is* the
      // list, so it stays open and its header is a plain divider rather than
      // a control that could only fold the whole screen away.
      final wholeList = now == null && next.isEmpty;
      final open = view.showRead || wholeList;
      return [
        if (now != null) ...[
          _Heading(_GroupHeader(l10n.groupReadingNow, color: patraAccent)),
          ...withSubHeaders([now], highlighted: true),
        ],
        if (next.isNotEmpty) ...[
          _Heading(
            _GroupHeader(
              (resume?.started ?? false)
                  ? l10n.groupUpNext
                  : l10n.groupStartHere,
            ),
          ),
          ...withSubHeaders(next),
        ],
        if (done.isNotEmpty) ...[
          _Heading(
            _GroupHeader(
              l10n.groupAlreadyRead(done.length),
              open: wholeList ? null : open,
              onToggle: wholeList
                  ? null
                  : ref.read(seriesListViewProvider.notifier).toggleRead,
            ),
          ),
          if (open) ...withSubHeaders(done),
        ],
      ];
    }

    /// The sections Kavita cuts a series into, in reading order or its
    /// reverse: both are one list read from either end.
    List<_Item> sectioned() {
      final buckets = _split(volumes);
      List<T> ordered<T>(List<T> ascending) => view.sort == ChapterSort.newest
          ? ascending.reversed.toList()
          : ascending;

      // Volumes and volumeless chapters are one story told in order — Kavita
      // calls that the storyline, and hides it where it would lie: an issue
      // run is not a storyline, and a book library has no chapter level. It
      // only says anything when the series actually has both, so a run of
      // volumes stays "Volumes".
      final merged =
          type.hasStoryline &&
          buckets.numberedVolumes.isNotEmpty &&
          buckets.loose.isNotEmpty;

      return [
        if (buckets.numberedVolumes.isNotEmpty) ...[
          header(merged ? type.storylineTitle(l10n) : type.volumesTitle(l10n)),
          for (final volume in ordered(buckets.numberedVolumes))
            if (_volumeChapters(volume).length == 1 &&
                _volumeChapters(volume).single.isVolumePlaceholder)
              // No chapter breakdown: the volume itself is the reading unit.
              chapterItem(
                _volumeChapters(volume).single,
                label: type.volumeLabel(l10n, volume.name),
                coverUrl: client.volumeCoverUrl(volume.id),
              )
            else ...[
              subHeader(type.volumeLabel(l10n, volume.name)),
              for (final chapter in ordered(_volumeChapters(volume)))
                chapterItem(chapter),
            ],
        ],
        if (buckets.loose.isNotEmpty) ...[
          // Inside the storyline the loose chapters simply follow the
          // volumes, exactly as Kavita orders them; they only get a header of
          // their own when they are a list apart.
          if (!merged) header(type.chaptersTitle(l10n)),
          for (final chapter in ordered(buckets.loose)) chapterItem(chapter),
        ],
        if (buckets.specials.isNotEmpty) ...[
          header(type.specialsTitle(l10n)),
          for (final chapter in ordered(buckets.specials)) chapterItem(chapter),
        ],
      ];
    }

    return switch (view.sort) {
      ChapterSort.readingPosition => grouped(),
      ChapterSort.newest || ChapterSort.oldest => sectioned(),
    };
  }
}

/// The name of an order and the rule behind it, in one place: the trigger
/// says the first in a tooltip, the sheet draws both.
(String, String) _sortWords(AppLocalizations l10n, ChapterSort sort) =>
    switch (sort) {
      ChapterSort.readingPosition => (
        l10n.sortReadingPosition,
        l10n.sortReadingPositionHint,
      ),
      ChapterSort.newest => (l10n.sortNewest, l10n.sortNewestHint),
      ChapterSort.oldest => (l10n.sortOldest, l10n.sortOldestHint),
    };

/// The three orders, behind one control: a round button on the trailing edge
/// of the row under the hero that opens a sheet.
///
/// They used to be three pills side by side, and the phrases are what broke
/// that: an order is only useful if its name says what it does, and three
/// such names in French under a large system font take more than a row of a
/// phone — the pills wrapped to two lines and pushed the list down before a
/// single chapter was drawn. With the names in a sheet no translation can
/// break the row, and each order gets the sentence explaining it rather than
/// a tooltip nobody on a phone can reach.
///
/// Icon-only, deliberately: the list underneath is what says which order is
/// in force, and a trigger carrying the name would be the same phrase back
/// in the row we just took it out of. The name is still spoken — it is the
/// tooltip and the semantics label both.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onPick});

  final ChapterSort sort;
  final void Function(ChapterSort sort) onPick;

  /// What the trigger draws: a 36pt disc, the height of the view switch
  /// beside it.
  static const size = 36.0;

  /// The empty band above and below it inside its 44pt box — what the layout
  /// around it has to count as already spent.
  static const boxInset = (minHitTarget - size) / 2;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.sortTooltip(_sortWords(l10n, sort).$1);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: () => _pickSort(context, sort, onPick),
          customBorder: const CircleBorder(),
          // The box is the 44 the app asks of every control, with the disc in
          // the middle of it.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minHitTarget),
            child: Center(
              widthFactor: 1,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: patraBorder),
                ),
                child: const Icon(
                  Icons.swap_vert,
                  size: 18,
                  color: patraTextMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rows or a grid of covers: two icons in one pill, the one in force filled.
///
/// Beside the sort control rather than behind it, because it is not an order
/// — the same list, in the same order, drawn two ways — and a choice between
/// two is one tap, where a sheet would make it three.
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.view, required this.onPick});

  final SeriesView view;
  final void Function(SeriesView view) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget segment(SeriesView option, IconData icon, String name) {
      final selected = option == view;
      return Tooltip(
        message: name,
        child: Semantics(
          button: true,
          selected: selected,
          label: name,
          child: InkWell(
            onTap: selected ? null : () => onPick(option),
            customBorder: const StadiumBorder(),
            child: Container(
              width: 36,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? patraAccent.withValues(alpha: .16) : null,
                borderRadius: BorderRadius.circular(radiusPill),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? patraAccent : patraTextMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: _SortButton.size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radiusPill),
        border: Border.all(color: patraBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment(SeriesView.list, Icons.view_list, l10n.seriesViewList),
          segment(SeriesView.grid, Icons.grid_view, l10n.seriesViewGrid),
        ],
      ),
    );
  }
}

/// The one line that teaches the two gestures, over the rows until either
/// has been used once on this device ([selectionHintVisibleProvider]).
///
/// It is needed because nothing at rest says a row can be saved any more:
/// the pill that did is gone, and a gesture nobody has been told about is a
/// feature nobody has.
class _SelectionHint extends StatelessWidget {
  const _SelectionHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 10),
      child: Row(
        children: [
          const Icon(Icons.swipe_left, size: 16, color: patraTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context).selectionHint,
              style: PatraText.metadata(size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app bar while the screen is selecting: how many, a way out, and the
/// one selection a reader most often wants made for them — **All unread**,
/// which *replaces* the selection rather than adding to it, since it says
/// what the selection is.
///
/// There was a "Next N" beside it, N being a batch size chosen in Settings.
/// It outlived the batch card it came from by one release: with a selection
/// any run can be picked by hand, and a number chosen once in Settings for
/// every series was a setting nobody could see the reason for.
class _SelectionAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _SelectionAppBar({required this.volumes});

  /// Null while they are still on their way, which leaves the shortcut off.
  final List<Volume>? volumes;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selection = ref.read(seriesSelectionProvider.notifier);
    final count = ref.watch(
      seriesSelectionProvider.select((selected) => selected?.length ?? 0),
    );
    final unread = [
      if (volumes case final volumes?)
        for (final e in orderedChapters(volumes))
          if (!e.chapter.isRead) e.chapter.id,
    ];

    return AppBar(
      backgroundColor: patraSurfaceHi,
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.cancel,
        onPressed: selection.clear,
      ),
      titleSpacing: 0,
      title: Text(
        l10n.selectionCount(count),
        style: PatraText.rowTitle().copyWith(fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        TextButton(
          onPressed: unread.isEmpty ? null : () => selection.replace(unread),
          style: TextButton.styleFrom(
            foregroundColor: patraOffline,
            minimumSize: const Size(0, minHitTarget),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: PatraText.rowTitle(size: 14),
          ),
          child: Text(l10n.selectAllUnread, maxLines: 1),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// The bar under the list while the screen is selecting: how many are
/// selected, what that comes to, and the one thing to do with them.
///
/// **One** button, never two: Save where something selected is left to fetch
/// and the server can be reached, Remove only where everything selected is
/// already on the device. A selection mixing the two is a selection to save —
/// what is here already costs nothing — and removal is offered only where it
/// is all there is to do, so a long-press meant for saving can never end in
/// a tap that deletes.
///
/// Its line says a **count** to download, never a size: a chapter's bytes
/// are not known before it is fetched, and a size promised here would be a
/// guess (#101).
class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({required this.volumes, required this.request});

  final List<Volume> volumes;
  final SavedChapter Function(Volume volume, Chapter chapter) request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(seriesSelectionProvider) ?? const <int>{};
    final summary = summarizeSelection(
      selected,
      ref.watch(downloadMembershipProvider),
    );
    final offline = ref.watch(offlineProvider);
    final canSave = summary.toFetch.isNotEmpty && !offline;

    final line = summary.count == 0
        ? l10n.selectionEmpty
        : summary.allSaved
        ? l10n.selectionAllSaved
        : summary.toFetch.isEmpty
        ? l10n.selectionOnItsWay
        : offline
        ? l10n.selectionOffline
        : l10n.selectionToFetch(summary.toFetch.length);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusCover),
    );
    const size = Size(0, minHitTarget);
    final textStyle = PatraText.rowTitle(size: 14);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: patraSurface,
        border: Border(top: BorderSide(color: patraBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 14, gutter, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.selectionCount(summary.count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PatraText.rowTitle(),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      line,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PatraText.metadata(),
                    ),
                  ],
                ),
              ),
              if (canSave) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _save(context, ref, summary.toFetch),
                  style: FilledButton.styleFrom(
                    backgroundColor: patraOffline,
                    foregroundColor: patraBg,
                    minimumSize: size,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: shape,
                    textStyle: textStyle,
                  ),
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: Text(l10n.savePill),
                ),
              ] else if (summary.allSaved) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _remove(context, ref, selected),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: patraDanger,
                    side: BorderSide(color: patraDanger.withValues(alpha: .4)),
                    minimumSize: size,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: shape,
                    textStyle: textStyle,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.removeDownload),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Queues what is left to fetch as one batch, in reading order, and leaves
  /// selection: the badges on the covers take the report over from here.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Set<int> toFetch,
  ) async {
    final selection = ref.read(seriesSelectionProvider.notifier);
    final downloads = ref.read(downloadsProvider.notifier);
    if (!await mayDownload(context, ref)) return;
    final requests = [
      for (final e in orderedChapters(volumes))
        if (toFetch.contains(e.chapter.id)) request(e.volume, e.chapter),
    ];
    selection.clear();
    await downloads.saveBatch(requests);
  }

  /// Takes the selected copies off the device, after saying how many: they
  /// are the reader's library, and what is about to go is said before it
  /// goes, as the row's own swipe does for one.
  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Set<int> selected,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selection = ref.read(seriesSelectionProvider.notifier);
    final downloads = ref.read(downloadsProvider.notifier);
    final confirmed = await _confirm(
      context,
      l10n.removeSelectedConfirm(selected.length),
      l10n.removeDownload,
    );
    if (!confirmed) return;
    selection.clear();
    for (final id in selected) {
      await downloads.remove(id);
    }
  }
}

/// Asks before something is taken off the device, with the destructive word
/// in danger.
Future<bool> _confirm(
  BuildContext context,
  String question,
  String action,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: patraSurface,
      title: Text(question, style: PatraText.body()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(action, style: PatraText.body(color: patraDanger)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The sheet the trigger opens: the three orders, each with the rule it
/// follows, the one in force ticked and drawn in the accent — the app's own
/// picker, the same one Settings offers a language and a cache budget in.
Future<void> _pickSort(
  BuildContext context,
  ChapterSort current,
  void Function(ChapterSort sort) onPick,
) async {
  final l10n = AppLocalizations.of(context);
  final picked = await showModalBottomSheet<ChapterSort>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 6),
            child: SectionLabel(l10n.sortSheetTitle),
          ),
          for (final option in ChapterSort.values)
            Builder(
              builder: (context) {
                final (name, hint) = _sortWords(l10n, option);
                final selected = option == current;
                return ListTile(
                  title: Text(
                    name,
                    style: PatraText.rowTitle(
                      color: selected ? patraAccent : patraText,
                    ),
                  ),
                  subtitle: Text(hint, style: PatraText.metadata()),
                  trailing: selected
                      ? const Icon(Icons.check, color: patraAccent, size: 18)
                      : null,
                  selected: selected,
                  onTap: () => Navigator.of(sheetContext).pop(option),
                );
              },
            ),
        ],
      ),
    ),
  );
  if (picked != null) onPick(picked);
}

/// The header of a group in the reading-position view: a tracked label, the
/// fold control where the group has one, and a hairline running to the edge.
///
/// Not a [SectionLabel], though it wears the same style: that widget gives
/// the label the whole row and hangs its trailing at the far edge, where this
/// header wants the control beside the words and the hairline taking what is
/// left. The *style* stays the one definition, `PatraText.sectionLabel`.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.text, {this.color, this.open, this.onToggle});

  final String text;

  /// Muted unless the group is about reading progress — "Reading now" is in
  /// the accent, like the Continue hero's eyebrow.
  final Color? color;

  /// Whether the group's rows are shown; null where the group cannot fold.
  final bool? open;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final header = Row(
      children: [
        // Flexible, or "DÉJÀ LUS · 12" and its control run a 320pt phone
        // over the edge: the label is what gives, never the control.
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PatraText.sectionLabel(color: color),
          ),
        ),
        if (open case final open?) ...[
          const SizedBox(width: 10),
          // Worded, never the chevron alone: a glyph says nothing to a screen
          // reader, and "Show" is what the tap does.
          Text(
            open ? l10n.hideReadChapters : l10n.showReadChapters,
            style: PatraText.rowTitle(color: patraAccent, size: 11),
          ),
          Icon(
            open ? Icons.expand_less : Icons.expand_more,
            size: 14,
            color: patraAccent,
          ),
        ],
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: .07),
          ),
        ),
      ],
    );
    if (onToggle == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(gutter, sectionGap, gutter, 8),
        child: header,
      );
    }
    // The same place on the page as the plain header: the tap target's own
    // padding is taken off the top here and given back inside it.
    const inset = 8.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, sectionGap - inset, gutter, 0),
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHitTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: inset),
            child: header,
          ),
        ),
      ),
    );
  }
}

/// What a row's trailing swipe does, which is whatever there is to do with
/// the copy in the state it is in — one action, never a menu.
enum _CopyAction {
  save(Icons.save_alt),
  pause(Icons.pause),
  resume(Icons.play_arrow),
  retry(Icons.refresh),
  remove(Icons.delete_outline);

  const _CopyAction(this.icon);
  final IconData icon;

  static _CopyAction of(DownloadQueueRecord? record) => switch (record) {
    null => save,
    DownloadQueueRecord(saved: _?) => remove,
    DownloadQueueRecord(isInFlight: true) => pause,
    DownloadQueueRecord(
      status: DownloadQueueStatus.paused || DownloadQueueStatus.pausedByUser,
    ) =>
      resume,
    _ => retry,
  };

  /// Pausing and removing are the device's own business; the rest asks the
  /// server for pages, and offline a swipe offering them would be the screen
  /// offering what it cannot do.
  bool get needsServer => this != pause && this != remove;

  String label(AppLocalizations l10n) => switch (this) {
    save => l10n.savePill,
    pause => l10n.pauseAction,
    resume => l10n.resumeDownload,
    retry => l10n.retry,
    remove => l10n.removeDownload,
  };
}

/// What selecting asks of one entry: null where the screen is not selecting,
/// else whether this one is in the selection.
bool? _selectedIn(Set<int>? selection, int chapterId) =>
    selection?.contains(chapterId);

/// The server is the authority on progress; mirror it into the stored copy
/// so the Downloads tab knows it too, including for chapters saved before
/// this screen was ever opened. Asked of every entry drawn, in either view.
///
/// It is **inert on an entry drawn from the catalogue**, and that is the same
/// fact stated twice rather than luck: [seriesVolumesProvider] has already
/// laid the saved copy's progress over such an entry, so the two numbers
/// agree and there is nothing to carry. Which is what has to happen — the
/// catalogue holds the server's *last* word, and writing that back over a
/// chapter somebody has since read on a train would undo the reading.
void _mirrorProgress(WidgetRef ref, Chapter chapter, SavedChapter? savedCopy) {
  if (savedCopy == null || savedCopy.pagesRead == chapter.pagesRead) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref
        .read(downloadsProvider.notifier)
        .recordProgress(chapter.id, chapter.pagesRead);
  });
}

/// Opens [chapter] in the reader and refreshes what reading changed.
Future<void> _openChapter(
  BuildContext context,
  WidgetRef ref,
  Chapter chapter,
  int seriesId,
) async {
  // Reading is about to define progress properly; a mark-read held on top of
  // the fetch would overwrite whatever comes back.
  ref.read(readOverridesProvider.notifier).clear(chapter.id);
  final started = chapter.pagesRead > 0 && chapter.pagesRead < chapter.pages;
  await context.push(readerLocation(chapter, started: started));
  // Progress changed while reading: the rows and the hero both show it.
  ref.invalidate(catalogue.volumes(seriesId).invalidatable);
  ref.invalidate(catalogue.series(seriesId).invalidatable);
}

/// A long-press enters selection with the entry pressed, or adds it where
/// selection is already open; either way the one-time line has done its job.
void _longPress(WidgetRef ref, int chapterId) {
  unawaited(HapticFeedback.selectionClick());
  ref.read(seriesSelectionProvider.notifier).start(chapterId);
  unawaited(ref.read(selectionHintVisibleProvider.notifier).dismiss());
}

/// A long-press held for 450ms, the prototype's timing — a shade quicker
/// than the platform's, because it is the only way into selecting and is
/// made many times in a row. Wrapped round the entry's own [InkWell], which
/// keeps the tap; a drag beyond the platform's touch slop is the scroll's or
/// the swipe's, and cancels it. (The prototype's 6px cannot be asked of
/// Flutter's recognizer, and the gesture arena settles the same conflict.)
class _LongPress extends StatelessWidget {
  const _LongPress({required this.onLongPress, required this.child});

  final VoidCallback onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    gestures: {
      LongPressGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(
              duration: const Duration(milliseconds: 450),
            ),
            (recognizer) => recognizer.onLongPress = onLongPress,
          ),
    },
    child: child,
  );
}

class _ChapterRow extends ConsumerWidget {
  const _ChapterRow({
    super.key,
    required this.entry,
    required this.seriesId,
    required this.seriesName,
  });

  final _Entry entry;
  final int seriesId;
  final String seriesName;

  Chapter get chapter => entry.chapter;

  /// The swipe panes are sized in points, not in a share of the row.
  ///
  /// A ratio that gives a phone a sensible drawer slides a tablet's row a
  /// third of 820pt off screen, taking the cover and the title with it — so
  /// the swipe hides the very thing it is about to act on. These are the
  /// widths the panes come to on a phone; `_paneRatio` turns them back into a
  /// ratio against whatever width the row actually got.
  static const _markPaneWidth = 116.0;
  static const _copyPaneWidth = 88.0;

  /// Never wider than a third of the row (a narrow phone), never so narrow
  /// that the action's own label has nowhere to sit.
  static double _paneRatio(double target, double available) =>
      available <= 0 ? .3 : (target / available).clamp(.15, .34);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tablet = isTabletLayout(context);
    final coverWidth = tablet ? rowCoverWidthTablet : rowCoverWidth;
    final coverHeight = tablet ? rowCoverHeightTablet : rowCoverHeight;
    final read = chapter.isRead;
    final inProgress = chapter.pagesRead > 0 && !read;
    final progress = inProgress && chapter.pages > 0
        ? chapter.pagesRead / chapter.pages
        : 0.0;

    final selectedState = ref.watch(
      seriesSelectionProvider.select((s) => _selectedIn(s, chapter.id)),
    );
    final selecting = selectedState != null;
    final selected = selectedState ?? false;

    final savedCopy = ref.watch(savedChapterProvider(chapter.id));
    final saved = savedCopy != null;
    // What the trailing swipe offers, as one value: a page landing on this
    // chapter moves its badge, not the whole row.
    final copyAction = ref.watch(
      downloadRecordProvider(chapter.id).select(_CopyAction.of),
    );
    final offline = ref.watch(offlineProvider);
    _mirrorProgress(ref, chapter, savedCopy);
    // Offline, a chapter that is not stored locally cannot be opened: a book
    // is read from the server's own pages, so there is nothing to open
    // without one. Saving one is the same fetch as any other chapter's — a
    // copy is made of the pages the server rendered (ADR-0009), whichever
    // of the two kinds of page those are.
    final openable = saved || !offline;

    final cover = SizedBox(
      width: coverWidth,
      height: coverHeight,
      child: Stack(
        fit: StackFit.expand,
        // The badge hangs off the corner, half over the page behind.
        clipBehavior: Clip.none,
        children: [
          CoverImage(
            url: entry.coverUrl,
            headers: ref.watch(kavitaClientProvider).imageHeaders,
            seriesId: seriesId,
            seriesName: seriesName,
            radius: radiusThumb,
            // Derived from the width actually drawn, never a constant: 138
            // was the phone's number (46pt at 3x) and left a tablet decoding
            // an 80pt cover at half its size — the blur the bigger cover was
            // meant to remove. Kavita's cover endpoint serves a fixed size,
            // so asking past it costs nothing.
            memCacheWidth: (coverWidth * MediaQuery.devicePixelRatioOf(context))
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
          if (selected) const _SelectedOutline(),
          Positioned(
            right: -6,
            bottom: -6,
            child: DownloadBadge(
              chapterId: chapter.id,
              placement: DownloadBadgePlacement.rowCorner,
            ),
          ),
        ],
      ),
    );

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
          if (selecting) ...[
            SelectionMark(selected: selected),
            const SizedBox(width: 12),
          ],
          cover,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A read row is not muted: read is a positive signal, said
                // by the rail and by the accent on the line below. The row
                // under way wears the accent in its title, as the group
                // header over it does.
                Text(
                  entry.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PatraText.rowTitle(
                    size: tablet ? 15 : 13.5,
                    color: entry.highlighted ? patraAccent : null,
                  ),
                ),
                const SizedBox(height: 3),
                // Where the row is read the word is in the line rather than
                // beside the title as a tag — the state is spoken because it
                // is written. A row under way says where it is instead.
                if (inProgress)
                  Text(
                    l10n.pageProgress(chapter.pagesRead, chapter.pages),
                    style: PatraText.metadata(size: tablet ? 12 : 11),
                  )
                else
                  PageCountLine(
                    pages: chapter.pages,
                    read: read,
                    size: tablet ? 12 : 11,
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
                        valueColor: const AlwaysStoppedAnimation(patraAccent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final tile = Opacity(
      opacity: !openable
          ? 0.4
          : selecting && !selected
          ? 0.6
          : 1,
      child: Builder(
        // Builder so the tap can ask the Slidable above it whether it is open.
        builder: (rowContext) => _LongPress(
          onLongPress: () => _longPress(ref, chapter.id),
          child: InkWell(
            onTap: selecting
                ? () => ref
                      .read(seriesSelectionProvider.notifier)
                      .toggle(chapter.id)
                : openable
                ? () => _tap(rowContext, ref)
                : null,
            // Edge to edge, gutters included: a tint that stopped at the
            // cover would read as the cover's, not the row's.
            child: ColoredBox(
              color: selected
                  ? patraOffline.withValues(alpha: .08)
                  : entry.highlighted
                  ? patraAccent.withValues(alpha: .06)
                  : Colors.transparent,
              child: ReadRail(
                read: read,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: gutter),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: minHitTarget),
                    child: row,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Selecting, a tap is a toggle and nothing slides: a swipe there would
    // act on one row while the bar below speaks for several.
    if (selecting) return tile;
    // Marking read is a server operation; offline there is nothing to swipe
    // for. A format we cannot open is still markable — it was read somewhere
    // else, which is exactly when saying so by hand is worth something.
    final markable = !offline;
    final copyable = openable && !(copyAction.needsServer && offline);
    if (!copyable && !markable) return tile;
    return LayoutBuilder(
      // The panes are asked for as a ratio, so the row has to be measured
      // before they can be given a width that means the same thing on every
      // screen.
      builder: (context, constraints) => Slidable(
        key: ValueKey(chapter.id),
        groupTag: 'chapters',
        // Progress on the leading edge, the copy on the trailing one: a swipe
        // that reaches for one can never land on the other.
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
        endActionPane: copyable
            ? ActionPane(
                motion: const DrawerMotion(),
                extentRatio: _paneRatio(_copyPaneWidth, constraints.maxWidth),
                children: [
                  SlidableAction(
                    onPressed: (actionContext) =>
                        _act(actionContext, ref, copyAction),
                    // Every download wears the offline blue; taking a copy
                    // away is the one action in danger.
                    backgroundColor: copyAction == _CopyAction.remove
                        ? patraSurfaceHi
                        : patraOffline,
                    foregroundColor: copyAction == _CopyAction.remove
                        ? patraDanger
                        : patraBg,
                    icon: copyAction.icon,
                    label: copyAction.label(l10n),
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

  /// The trailing swipe's one action, on the copy in the state it is in.
  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    _CopyAction action,
  ) async {
    final downloads = ref.read(downloadsProvider.notifier);
    unawaited(ref.read(selectionHintVisibleProvider.notifier).dismiss());
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case _CopyAction.save:
        if (!await mayDownload(context, ref)) return;
        await downloads.save(entry.request);
      case _CopyAction.pause:
        await downloads.pause(chapter.id);
      case _CopyAction.resume || _CopyAction.retry:
        if (!await mayDownload(context, ref)) return;
        await downloads.retry(chapter.id);
      case _CopyAction.remove:
        // A copy that is **here** is the reader's library, and what is
        // about to go is said before it goes.
        final title = [
          seriesName,
          entry.label,
        ].where((p) => p.isNotEmpty).join(' — ');
        if (!await _confirm(
          context,
          l10n.removeDownloadConfirm(title),
          l10n.removeDownload,
        )) {
          return;
        }
        await downloads.remove(chapter.id);
    }
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
    if (ref.context.mounted) {
      ref.invalidate(catalogue.series(seriesId).invalidatable);
    }
  }

  /// An open row closes on tap; only a closed one opens the reader.
  void _tap(BuildContext context, WidgetRef ref) {
    final slidable = Slidable.of(context);
    if (slidable != null && slidable.animation.value > 0) {
      slidable.close();
      return;
    }
    _openChapter(context, ref, chapter, seriesId);
  }
}

/// A selected cover's ring: the offline blue, two points out from the cover,
/// so the picture itself is not covered by what says it was picked.
class _SelectedOutline extends StatelessWidget {
  const _SelectedOutline();

  @override
  Widget build(BuildContext context) => Positioned(
    left: -4,
    top: -4,
    right: -4,
    bottom: -4,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radiusThumb + 4),
          border: Border.all(color: patraOffline, width: 2),
        ),
      ),
    ),
  );
}

/// One run of tiles across the grid, the last one padded out with empty
/// columns so every cover in the grid is the same size.
class _GridRow extends StatelessWidget {
  const _GridRow({
    required this.columns,
    required this.first,
    required this.children,
  });

  final int columns;

  /// The first row under a heading sits a little closer to it.
  final bool first;
  final List<Widget> children;

  static const columnGap = 12.0;
  static const rowGap = 18.0;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(gutter, first ? 4 : 0, gutter, rowGap),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns; i++) ...[
          if (i > 0) const SizedBox(width: columnGap),
          Expanded(child: i < children.length ? children[i] : const SizedBox()),
        ],
      ],
    ),
  );
}

/// One entry as a cover in the grid: the 2:3 cover with its reading bar,
/// the badge of its copy in the top corner, and its name under it.
///
/// No swipe — a tile in a grid has no edge to pull — so saving one is a
/// long-press and the bar, which is the one way the grid saves anything.
class _VolumeTile extends ConsumerWidget {
  const _VolumeTile({
    super.key,
    required this.entry,
    required this.seriesId,
    required this.seriesName,
  });

  final _Entry entry;
  final int seriesId;
  final String seriesName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chapter = entry.chapter;
    final read = chapter.isRead;
    final inProgress = chapter.pagesRead > 0 && !read;
    final selectedState = ref.watch(
      seriesSelectionProvider.select((s) => _selectedIn(s, chapter.id)),
    );
    final selecting = selectedState != null;
    final selected = selectedState ?? false;
    final savedCopy = ref.watch(savedChapterProvider(chapter.id));
    final offline = ref.watch(offlineProvider);
    _mirrorProgress(ref, chapter, savedCopy);
    final openable = savedCopy != null || !offline;

    return Opacity(
      opacity: !openable
          ? 0.4
          : selecting && !selected
          ? 0.6
          : 1,
      child: _LongPress(
        onLongPress: () => _longPress(ref, chapter.id),
        child: InkWell(
          onTap: selecting
              ? () => ref
                    .read(seriesSelectionProvider.notifier)
                    .toggle(chapter.id)
              : openable
              ? () => _openChapter(context, ref, chapter, seriesId)
              : null,
          borderRadius: BorderRadius.circular(radiusThumb),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: coverAspectRatio,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      CoverImage(
                        url: entry.coverUrl,
                        headers: ref.watch(kavitaClientProvider).imageHeaders,
                        seriesId: seriesId,
                        seriesName: seriesName,
                        radius: radiusThumb,
                        // A bar on a cover is reading progress, and a read
                        // one is a full bar rather than none.
                        progress: read
                            ? 1
                            : chapter.pages > 0
                            ? chapter.pagesRead / chapter.pages
                            : 0,
                        memCacheWidth:
                            (constraints.maxWidth *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round(),
                      ),
                      if (selected) const _SelectedOutline(),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: DownloadBadge(
                          chapterId: chapter.id,
                          placement: DownloadBadgePlacement.tileCorner,
                        ),
                      ),
                      if (selecting)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: SelectionMark(selected: selected, onArt: true),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                entry.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PatraText.rowTitle(
                  size: 12.5,
                  color: entry.highlighted ? patraAccent : null,
                ),
              ),
              const SizedBox(height: 2),
              if (inProgress)
                Text(
                  l10n.pageProgress(chapter.pagesRead, chapter.pages),
                  style: PatraText.metadata(),
                )
              else
                PageCountLine(pages: chapter.pages, read: read, size: 11),
            ],
          ),
        ),
      ),
    );
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
