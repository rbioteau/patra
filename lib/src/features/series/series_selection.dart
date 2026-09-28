import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/models.dart';
import '../../downloads/downloads_provider.dart';
import '../../resume_point.dart';
import '../../settings/profile_preferences.dart';

/// How a series is drawn when its reader has never switched it.
///
/// A grid is a shelf of covers, so it is the default only where every entry
/// *has* a cover of its own: a manga or a comic whose volumes are the reading
/// units. A volume broken into chapters mostly lends each chapter its own
/// cover, which a grid would show as the same picture five times, and a book
/// is read by its title rather than by its jacket — both are rows. Specials
/// take no part in the question: they close the list either way.
SeriesView defaultSeriesView(LibraryType type, List<Volume> volumes) {
  if (type.usesBooks) return SeriesView.list;
  final units = [
    for (final entry in orderedChapters(volumes))
      if (!entry.chapter.isSpecial) entry,
  ];
  return units.isNotEmpty && units.every((entry) => entry.isWholeVolume)
      ? SeriesView.grid
      : SeriesView.list;
}

/// Which entries of a series are selected for a batch — keyed by the id of
/// the chapter each entry stands for — or null where the screen is not
/// selecting at all.
///
/// Screen-scoped: it dies with the screen, and it is deliberately **not**
/// reset by switching between list and grid, since the two are one list
/// drawn two ways.
class SeriesSelectionNotifier extends Notifier<Set<int>?> {
  @override
  Set<int>? build() => null;

  /// Enters selection with [chapterId] in it — what a long-press does — or
  /// adds it where selection is already open.
  void start(int chapterId) => state = {...?state, chapterId};

  /// Adds or takes away one entry. Emptied by hand, selection stays open: the
  /// bar under it says what a tap does next.
  void toggle(int chapterId) {
    final current = state;
    if (current == null) return;
    state = current.contains(chapterId)
        ? ({...current}..remove(chapterId))
        : {...current, chapterId};
  }

  /// Selects exactly [chapterIds] — the "All unread" shortcut, which says
  /// what the selection *is* rather than what to add to it.
  void replace(Iterable<int> chapterIds) => state = chapterIds.toSet();

  /// Leaves selection.
  void clear() => state = null;
}

final seriesSelectionProvider =
    NotifierProvider.autoDispose<SeriesSelectionNotifier, Set<int>?>(
      SeriesSelectionNotifier.new,
    );

/// What a selection holds against what the device has.
///
/// [toFetch] is what a save would queue: neither here nor already on its way.
/// A paused or failed copy is in it, since the queue sends it on from the
/// pages it kept. [allSaved] is the one case the bar offers removal for —
/// taking copies off the device is only offered where that is all there is
/// to do with the selection.
typedef SelectionSummary = ({int count, Set<int> toFetch, bool allSaved});

SelectionSummary summarizeSelection(
  Set<int> selected,
  DownloadMembership membership,
) => (
  count: selected.length,
  toFetch: {
    for (final id in selected)
      if (!membership.saved.contains(id) && !membership.inFlight.contains(id))
        id,
  },
  allSaved: selected.isNotEmpty && selected.every(membership.saved.contains),
);
