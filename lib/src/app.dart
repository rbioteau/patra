import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import 'auth/session.dart';
import 'features/library/libraries_screen.dart';
import 'features/library/series_list_screen.dart';
import 'features/login/login_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/series/series_detail_screen.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(sessionProvider) != null;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn) return onLogin ? null : '/login';
      if (onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const LibrariesScreen()),
      GoRoute(
        path: '/library/:id',
        builder: (_, state) => SeriesListScreen(
          libraryId: int.parse(state.pathParameters['id']!),
          libraryName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/series/:id',
        builder: (_, state) => SeriesDetailScreen(
          seriesId: int.parse(state.pathParameters['id']!),
          seriesName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/reader/:chapterId',
        builder: (_, state) => ReaderScreen(
          chapterId: int.parse(state.pathParameters['chapterId']!),
          initialPage:
              int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 0,
        ),
      ),
    ],
  );
});

class VersoApp extends ConsumerWidget {
  const VersoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Verso',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      routerConfig: ref.watch(_routerProvider),
    );
  }
}
