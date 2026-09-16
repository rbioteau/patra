import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/settings/reading_settings.dart';

import 'test_support.dart';

/// Every family `pubspec.yaml` declares, with the files behind it and whether
/// one of them is an italic.
///
/// Read out of the manifest rather than imported, because the manifest is
/// what is being pinned: a face the app does not ship is a face the engine
/// answers with the default one and nothing says so, which is the same
/// invisible kind of failure `test/shared_image_cache_test.dart` exists for.
Map<String, ({List<String> assets, bool italic})> _declaredFaces() {
  final declared = <String, ({List<String> assets, bool italic})>{};
  final manifest = File('pubspec.yaml').readAsStringSync();
  for (final block in manifest.split('\n    - family: ').skip(1)) {
    declared[block.split('\n').first.trim()] = (
      assets: [
        for (final match in RegExp(r'- asset: (\S+)').allMatches(block))
          match.group(1)!,
      ],
      italic: block.contains('style: italic'),
    );
  }
  return declared;
}

void main() {
  // The direction is not here any more: #58 took the device's rung out of the
  // chain, so the key is written no more. What is left of this store is the
  // one device preference that survived it, and `directionNamed`, which the
  // two direction maps still parse their values with
  // (`test/profile_preferences_test.dart`).
  group('the magnify preference', () {
    // The concept was called a loupe until the word was found to be wrong for
    // it. The identifiers moved; the storage key deliberately did not, because
    // it is already written on every device that has turned the setting on.
    test(
      'is stored under its original key, whatever the code calls it',
      () async {
        final keychain = MemoryKeychain();
        await ReadingSettingsStore(keychain).saveMagnify(true);
        expect(
          keychain.values.keys.where((k) => k.endsWith('loupeGesture')),
          isNotEmpty,
          reason:
              'renaming this key would silently reset the setting on every '
              'device that has it on',
        );
      },
    );

    test('round-trips, and is off when nothing was ever stored', () async {
      final store = ReadingSettingsStore(MemoryKeychain());
      expect(await store.loadMagnify(), isFalse);
      await store.saveMagnify(true);
      expect(await store.loadMagnify(), isTrue);
      await store.saveMagnify(false);
      expect(await store.loadMagnify(), isFalse);
    });

    test('a value written before the rename still reads back on', () async {
      // The exact string a device that turned it on already holds. (Android
      // prefixes it natively, below the method channel, so what the Dart side
      // reads is the bare key.)
      final store = ReadingSettingsStore(
        MemoryKeychain({'loupeGesture': 'true'}),
      );
      expect(await store.loadMagnify(), isTrue);
    });
  });

  group('the faces the reader offers', () {
    // Bundled rather than fetched, which is what lets a book saved for the
    // train open in the face its reader chose with no server at all (#77).
    test('are every one declared, with the file that draws it', () {
      final declared = _declaredFaces();
      for (final face in ReadingFace.values) {
        final entry = declared[face.family];
        expect(
          entry,
          isNotNull,
          reason: '${face.family} is offered but not bundled, so it would be '
              'drawn in the default face with nothing saying so',
        );
        expect(entry!.assets, isNotEmpty);
        for (final asset in entry.assets) {
          expect(
            File(asset).existsSync(),
            isTrue,
            reason: '$asset is declared but not in the repository',
          );
        }
        // One variable file per family — one file answers every weight, so a
        // static per weight is a bundle four times the size for nothing.
        final files = entry.assets.map((a) => a.split('/').last).toSet();
        expect(
          files.length,
          face.canSetItalic ? 2 : 1,
          reason: '${face.family} ships one file per family, plus its italic',
        );
        expect(
          entry.italic,
          face.canSetItalic,
          reason: '${face.family} must say the same thing about its italic '
              'as the code that sets a book in it does',
        );
      }
    });

    test('each ships the licence it is published under', () {
      final declared = _declaredFaces();
      for (final face in ReadingFace.values) {
        for (final asset in declared[face.family]!.assets) {
          final name = asset.split('/').last;
          final family = name.substring(0, name.indexOf('-'));
          expect(
            File('assets/fonts/$family-OFL.txt').existsSync(),
            isTrue,
            reason: '$name is shipped without the OFL it is licensed under',
          );
        }
      }
    });
  });
}
