import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/auth/session.dart';
import 'src/settings/reading_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = await SessionStorage.load();
  final readingDirection = await ReadingSettingsStore.load();
  runApp(
    ProviderScope(
      overrides: [
        initialAuthStateProvider.overrideWithValue(auth),
        initialReadingDirectionProvider.overrideWithValue(readingDirection),
      ],
      child: const VersoApp(),
    ),
  );
}
