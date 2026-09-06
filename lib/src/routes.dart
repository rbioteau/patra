/// Where the app's pushable screens live, as locations rather than as strings
/// assembled at each call site.
///
/// Three screens push a series and three push the reader, and each used to
/// build the query itself. The parameters are not decoration: a series screen
/// draws its header from `name` and `library` before its fetch lands, and the
/// reader opens at `page` rather than at the beginning, so a call site that
/// forgets one is a screen that looks broken for a moment or a chapter that
/// loses its place. `app.dart` declares the routes these address.
library;

import 'api/models.dart';

/// A series, with what its screen needs to draw a header before it has data.
String seriesLocation(Series series) => Uri(
  path: '/series/${series.id}',
  queryParameters: {'name': series.name, 'library': '${series.libraryId}'},
).toString();

/// A chapter, opened where it was left.
///
/// [started] is a fact about the series rather than about this chapter:
/// finishing a volume leaves the next one untouched, so a series under way
/// resumes at the chapter's own progress while one never opened begins at the
/// beginning. Opening a saved chapter at 0 would post that back and wipe the
/// place it was left.
String readerLocation(Chapter chapter, {required bool started}) =>
    '/reader/${chapter.id}?page=${started ? chapter.pagesRead : 0}';
