import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import 'auth/session.dart';
import 'features/downloads/downloads_screen.dart';
import 'features/home/home_screen.dart';
import 'features/launch/launch_animation.dart';
import 'features/library/library_screen.dart';
import 'features/login/login_screen.dart';
import 'features/profiles/profile_picker_screen.dart';
import 'features/reader/reader_screen.dart';
import 'features/series/series_detail_screen.dart';
import 'features/settings/settings_screen.dart';
import 'routes.dart';
import 'settings/profile_preferences.dart';
import 'theme.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  // The link the app was opened with, if it was opened with one: the OS puts
  // one in `defaultRouteName`, and go_router would otherwise take it as its
  // initial location and follow it before anybody had said who they were.
  // Only on a launch — that value stays there for the life of the process,
  // so a handover building this again must not read it a second time.
  final pending = ref.watch(isLaunchProvider)
      ? PendingLink(WidgetsBinding.instance.platformDispatcher.defaultRouteName)
      : PendingLink.none();
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  // The profiles themselves, and not only the session: forgetting the last
  // one but one turns the picker into the form, and nothing about the active
  // session moved.
  ref.listen(
    authProvider.select((auth) => auth.profiles.length),
    (_, _) => refresh.value++,
  );
  ref.onDispose(refresh.dispose);

  late final GoRouter router;

  /// Opens [link] on top of the app, once the app is there to open it on.
  ///
  /// Pushed rather than returned from the redirect, because what a redirect
  /// returns *replaces* the stack: a series with nothing under it draws no
  /// back arrow and the reader's own close button calls `maybePop`, which on
  /// a lone page does nothing at all — a link would open the app into a room
  /// with no door. So the app is built at its own first screen and the link
  /// arrives on top of it, exactly where a tap would have put it. A frame
  /// later, because this runs from inside the parse that is still deciding
  /// where the app is.
  void open(String? link) {
    if (link == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The container may have been handed to somebody else in the meantime,
      // and this router disposed with it.
      if (ref.mounted) router.push(link);
    });
  }

  router = GoRouter(
    // The platform's own initial location is deliberately not followed: it
    // is where a link arrives, and a link waits for a profile. `pending`
    // holds it instead, and `open` spends it once somebody is reading.
    initialLocation: '/',
    overridePlatformDefaultLocation: true,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final location = state.matchedLocation;
      final onGate = location == '/login' || location == profilesLocation;
      if (auth.active != null) {
        // Somebody is reading, so anything that was waiting on that can be
        // opened — whether the wait was a picker, a password, or no wait at
        // all on a device with one profile.
        open(pending.take());
        return onGate ? '/' : null;
      }

      // Signed out: the gate this device belongs at, unless it is already
      // there. `/login` counts as being there whatever the gate says — it is
      // where adding a profile and signing a refused one back in both
      // happen, and both are reached *from* the picker, so a device with
      // several profiles must not be bounced back to it.
      final gate = signedOutLocation(auth);
      if (location == '/login' || location == gate) return null;
      return gate;
    },
    routes: [
      GoRoute(
        path: profilesLocation,
        builder: (_, _) => const ProfilePickerScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, state) => LoginScreen(
          profileId: state.uri.queryParameters['profile'],
          expired: state.uri.queryParameters['expired'] == '1',
        ),
      ),

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
  // A container is thrown away when the app is handed to somebody else
  // (`SessionScope`), and the router goes with it: its navigator, its stack
  // and the route the previous person was on are all in here.
  ref.onDispose(router.dispose);
  return router;
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
      // Null is not "unset": it is what MaterialApp takes to mean "resolve
      // against the device", which is the setting's own default option.
      locale: ref.watch(localeProvider),
      theme: patraTheme(),
      darkTheme: patraTheme(),
      themeMode: ThemeMode.dark,
      routerConfig: ref.watch(_routerProvider),
      // The launch animation wraps the whole app rather than being a route of
      // its own: its last beat flies the frond into the home header, which has
      // to be laid out underneath while the splash is still playing.
      builder: (_, child) => LaunchAnimation(
        // A handover builds the whole app again, and that is not a launch.
        play: ref.watch(isLaunchProvider),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
