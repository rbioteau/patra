import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../api/models.dart';
import '../auth/session.dart';
import '../catalogue/catalogue_reads.dart' as catalogue;
import '../downloads/downloads_provider.dart';
import '../resume_point.dart';
import '../theme.dart';
import 'cover.dart';
import 'page_backdrop.dart';

/// The hero that opens a series: the cover of the chapter it resumes, who
/// made it, how much of it there is, and one button that takes the reader
/// back to where they left off.
///
/// **One widget, two screens.** The series screen stands it at the top of the
/// list below; the home screen promotes one series with it. There were two of
/// these until they were made one, and they had drifted apart in everything
/// that is not the series itself — a 124x182 cover here against a cover
/// stretched to the height of the words there, 16pt between the cover and the
/// words against 12, a button that named the chapter it resumes against one
/// that only ever said "Continue", a progress bar and a page count under one
/// and a tally of volumes under the other. None of those differences was
/// argued for the second time; they were two screens that happened to be
/// written twice.
///
/// So the two now draw one widget, and the same series reads the same on
/// either screen. What a screen still supplies is only what is its own:
/// [onRead] is where the reader goes — each screen refreshes what reading may
/// have changed — and [onOpenSeries] is the way to the series, which the home
/// screen needs because its card is the only door to the series it promotes
/// (having taken that series out of the shelf below it), and the series
/// screen does not, standing on it already.
///
/// The cover in front and the page behind are `resume_point.dart`'s two
/// rules, asked once here rather than once per screen.
class SeriesHero extends ConsumerWidget {
  const SeriesHero({
    super.key,
    required this.seriesId,
    required this.seriesName,
    required this.volumes,
    required this.onRead,
    this.onOpenSeries,
  });

  final int seriesId;
  final String seriesName;

  /// The chapter list as the screen has it — the whole [AsyncValue] and not
  /// only its value, because the hero has to tell a list still on its way
  /// from one that is never coming: the button waits for the first, and the
  /// tally's skeleton must stop shimmering for the second.
  ///
  /// It is handed in rather than watched here because the two screens ask for
  /// it differently on purpose: the series screen watches the provider that
  /// lays its own optimistic mark-read over the fetch, and the home screen
  /// deliberately watches the layer under that one, whose map is autoDispose
  /// and would otherwise outlive the screen it belongs to.
  final AsyncValue<List<Volume>> volumes;

  /// Takes a chapter to the reader, at the page this hero decided. [started]
  /// says whether that chapter is under way, which is the whole of what the
  /// button knows about where it opens.
  final void Function(Chapter chapter, {required bool started}) onRead;

  /// Where tapping the cover or the title goes, on a screen that is not
  /// already that series' own.
  final VoidCallback? onOpenSeries;

  static const _coverWidth = 124.0;
  static const _coverHeight = 182.0;

  /// The same hero, given a tablet's room: the cover keeps its proportions.
  static const _tabletCoverWidth = 160.0;
  static const _tabletCoverHeight = 235.0;

  /// The chapter the button opens, decided by the one shared rule the home
  /// screen's Continue card uses too — see `resume_point.dart`.
  ResumePoint? _target() {
    final list = volumes.value;
    return list == null ? null : resumePoint(list);
  }

  /// Whether the reader opens where it was left off rather than at the first
  /// page.
  ///
  /// A chapter nobody has opened starts at its beginning, and so does one
  /// already finished: `pagesRead` is where the *server* stopped counting,
  /// and on a chapter that is read through that is its last page — which is
  /// not reading resuming. It used to be two rules, one per screen, and they
  /// agreed only by accident of which chapters reached them.
  static bool _underWay(Chapter chapter) =>
      chapter.pagesRead > 0 && chapter.pagesRead < chapter.pages;

