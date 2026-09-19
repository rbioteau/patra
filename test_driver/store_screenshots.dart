/// The half of the screenshot run that owns a filesystem.
///
/// `flutter drive` runs this on the host while the recipe
/// (`integration_test/store_screenshots_test.dart`) runs on the device: a
/// screenshot is taken there and delivered here as bytes through the driver
/// extension, and this is what turns those bytes into files a store can take.
///
/// It writes PNG32, which is what the device gave it. Flattening — the stores
/// refuse an alpha channel — belongs to `tool/store_screenshots.sh`, next to
/// the rest of the post-processing, so that a run that fails here leaves
/// nothing half-made in the repository.
library;

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  // Where the screenshots go: the script exports it, because a `--dart-define`
  // reaches the target on the device and not this process. One language per
  // run — the recipe forces the language before its first shot — so the
  // directory is the whole of what tells the two listings apart.
  final directory =
      Platform.environment['PATRA_SHOT_DIR'] ?? 'store/screenshots';

  await integrationDriver(
    // Nothing here compares or judges: the recipe's job is to take the
    // pictures, and a run that ends with files on disk has done it. Returning
    // false would fail the run, which is for a mismatch against a baseline —
    // and there is no baseline for a screenshot whose whole point is to show
    // the app as it is today.
    onScreenshot:
        (String name, List<int> image, [Map<String, Object?>? args]) async {
          final file = File('$directory/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(image);
          stdout.writeln('wrote ${file.path}');
          return true;
        },
    responseDataCallback: null,
  );
}
