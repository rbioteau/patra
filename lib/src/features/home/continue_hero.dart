import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../catalogue/catalogue_reads.dart' as catalogue;
import '../../routes.dart';
import '../../widgets/series_hero.dart';

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

/// The Continue shelf's series, given the full treatment.
///
/// A promotion, never an obligation: where the card cannot be complete the
/// hero is simply not drawn, and its series goes back into the shelf below.
///
/// **It is the series screen's own hero** — `SeriesHero`, one widget, so a
/// series reads the same wherever it is drawn — and what this screen adds is
/// nothing at all: the card sits where that screen's hero sits, at the top of
/// the list with the app bar above it, and names itself the way every hero
/// does. It used to carry a `CONTINUE` eyebrow and a gap, which is what a
/// *shelf* wears; the hero is not one.
///
/// What it does wire is the two doors, which are the screen's business: the
/// card is the only way to the series it promotes — that series having been
/// taken out of the shelf below it — and opening either one comes back
/// through [onReturn], because reading changes progress on the server.
class ContinueHero extends ConsumerWidget {
  const ContinueHero({super.key, required this.series, required this.onReturn});

  final Series series;

  /// Reading changes progress on the server, so whatever the card opened has
  /// to be asked about again on the way back. The screen owns the providers,
  /// so it says what that means rather than the card reaching back into it.
  final Future<void> Function() onReturn;

  Future<void> _open(BuildContext context, String location) async {
    await context.push(location);
    await onReturn();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Deliberately one layer down from `seriesVolumesProvider`, which lays
    // the series screen's optimistic mark-read on top of this: that override
    // map is autoDispose so that it dies with that screen and the next visit
    // is the server's word again, and a home screen watching it would keep it
    // alive for the life of the app. What keeps this honest instead is that
    // every path back from reading re-fetches — see `_refresh`.
    final volumes = ref.watch(catalogue.volumes(series.id).provider);
    return SeriesHero(
      seriesId: series.id,
      seriesName: series.name,
      volumes: volumes,
      onOpenSeries: () => _open(context, seriesLocation(series)),
      onRead: (chapter, {required started}) =>
          _open(context, readerLocation(chapter, started: started)),
    );
  }
}
