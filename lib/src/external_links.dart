import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// The addresses this app sends somebody out to, and the one seam it goes
/// through.
///
/// Small, but a seam rather than a `launchUrl` at each call site for the
/// reason `Keychain` is one: a test cannot open a browser, so without it
/// there is no way to check the two things that can actually be wrong here —
/// a mistyped address, and a row that does not fire. [MemoryLinks] in the
/// tests records what was asked for.
abstract class ExternalLinks {
  /// Where the code is. Named here and not in a string in a widget, because
  /// the privacy policy's URL has to agree with the one the store listings
  /// were given and this is the one place to look.
  static const source = 'https://github.com/rbioteau/patra';

  /// The policy the two store listings point at, served by GitHub Pages out
  /// of `site/`. Play asks for it on the listing **and** within the app for
  /// an app that touches user data, which is what this row answers.
  static const privacy = 'https://rbioteau.github.io/patra/privacy.html';

  /// Whose work this is. Not localised: a symbol, a number and a name, with
  /// no word in it for a translator to change — and written down rather than
  /// read off `DateTime.now()`, a copyright dating from publication and not
  /// from the clock of whoever is holding the phone.
  static const copyright = '© 2026 Romain Bioteau';

  /// The same, plus the terms the code is published under, for the head of
  /// the licence page — where naming Apache 2.0 answers the question the
  /// page is there to ask. Never "all rights reserved", which would
  /// contradict a licence that grants them.
  static const legalese = '$copyright · Apache 2.0';

  Future<bool> open(String url);
}

class SystemLinks implements ExternalLinks {
  const SystemLinks();

  @override
  Future<bool> open(String url) => launchUrl(
    Uri.parse(url),
    // The browser rather than a view inside the app: what is on the other
    // end is a page about this app, read once, and an in-app browser would
    // put the app's own chrome around a claim the app is making about
    // itself.
    mode: LaunchMode.externalApplication,
  );
}

final externalLinksProvider = Provider<ExternalLinks>(
  (ref) => const SystemLinks(),
);
