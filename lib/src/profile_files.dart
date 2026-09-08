/// A directory name for a `Profile.id`, which is an address with an account
/// id on the end of it (`https://kavita.example#3`) and so carries `:`, `/`
/// and `#`.
///
/// Percent-encoded rather than hashed: it is reversible by eye when somebody
/// is looking at a device's files, and — unlike a hash — two profiles cannot
/// possibly land on one directory, which is the whole bug this layout exists
/// to prevent.
///
/// One definition rather than one per store. Both file-backed stores the
/// device owns file by profile — the saved chapters and the catalogue — and
/// each argues from this encoding: that a person can read their own id off a
/// directory, and that `DownloadsService`'s sweep can tell an encoded id from
/// the all-digit chapter directory the previous layout left behind. Two
/// copies of a rule two arguments rest on is one copy too many.
String profileDirName(String profileId) => Uri.encodeComponent(profileId);
