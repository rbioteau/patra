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
import '../library/library_screen.dart';
import '../../widgets/page_backdrop.dart';
import '../../routes.dart';

/// The one series the home screen promotes above the Continue shelf, or null
/// when there is nothing to promote and the hero should not be drawn at all.
///
/// **The candidates are already the answer to "what is being read".** They
/// come from `/api/Series/currently-reading`, whose whole job is that
/// question, so this does not ask it again: re-deriving "started and
/// unfinished" from the payload would be second-guessing the endpoint's own
/// contract with fields it has no obligation to fill in.
///
/// What is left to decide here is only what the endpoint does not know: that
/// this app cannot open an EPUB at all — the reader refuses one outright, so
/// the hero's button, the whole reason the hero exists, would lead nowhere —
/// and which of the candidates was read most recently. A series carrying no
/// read date stays eligible; it simply cannot outrank one that says when it
/// was read, so with no dates anywhere the shelf's own order stands.
///
/// The finished guard is a belt-and-braces check for a server that hands back
/// something already read.
Series? featuredSeries(List<Series> candidates) {
  Series? best;
  for (final series in candidates) {
    if (series.isRead) continue;
    if (!series.format.isImageReadable) continue;
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

  static const _coverWidth = 92.0;
  static const _coverWidthTablet = 160.0;

  String get _seriesLocation => seriesLocation(data.series);

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
    final l10n = AppLocalizations.of(context);
    final client = ref.watch(kavitaClientProvider);
    final series = data.series;
    final tablet = isTabletLayout(context);
    final coverWidth = tablet ? _coverWidthTablet : _coverWidth;

    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, sectionGap),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radiusCard),
        child: ColoredBox(
          color: patraSurface,
          child: Stack(
            children: [
              Positioned.fill(
                child: PageBackdrop(
                  seriesId: series.id,
                  chapterId: data.point?.entry.chapter.id,
                  page: _resumePage,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _open(context, _seriesLocation),
                          child: SizedBox(
                            width: coverWidth,
                            height: coverWidth / coverAspectRatio,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(radiusCover),
                              child: CoverImage(
                                url: client.seriesCoverUrl(series.id),
                                headers: client.imageHeaders,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _Details(
                            data: data,
                            onOpenSeries: () => _open(context, _seriesLocation),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: controlMaxWidth,
                      ),
                      child: SizedBox(
                        height: minHitTarget + 4,
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: switch (data.point) {
                            null => null,
                            final point => () => _open(
                              context,
                              readerLocation(
                                point.entry.chapter,
                                started: point.started,
                              ),
                            ),
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: Text(l10n.seriesContinuePlain),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.data, required this.onOpenSeries});

  final ContinueHeroData data;
  final VoidCallback onOpenSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tablet = isTabletLayout(context);
    final series = data.series;
    final entry = data.point?.entry;
    final chapter = entry?.chapter;
    final type = ref.watch(libraryTypeProvider(series.libraryId));
    final resumeName = entry == null
        ? null
        : type.resumeTitle(l10n, entry.volume, chapter!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(l10n.continueSection, color: patraAccent),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onOpenSeries,
          child: Text(
            series.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PatraText.serifTitle(size: tablet ? 24 : 21),
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
              ],
            ),
          ),
        ],
      ],
    );
  }
}
