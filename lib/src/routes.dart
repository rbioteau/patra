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
import 'auth/session.dart';

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

/// The picker of faces: who is reading, asked before anything is read.
const profilesLocation = '/profiles';

/// The sign-in form, and what it should already know.
///
/// [profile] is a remembered person being signed in again — the form takes
/// their address and their name from it, so the only thing left to type is
/// the password. [expired] says the stored key was refused rather than
/// missing, which is a different sentence and not one the form could work out
/// for itself: by the time it is drawn, the key has already been dropped.
String loginLocation({Profile? profile, bool expired = false}) {
  final query = {
    if (profile != null) 'profile': profile.id,
    if (expired) 'expired': '1',
  };
  if (query.isEmpty) return '/login';
  return Uri(path: '/login', queryParameters: query).toString();
}

/// Where a device with no session belongs.
///
/// The picker, unless there is nobody to choose between: an empty device gets
/// the form, and a device holding one profile that needs a password gets the
/// form with that profile already in it. **A single profile never meets the
/// picker** — it costs a tap to be asked a question with one answer.
///
/// A lone profile that still holds its key does land here, and lands on the
/// picker: a cold start never produces that state (a device with one profile
/// opens straight into it), and where something else has, one face and one
/// tap beats asking for a password nothing needs.
String signedOutLocation(AuthState auth) {
  final profiles = auth.profiles;
  if (profiles.isEmpty) return loginLocation();
  final only = profiles.length == 1 ? profiles.single : null;
  if (only != null && !only.hasCredential) return loginLocation(profile: only);
  return profilesLocation;
}
