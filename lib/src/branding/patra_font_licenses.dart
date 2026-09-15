import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Puts the two bundled faces' OFL notices where Flutter's own license page
/// looks for them.
///
/// Both are SIL Open Font License, which travels with the font: shipping the
/// file without the notice is not a distribution the licence permits, and the
/// license page is where a reader of this app would go looking for one.
///
/// Call once, after `WidgetsFlutterBinding.ensureInitialized()`.
void registerPatraFontLicenses() {
  if (_registered) return;
  _registered = true;
  for (final family in const ['SpaceGrotesk', 'SourceSerif4']) {
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString('assets/fonts/$family-OFL.txt');
      yield LicenseEntryWithLineBreaks([family], text);
    });
  }
}
