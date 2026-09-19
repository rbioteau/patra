import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../entity_naming.dart';
import '../../resume_point.dart';
import '../../theme.dart';
import '../../widgets/cover.dart';
import '../../catalogue/catalogue_reads.dart' as catalogue;
import '../../widgets/no_intrinsic.dart';
import '../../widgets/page_backdrop.dart';
import '../../routes.dart';

/// The one series the home screen promotes above the Continue shelf, or null
/// when there is nothing to promote and the hero should not be drawn at all.
///
/// **The candidates are already the answer to "what is being read".** They
/// come from `/api/Series/on-deck`, which Kavita builds from `PagesRead > 0
/// && PagesRead < Pages` plus a recency clause, so this does not ask it
/// again: re-deriving "started and unfinished" from the payload would be
/// second-guessing the endpoint's own contract with fields it has no
/// obligation to fill in.
///
/// It is deliberately **not** `/api/Series/currently-reading`, whose name is
/// the trap — that one is `ReadLast GreaterThan OnDeckProgressDays`, which
/// the server inverts into "last read more than a month ago". See
/// `catalogue.onDeck`.
///
/// What is left to decide here is only what the endpoint does not know: which
/// of the candidates was read most recently, and that a series is finished.
/// A series carrying no read date stays eligible; it simply cannot outrank one
/// that says when it was read, so with no dates anywhere the shelf's own order
/// stands.
///
/// **What a series is made of is not asked, and never was anything but a
/// gap.** A book is read on the pages the server laid its words out into
/// (ADR-0008), and it is pages that Kavita counts, so a shelf that holds one
/// is holding reading progress like any other. Passing over [[Reflowable
/// content]] here was the reader's own limitation wearing this screen's
/// clothes: the button opens one now, so there is nothing left to exclude.
///
/// The finished guard is a belt-and-braces check for a server that hands back
/// something already read.
///
Series? featuredSeries(List<Series> candidates) {
  Series? best;
  for (final series in candidates) {
    if (series.isRead) continue;
    if (best == null || _readMoreRecently(series, best)) best = series;
  }
  return best;
}

/// Ties and absent dates keep the order they arrived in, so the same shelf
/// always promotes the same series.
bool _readMoreRecently(Series candidate, Series best) {
  final date = candidate.latestReadDate;
  if (date == null) return false;
  final incumbent = best.latestReadDate;
  return incumbent == null || date.isAfter(incumbent);
}

/// What the hero needs to draw itself: the promoted series, and where reading
/// it resumes once that is known. [point] is null only while the chapter is
/// still in flight — the hero shows its cover and title straight away rather
/// than holding the whole card back for it.
typedef ContinueHeroData = ({Series series, ResumePoint? point});

/// The band's own gaps, drawn by both the row and the column of words.
///
/// The chapter rows' 12 between a cover and its words, rather than the
/// prototype's 16: on a band this wide the larger gap read as the details
/// standing off the cover, not beside it. And the 14 between the progress
/// track and the button that follows it on a tablet, wider than the 6 above
/// the track — a control needs more air around it than the line above it does.
const _coverGap = 12.0;
const _buttonGap = 14.0;

/// The Continue shelf's series, given the full treatment.
///
/// A promotion, never an obligation: where the card cannot be complete the
/// hero is simply not drawn, and its series goes back into the shelf below.
class ContinueHero extends ConsumerWidget {
  const ContinueHero({super.key, required this.data, required this.onReturn});

  final ContinueHeroData data;

  /// Reading changes progress on the server, so whatever the card opened has
  /// to be asked about again on the way back. The screen owns the providers,
  /// so it says what that means rather than the card reaching back into it.
  final Future<void> Function() onReturn;

  Future<void> _open(BuildContext context, String location) async {
    await context.push(location);
    await onReturn();
  }

  /// The cover's own size — what it is drawn at, and the floor under the
  /// height it fills beside the words: see [_FillingCover].
  static const _coverWidth = 92.0;
  static const _coverWidthTablet = 160.0;

  String get _seriesLocation => seriesLocation(data.series);

  /// What the button opens, or null while the chapter is still unknown:
  /// there is nothing to resume yet.
  VoidCallback? _continue(BuildContext context) => switch (data.point) {
    null => null,
    final point => () => _open(
      context,
      readerLocation(point.entry.chapter, started: point.started),
    ),
  };

