import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import 'auth/session.dart';
import 'features/downloads/downloads_screen.dart';
import 'features/home/home_screen.dart';
import 'features/library/library_screen.dart';
import 'features/login/login_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/series/series_detail_screen.dart';
import 'features/settings/settings_screen.dart';
import 'theme.dart';

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

      // Drill-down screens live outside the shell: full-screen, with the
      // system back button popping them (see CLAUDE.md on push vs go).
      GoRoute(
        path: '/series/:id',
        builder: (_, state) => SeriesDetailScreen(
          seriesId: int.parse(state.pathParameters['id']!),
          seriesName: state.uri.queryParameters['name'] ?? '',
          libraryId:
              int.tryParse(state.uri.queryParameters['library'] ?? '') ?? 0,
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

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _PatraShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (_, _) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/downloads',
                builder: (_, _) => const DownloadsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _PatraShell extends StatelessWidget {
  const _PatraShell({required this.shell});

  final StatefulNavigationShell shell;

  /// Whether every label fits on one line in its share of the bar.
  ///
  /// French labels are half again as long as the English ones, and a large
  /// system font size makes any of them overflow: measure rather than guess,
  /// and drop to icons when there is no room.
  bool _labelsFit(BuildContext context, List<String> labels) {
    final cell = MediaQuery.sizeOf(context).width / labels.length;
    final scaler = MediaQuery.textScalerOf(context);
    final style = PatraText.navLabel(selected: true);
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textScaler: scaler,
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      // 8dp of breathing room on each side of the label.
      if (painter.width + 16 > cell) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.navHome,
      l10n.navLibrary,
      l10n.navDownloads,
      l10n.navSettings,
    ];
    final showLabels = _labelsFit(context, labels);

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: patraBorder)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          height: showLabels ? 68 : 56,
          labelBehavior: showLabels
              ? NavigationDestinationLabelBehavior.alwaysShow
              : NavigationDestinationLabelBehavior.alwaysHide,
          // goBranch keeps each tab's own navigation stack.
          onDestinationSelected: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l10n.navHome,
              tooltip: l10n.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.grid_view_outlined),
              selectedIcon: const Icon(Icons.grid_view),
              label: l10n.navLibrary,
              tooltip: l10n.navLibrary,
            ),
            NavigationDestination(
              icon: const Icon(Icons.download_outlined),
              selectedIcon: const Icon(Icons.download),
              label: l10n.navDownloads,
              tooltip: l10n.navDownloads,
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_outlined),
              selectedIcon: const Icon(Icons.tune),
              label: l10n.navSettings,
              tooltip: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class PatraApp extends ConsumerWidget {
  const PatraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Patra',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: patraTheme(),
      darkTheme: patraTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(_routerProvider),
    );
  }
}
