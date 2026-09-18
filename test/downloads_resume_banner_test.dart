import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/downloads/resume_banner.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

/// A server that answers every page request, and counts them: what the
/// question must not do is fetch anything, so the count is the whole of the
/// assertion.
class _PageServer implements HttpClientAdapter {
  final requested = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(int.parse('${options.queryParameters['page']}'));
    return ResponseBody.fromBytes(
      List<int>.filled(4, 9),
      200,
      headers: {
        Headers.contentTypeHeader: ['image/jpeg'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

SavedChapter _chapter(int id) => SavedChapter(
  chapterId: id,
  seriesId: 3,
  volumeId: 1,
  libraryId: 2,
  seriesName: 'Akira',
  title: 'Volume $id',
  pages: 3,
  bytes: 0,
);

const _profileId = 'https://kavita.test#1';

/// What a previous run left behind: copies the app was closed in the middle
/// of, written down the way the queue writes them.
Future<Directory> _interruptedRoom(List<int> chapterIds) async {
  final root = Directory.systemTemp.createTempSync('patra-resume-prompt');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  await DownloadsService(root: root, profileId: _profileId).writeQueue({
    for (final id in chapterIds)
      id: DownloadQueueRecord(
        request: _chapter(id),
        status: DownloadQueueStatus.paused,
        priority: id,
      ),
  });
  return root;
}

/// The strip, around an app that draws nothing of its own: what is under test
/// is the question, not the shell it is mounted above.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  Directory root,
  _PageServer server,
) async {
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'the-api-key',
  );
  client.httpClient.httpClientAdapter = server;
  client.bareHttpClient.httpClientAdapter = server;
  final container = ProviderContainer(
    overrides: [
      kavitaClientProvider.overrideWithValue(client),
      downloadsServiceProvider.overrideWithValue(
        DownloadsService(root: root, profileId: _profileId),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DownloadsResumeBanner(child: Scaffold(body: SizedBox())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('a launch asks before it fetches anything, and names how many', (
    tester,
  ) async {
    final root = await _interruptedRoom([12, 13]);
    final server = _PageServer();
    final container = await _pump(tester, root, server);

    // A strip across the app rather than a dialog in the middle of it: the
    // sentence, and two worded answers, over a screen the reader can go on
    // using.
    expect(
      find.text('2 downloads stopped when the app closed.'),
      findsOneWidget,
    );
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(server.requested, isEmpty, reason: 'nothing before the answer');

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialBanner), findsNothing);
    await pumpUntil(
      tester,
      () => container.read(downloadsProvider).value?.saved.length == 2,
    );

    expect(server.requested, [0, 1, 2, 0, 1, 2]);
    expect(
      container.read(downloadsProvider).value!.saved.keys,
      containsAll([12, 13]),
    );
  });

  testWidgets('“not now” leaves the copies stopped and fetches nothing', (
    tester,
  ) async {
    final root = await _interruptedRoom([12]);
    final server = _PageServer();
    final container = await _pump(tester, root, server);

    // One copy, so the sentence is the singular one.
    expect(
      find.text('One download stopped when the app closed.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialBanner), findsNothing);
    await pumpUntil(
      tester,
      () =>
          container.read(downloadsProvider).value?.interrupted.contains(12) ??
          false,
    );

    expect(server.requested, isEmpty);
    final state = container.read(downloadsProvider).value!;
    expect(state.awaitingResume, isEmpty);
    expect(state.interrupted, contains(12));
  });
}
