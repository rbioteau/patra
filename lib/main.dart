import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/auth/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = await SessionStorage.load();
  runApp(
    ProviderScope(
      overrides: [initialSessionProvider.overrideWithValue(session)],
      child: const VersoApp(),
    ),
  );
}
