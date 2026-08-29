import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/api/client_identity.dart';
import 'src/app.dart';
import 'src/auth/session.dart';
import 'src/settings/reading_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = await SessionStorage.load();
  // Resolved before runApp so the very first request — a resumed session's —
  // already identifies itself to the server.
  final identity = await ClientIdentity.resolve();
  final readingDirection = await ReadingSettingsStore.load();
  runApp(
    ProviderScope(
      overrides: [
        initialAuthStateProvider.overrideWithValue(auth),
        clientIdentityProvider.overrideWithValue(identity),
        initialReadingDirectionProvider.overrideWithValue(readingDirection),
      ],
      child: const VersoApp(),
    ),
  );
}
