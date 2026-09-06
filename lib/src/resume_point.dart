/// Where reading a series picks up again — and the one place that decides it.
///
/// Two screens ask this question: the series hero's action button and the
/// home screen's Continue hero. Kavita has an endpoint for it
/// (`/api/Reader/continue-point`), and we deliberately do not call it: its
/// own description states a different rule from this one, whether it truly
/// differs is not knowable from the spec, and a target the server decides is
/// always a round trip behind the optimistic mark-read the series screen
/// applies. See `docs/adr/0002-resume-point-computed-in-the-app.md`.
///
/// Both screens call this, so they agree by construction rather than by
/// coincidence.
library;

import 'api/models.dart';

/// A chapter together with the volume it belongs to, which is what names a
/// volume that has no chapter breakdown of its own.
typedef ResumeEntry = ({Volume volume, Chapter chapter});

/// [entry] is where to resume. [started] is whether the *series* has been
/// read at all, which is a different question — finishing a volume leaves the
/// next one untouched. [allRead] means there was nothing left, so [entry] is
/// the beginning again.
typedef ResumePoint = ({ResumeEntry entry, bool started, bool allRead});

int bySortOrder(Chapter a, Chapter b) => a.sortOrder.compareTo(b.sortOrder);

List<Chapter> sortedChapters(List<Chapter> chapters) =>
    [...chapters]..sort(bySortOrder);

/// Every chapter in reading order — volumes first, then loose chapters, then
/// specials, the order the series screen renders its sections in — each
/// paired with the volume it belongs to.
List<ResumeEntry> orderedChapters(List<Volume> volumes) {
  final inVolumes = <ResumeEntry>[];
  final loose = <ResumeEntry>[];
  final specials = <ResumeEntry>[];
  for (final volume in volumes) {
    final numbered = !volume.isLooseLeaf && !volume.isSpecials;
    for (final chapter in sortedChapters(volume.chapters)) {
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
    list.sort((a, b) => bySortOrder(a.chapter, b.chapter));
  }
  return [...inVolumes, ...loose, ...specials];
}

/// The chapter to resume at: the first one not finished, else the first.
///
/// Null when the series has no chapters at all.
ResumePoint? resumePoint(List<Volume> volumes) {
  final entries = orderedChapters(volumes);
  if (entries.isEmpty) return null;
  // "Started" is a fact about the *series*, not about the chapter the button
  // happens to land on. Finishing a volume leaves the next one untouched, so
  // reading it against the target alone said "Start reading" to someone
  // halfway through a series. Kavita's own web client asks it of the series
  // too — `hasReadingProgress` is that client's concept and is not an API
  // field, so this mirrors its rule rather than reading a value.
  final started = entries.any((entry) => entry.chapter.pagesRead > 0);
  for (final entry in entries) {
    if (!entry.chapter.isRead) {
      return (entry: entry, started: started, allRead: false);
    }
  }
  return (entry: entries.first, started: started, allRead: true);
}
