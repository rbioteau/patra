import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Every face the app bundles, under the names the license page lists them by.
///
/// All four are SIL Open Font License, which travels with the font: shipping
/// the file without its notice is not a distribution the licence permits, and
/// the row in **Settings › About** is where a reader of this app goes looking
/// for one. Two are the interface's and two are a book's (#77) — this file was
/// written when there were only the first two, and a book set in Literata or
/// Atkinson Hyperlegible Next had no notice to read until the two were named
/// here.
///
/// A face named here needs its `assets/fonts/<Family>-OFL.txt` to exist *and*
/// to be declared in `pubspec.yaml`. One that ships without being named here
/// fails `test/about_version_test.dart`, which reads what ships rather than
/// asking this list what it meant.
const _families = [
  'SpaceGrotesk',
  'SourceSerif4',
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