  /// A chapter nobody has opened starts at the beginning; one under way
  /// resumes where it was left.
  ///
  /// Zero while the chapter is still in flight. The card is drawn as soon as
  /// its series is known and fills the chapter in behind, so there is a real
  /// frame where there is no point yet — and everything read during that
  /// frame has to survive it. This getter is reached from `build`, not only
  /// from the button, which is what made a `!` here a crash on startup
  /// rather than an impossibility.
  int get _resumePage {
    final point = data.point;
    if (point == null) return 0;
    return point.started ? point.entry.chapter.pagesRead : 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(kavitaClientProvider);
    final series = data.series;
    // **The button follows the track it belongs to, on both sizes.** Drawn
    // inside the column of words, directly under the progress bar and at the
    // bar's own width and left edge, the two are one block. A row of its own
    // under the card instead left a tablet with a card's worth of nothing
    // above the button and nothing left to be centred against, and left a
    // phone with the one thing on the screen lined up with nothing at all.
    final button = _ContinueButton(onPressed: _continue(context));
    final tablet = isTabletLayout(context);
    final coverWidth = tablet ? _coverWidthTablet : _coverWidth;
    final coverHeight = coverWidth / coverAspectRatio;

    // The card is about one chapter — it names it, counts what is left of it
    // and opens it — so the picture beside all that is the chapter's, the
    // untouched next volume included: a series cover here, the frame after a
    // volume's last page, said nothing about which one came next. The series
    // cover stands in for the frame where the chapter is not known yet, and
    // where the button would start the series or offer it again — there is
    // no chapter you are inside, and a cover is a poor way to say so.
    //
    // The backdrop below keeps its own, looser rule — it draws the resume
    // point's chapter as soon as there is one, page 0 included. That is
    // Home's own bargain: unlike the series screen, this card exists only to
    // be resumed from, and a card with no artwork at all is what refusing
    // that page would cost.
    final pictured = entryPictured(data.point);
    // A book has no page picture to draw behind the card — see
    // [Chapter.hasPagePictures]. What stands in is the cover, which is what
    // the backdrop already falls back to for a page that will not load.
    // Edge to edge, like the shelves under it: with the brand kit's surface
    // now plainly lighter than the page, a card inset by a gutter read as
    // narrower than the shelf that scrolls under both screen edges below it.
    // The band has no corners to round; its contents keep the gutter so they
    // stand at the same left edge as the shelf's label and first tile. And
    // nothing under it: the shelf that follows brings the section gap, as
    // every section of Home does, and a gap of the band's own doubled it.
    return ClipRect(
      child: ColoredBox(
        color: patraSurface,
        child: Stack(
          children: [
            Positioned.fill(
              child: PageBackdrop(
                seriesId: series.id,
                chapterId: switch (data.point?.entry.chapter) {
                  final chapter? when chapter.hasPagePictures => chapter.id,
                  _ => null,
                },
                page: _resumePage,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 18),
              // **The card is as tall as its words, and the cover takes that
              // height** — see [_FillingCover]. The row is what makes the two
              // one height; the cover's width follows from it by the 2:3
              // ratio, so the space a 92pt cover used to leave empty under
              // itself on a phone is the space it now fills.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: () => _open(context, _seriesLocation),
                      child: _FillingCover(
                        minHeight: coverHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(radiusCover),
                          child: CoverImage(
                            url: pictured == null
                                ? client.seriesCoverUrl(series.id)
                                : entryCoverUrl(client, pictured),
                            headers: client.imageHeaders,
                            seriesId: series.id,
                            seriesName: series.name,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: _coverGap),
                    Expanded(
                      child: _Details(
                        data: data,
                        onOpenSeries: () => _open(context, _seriesLocation),
                        button: button,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A cover that takes the height of the words beside it, never shrinking
/// below the size a cover is drawn at.
///
/// **The height comes from the words.** The card's row is an
/// `IntrinsicHeight`, so the band is as tall as its column of words; the
/// cover is stretched to that height and its width follows from it by the
/// 2:3 ratio. That is what fills the space a 92pt cover used to leave empty
/// under itself on a phone — a landing page for one chapter, where the cover
/// and the words are one object and a short cover beside tall ones reads as a
/// cover that failed to load. On a tablet the words are the shorter of the
/// two and nothing moves: the cover is its own 160x240, which is what
/// [minHeight] is for.
///
/// **And the picture says nothing to that question.** A decoded image reports
/// its own pixel dimensions as its intrinsic size, so a 1500px cover would
/// make the band 1500pt tall the moment its picture landed in the cache —
/// and not before, which is a bug no widget test with an unloaded image can
/// see. [NoIntrinsic] is what keeps a picture's pixels out of the card's
/// height: the space between a cover and the words is a layout decision, and
/// an image is not entitled to an opinion about it.
class _FillingCover extends StatelessWidget {
  const _FillingCover({required this.minHeight, required this.child});

  /// The height a cover is drawn at when the words are shorter than it.
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(minHeight: minHeight),
    child: NoIntrinsic(
      child: AspectRatio(aspectRatio: coverAspectRatio, child: child),
    ),
  );
}

/// The height one line of [style] takes, at the text scale the screen is read
/// at.
///
/// Asked of the text engine rather than worked out from the style: a line is
/// `fontSize * height` only when the style carries a `height`, and what a font
/// makes of a line otherwise is the font's business.
double _lineHeight(BuildContext context, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: 'X', style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.height;
}

/// The card's one action.
///
/// Held to [controlMaxWidth] and to a fixed height, because a button given a
/// band's width to fill stops reading as a button: that is the same rule the
/// series hero follows. It is drawn under the progress track on the card, at
/// the track's own width — so [controlMaxWidth] here is the track's cap
/// rather than a placement of its own, and on a phone, where the column of
/// words is narrower than that, the two take the column.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: controlMaxWidth),
    child: SizedBox(
      height: minHitTarget + 4,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.menu_book_rounded, size: 20),
        label: Text(AppLocalizations.of(context).seriesContinuePlain),
      ),
    ),
  );
}

class _Details extends ConsumerWidget {
  const _Details({
    required this.data,
    required this.onOpenSeries,
    required this.button,
  });

  final ContinueHeroData data;
  final VoidCallback onOpenSeries;

  /// The card's one action, drawn here because it follows the progress track
  /// the column already holds — at the track's width and left edge, under it.
  ///
  /// It is handed down rather than built here so the card builds one of it;
  /// the gap it keeps from the track is the band's own.
  final Widget button;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tablet = isTabletLayout(context);
    final series = data.series;
    final entry = data.point?.entry;
    final chapter = entry?.chapter;
    final type = ref.watch(catalogue.libraryTypeProvider(series.libraryId));
    final resumeName = entry == null
        ? null
        : type.resumeTitle(l10n, entry.volume, chapter!);
    final titleStyle = PatraText.serifTitle(size: tablet ? 24 : 21);
    // **Two lines of the title's own style, reserved whether or not the title
    // needs them.** The card is as tall as this column and the cover beside
    // it is stretched to that height, so the column's height may not depend
    // on how long the title happens to be: the words are measured by an
    // `IntrinsicHeight` at the band's *full* width, before the cover takes
    // its share back, and a title that fits one line there and needs two
    // where it is drawn leaves the card 26pt shorter than its own content —
    // which is a RenderFlex overflow, not a tight fit. So the block is two
    // lines whatever the title says, and a short title sits at the top of
    // them. The height is asked of the text engine rather than computed from
    // the style, because a font has its own idea of what a line is.
    final titleBlock = 2 * _lineHeight(context, titleStyle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(l10n.continueSection, color: patraAccent),
        const SizedBox(height: 6),
        SizedBox(
          height: titleBlock,
          child: Align(
            // The title sits at the **bottom** of the block it is given, so a
            // one-line title stays joined to the chapter named under it and
            // the reserve is air above the title rather than a gap through
            // the middle of the words.
            alignment: AlignmentDirectional.bottomStart,
            child: GestureDetector(
              onTap: onOpenSeries,
              child: Text(
                series.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
          ),
        ),
        if (resumeName != null && resumeName.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            resumeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PatraText.metadata(
              size: tablet ? 13 : 11.5,
              color: patraTextOnArt,
            ),
          ),
        ],
        if (chapter != null && chapter.pages > 0) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: controlMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.homeHeroPagesLeft(
                      (chapter.pages - chapter.pagesRead).clamp(
                        0,
                        chapter.pages,
                      ),
                    ),
                    // One line, for the same reason the title is two: the
                    // column's height is what the cover is stretched to, and
                    // it is measured at a width the column does not end up
                    // with.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PatraText.metadata(
                      size: tablet ? 12 : 10.5,
                      color: patraTextOnArt,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(radiusTrack),
                  child: LinearProgressIndicator(
                    value: chapter.pages > 0
                        ? chapter.pagesRead / chapter.pages
                        : 0.0,
                    minHeight: 3,
                    backgroundColor: patraTrack,
                    valueColor: const AlwaysStoppedAnimation(patraAccent),
                  ),
                ),
                // Inside the track's own cap and stretching to it, so the
                // button starts where the bar starts and ends where it ends:
                // the two are one block, and a button that only nearly lined
                // up with the bar above it would be the thing that reads as
                // wrong. Where the column is narrower than the cap — a phone,
                // at 246 — both take the column instead, and still agree.
                const SizedBox(height: _buttonGap),
                button,
              ],
            ),
          ),
        ] else ...[
          // No track to follow — the chapter is still in flight — and the
          // button is drawn where it would have been, so the card does not
          // change shape when the answer arrives.
          const SizedBox(height: _buttonGap),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: controlMaxWidth),
            child: button,
          ),
        ],
      ],
    );
  }
}
