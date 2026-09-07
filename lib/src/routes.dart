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

/// Whether a location names **content** — a series or a chapter, the two
/// things [seriesLocation] and [readerLocation] build and the two a link from
/// outside the app can point at.
///
/// Everything else a location can be is the app's own furniture: a gate, or
/// whichever tab somebody happened to be on. Nobody links to those, and one
/// held would send the next person signing in to where the previous one was.
///
/// The id has to be one, and that is not pedantry: both screens parse theirs
/// out of the path, so `/series/nowhere` is not a link that opens nothing —
/// it is a link that opens a crash. A link nothing can be made of is dropped
/// here and the app opens where it always would.
bool linksToContent(String location) {
  final segments = Uri.parse(location).pathSegments;
  if (segments.length != 2) return false;
  if (segments.first != 'series' && segments.first != 'reader') return false;
  return int.tryParse(segments[1]) != null;
}

/// A link the app was opened with, held while it asks who is reading.
///
/// A link names content and a profile names who is reading, and identity
/// comes first: followed as it arrives, a link would open in whichever
/// session was last used, which on a shared device is a coin toss. So the
/// app opens at its own gate and the link waits here; the first moment
/// somebody is reading, it is spent.
///
/// It lives beside the builders that make these locations because it is the
/// same subject — what a location is, and what becomes of one that had to
/// wait.
///
/// **A launch is the only thing that ever fills one**, and that is a rule
/// about who, not about tidiness. Filling it from anywhere else — the
/// redirect, say, which meets a content location again whenever a session
/// ends under somebody still reading one — would hold the screen person A
/// was on and push it at person B when they signed in. That is the coin toss
/// this exists to prevent, arriving an hour later. What it costs is a link
/// that reaches an app already running and signed out: it goes where
/// go_router takes it, which is the gate, and is not held.
class PendingLink {
  /// Holds [location] if it is a link at all ([linksToContent]); anything
  /// else is nothing held.
  PendingLink(String location)
    : _held = linksToContent(location) ? location : null;

  /// Nothing held, which is what every app built after the first one is
  /// given: `defaultRouteName` still names the link that started the
  /// process, so a container built for somebody else (`SessionScope`) must
  /// start empty or one person's link opens in another's session.
  PendingLink.none() : _held = null;

  String? _held;

  /// What was held, if anything — and never twice. A link is spent by being
  /// opened, so switching profile an hour later opens Home like any other
  /// switch.
  String? take() {
    final held = _held;
    _held = null;
    return held;
  }
}
