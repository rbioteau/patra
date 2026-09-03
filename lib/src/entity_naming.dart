import '../l10n/generated/app_localizations.dart';
import 'api/models.dart';

/// What to call the parts of a series, which depends on the library type.
///
/// This mirrors Kavita's own `EntityNamingService`: a comic has issues where a
/// manga has chapters, and a book library calls a volume a book. Kavita words
/// its entire series page this way, and a client that says "Chapitre 12" over
/// a comic issue is speaking a different language from the server it browses.
///
/// French glossary, fixed: specials = hors-série, volume = tome,
/// chapter = chapitre, issue = numéro, storyline = arc narratif.
extension LibraryTypeNaming on LibraryType {
  /// Header over the volumes.
  String volumesTitle(AppLocalizations l10n) =>
      usesBooks ? l10n.booksTitle : l10n.volumesTitle;

  /// One volume, by its Kavita name (already just the number).
  String volumeLabel(AppLocalizations l10n, String name) =>
      usesBooks ? l10n.bookLabel(name) : l10n.volumeLabel(name);

  /// Header over the chapters that belong to no volume.
  String chaptersTitle(AppLocalizations l10n) => switch (this) {
    LibraryType.comic || LibraryType.comicVine => l10n.issuesTitle,
    LibraryType.book || LibraryType.lightNovel => l10n.booksTitle,
    _ => l10n.chaptersTitle,
  };

  /// Volumes and volumeless chapters read as one story; Kavita calls that the
  /// storyline and only shows it where it means something.
  String storylineTitle(AppLocalizations l10n) => l10n.storylineTitle;

  String specialsTitle(AppLocalizations l10n) => l10n.specialsTitle;

  /// One chapter, numbered in the type's own unit.
  String numberedChapterLabel(AppLocalizations l10n, String range) =>
      switch (this) {
        LibraryType.comic || LibraryType.comicVine => l10n.issueLabel(range),
        LibraryType.book || LibraryType.lightNovel => l10n.bookLabel(range),
        _ => l10n.chapterLabel(range),
      };

  /// The hero button, which names what it will open in the same vocabulary.
  String continueChapterLabel(AppLocalizations l10n, String range) =>
      switch (this) {
        LibraryType.comic ||
        LibraryType.comicVine => l10n.seriesContinueIssue(range),
        LibraryType.book ||
        LibraryType.lightNovel => l10n.seriesContinueBook(range),
        _ => l10n.seriesContinue(range),
      };

  String continueVolumeLabel(AppLocalizations l10n, String name) => usesBooks
      ? l10n.seriesContinueBook(name)
      : l10n.seriesContinueVolume(name);

  /// The full name of one chapter, following Kavita's rules: a special is
  /// known only by its title, and a title is *appended* to the number rather
  /// than replacing it — but only when it adds something the number does not
  /// already say.
  String chapterTitle(AppLocalizations l10n, Chapter chapter) {
    final title = chapter.titleName.isNotEmpty
        ? chapter.titleName
        : chapter.title;
    if (chapter.isSpecial) return title;

    final base = numberedChapterLabel(l10n, chapter.range);
    if (title.isEmpty || title == chapter.range || title == base) return base;
    return '$base - $title';
  }
}
