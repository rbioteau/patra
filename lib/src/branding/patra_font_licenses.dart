import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Every face the app bundles, under the names the license page lists them by.
///
/// All three are SIL Open Font License, which travels with the font: shipping
/// the file without its notice is not a distribution the licence permits, and
/// the row in **Settings › About** is where a reader of this app goes looking
/// for one. One is the interface's sans alone, and the other two are the faces
/// a book can be set in besides the one it carries itself — which is why
/// Source Serif 4 is no longer named here: the app no longer draws it.
///
/// A face named here needs its `assets/fonts/<Family>-OFL.txt` to exist *and*
/// to be declared in `pubspec.yaml`. One that ships without being named here
/// fails `test/about_version_test.dart`, which reads what ships rather than
/// asking this list what it meant.
const _families = [
  'SpaceGrotesk',
  'Literata',
  'AtkinsonHyperlegibleNext',
];

/// Puts every bundled face's OFL notice where Flutter's own license page looks
/// for them.
///
/// Call once, after `WidgetsFlutterBinding.ensureInitialized()`.
void registerPatraFontLicenses() {
  if (_registered) return;
  _registered = true;
  for (final family in _families) {
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString('assets/fonts/$family-OFL.txt');
      yield LicenseEntryWithLineBreaks([family], text);
    });
  }
}