  /// What the button says.
  ///
  /// **It names nothing, and that is the decision.** It used to name what it
  /// opens — `Continue — Ch. 3`, `— tome 1`, `— #12`, `— livre 2` — in the
  /// library's own vocabulary, which is Kavita's own way of wording it. What
  /// that bought was a number a reader could already see on the row the
  /// button opens, in a button that then had to be read rather than pressed;
  /// what it cost was a word in every language, a rule per library type, and
  /// a title that could never be named there anyway (free text stretches a
  /// button across the hero). So the button says what it does and nothing
  /// else, and the chapter it opens is named by the row underneath.
  static String _label(
    ResumePoint? target,
    bool known,
    AppLocalizations l10n,
  ) => switch (target) {
    // Nothing is known yet: the hero is drawn as soon as its series is,
    // and fills the chapter in behind, so "Start reading" would be a
    // verdict on a question still being asked. The plain word is the one
    // that does not have to be taken back.
    null when !known => l10n.seriesContinuePlain,
    // Nothing to open: a series with no chapters at all, or one whose
    // volumes could not be read.
    null => l10n.seriesStartReading,
    // The button asks whether the *series* is under way, not the chapter
    // it lands on: finishing a volume leaves the next one untouched, so
    // progress off the target alone says "Start reading" to somebody
    // halfway through a series.
    (entry: _, started: true, allRead: false) => l10n.seriesContinuePlain,
    (allRead: true, entry: _, started: _) => l10n.seriesReadAgain,
    _ => l10n.seriesStartReading,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tablet = isTabletLayout(context);
    final coverWidth = tablet ? _tabletCoverWidth : _coverWidth;
    final coverHeight = tablet ? _tabletCoverHeight : _coverHeight;
    final client = ref.watch(kavitaClientProvider);
    final series = ref.watch(catalogue.series(seriesId).provider).value;
    final metadataAsync = ref.watch(
      catalogue.seriesMetadata(seriesId).provider,
    );
    final metadata = metadataAsync.value;
    final target = _target();
    // The one thing the button does, or nothing when there is nothing to open.
    final VoidCallback? open = switch (target?.entry) {
      null => null,
      final entry => () => onRead(
        entry.chapter,
        started: _underWay(entry.chapter),
      ),
    };

    // "Author · Genre", dropping whichever half the server does not have.
    final credits = [
      if (metadata != null && metadata.writers.isNotEmpty)
        metadata.writers.take(2).join(', '),
      if (metadata != null && metadata.genres.isNotEmpty) metadata.genres.first,
    ].join(' · ');
    // A volume-organised series is counted in volumes: calling four volumes
    // "4 chapters" reads as wrong to anyone looking at the list below.
    final tally = switch (volumes.value) {
      null => null,
      final list when list.any((v) => v.isNumbered) => l10n.seriesVolumeCount(
        list.where((v) => v.isNumbered).length,
      ),
      final list => l10n.seriesChapterCount(orderedChapters(list).length),
    };
    final stats = [
      ?tally,
      if (series != null && series.libraryName.isNotEmpty) series.libraryName,
    ].join(' · ');

    // Offline the button follows the same rule as the row it opens: a chapter
    // that is not on the device cannot be read, and a hero offering what the
    // dimmed row below it refuses is the screen disagreeing with itself. The
    // *format* is deliberately not asked about here, as it never has been — a
    // book is read through the pages the server makes of it, so there is no
    // format left that a chapter cannot be opened in.
    final openable =
        target != null &&
        (!ref.watch(offlineProvider) ||
            ref.watch(savedChapterProvider(target.entry.chapter.id)) != null);

    final label = _label(target, volumes.hasValue, l10n);

    // A page behind the hero only when a chapter is genuinely under way.
    // Where the button starts the series, or offers it again, there is no
    // page you are on — and the first page of something unread is a spoiler
    // with nothing behind it. The cover in front follows the looser rule: it
    // is the entry the button opens whenever the series is under way, the
    // untouched next volume included.
    final underWay = entryUnderWay(target);
    final onPage = underWay?.chapter;
    final pictured = entryPictured(target);

    // Muted grey is tuned against a flat panel; over a page it is the first
    // thing to go.
    final onArt = onPage == null ? null : patraTextOnArt;

    // A cover's bar always means "how far through the thing pictured" — the
    // rule every chapter row and library tile follows — so it belongs to
    // whichever of the two this cover turned out to be, and must never fall
    // back across that line: a series' progress under a chapter's picture is
    // a number about something else.
    final coverProgress = switch (pictured) {
      final entry? =>
        entry.chapter.pages == 0
            ? 0.0
            : entry.chapter.pagesRead / entry.chapter.pages,
      null =>
        series == null || series.pages == 0
            ? 0.0
            : series.pagesRead / series.pages,
    };

    // The card's own two doors, where the screen has anywhere to go: the
    // cover and the title both open the series.
    Widget reachable(Widget child) => onOpenSeries == null
        ? child
        : GestureDetector(onTap: onOpenSeries, child: child);

    return Stack(
      children: [
        if (onPage != null)
          Positioned.fill(
            child: PageBackdrop(
              seriesId: seriesId,
              // A book has no page picture to draw — see
              // [Chapter.hasPagePictures]. The cover stands in, which is
              // what the backdrop already does for a page that cannot load.
              chapterId: onPage.hasPagePictures ? onPage.id : null,
              page: onPage.pagesRead,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, gutter),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              reachable(
                SizedBox(
                  width: coverWidth,
                  height: coverHeight,
                  child: CoverImage(
                    url: pictured == null
                        ? client.seriesCoverUrl(seriesId)
                        : entryCoverUrl(client, pictured),
                    headers: client.imageHeaders,
                    seriesId: seriesId,
                    seriesName: seriesName,
                    progress: coverProgress,
                  ),
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
                      // The column is pinned to the cover's height, so a
                      // title that needs more room than the button row leaves
                      // it must clip rather than overflow: the hero is not
                      // scrollable, and an overflow paints the title over
                      // the screen below. The title is the only child that
                      // can grow — the lines under it all ellipsize to one.
                      Flexible(
                        child: reachable(
                          Text(
                            seriesName,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: PatraText.serifTitle(size: tablet ? 25 : 21),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (credits.isNotEmpty)
                        Text(
                          credits,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PatraText.metadata(size: 12, color: onArt),
                        )
                      // Only while it may still arrive. A resolved failure
                      // is not a slow answer, and a skeleton keyed on a null
                      // value alone shimmers for one that is never coming.
                      else if (metadata == null &&
                          !metadataAsync.isResolvedFailure)
                        const Skeleton(height: 11, width: 150),
                      const SizedBox(height: 6),
                      if (stats.isNotEmpty)
                        Text(
                          stats,
                          style: PatraText.metadata(size: 12, color: onArt),
                        )
                      // Same rule, and the volumes alone answer it: a list
                      // that arrived always counts to something, so an empty
                      // tally means the fetch is either in flight or refused.
                      else if (!volumes.isResolvedFailure)
                        const Skeleton(height: 11, width: 110),
                      const SizedBox(height: 14),
                      // Held to [controlMaxWidth] and given the height a
                      // control is, because a button handed a hero's whole
                      // width to fill stops reading as a button — the rule
                      // every resume and sign-out button in the app follows.
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: controlMaxWidth,
                        ),
                        child: SizedBox(
                          height: minHitTarget,
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(minHitTarget),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onPressed: openable ? open : null,
                            // Kavita's own continue control wears an open
                            // book, and so does this one: the play triangle
                            // said "play", where this opens a book at the
                            // page it kept.
                            icon: const Icon(Icons.menu_book_rounded, size: 20),
                            label: Text(
                              label,
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
        ),
      ],
    );
  }
}
