import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verso/l10n/generated/app_localizations.dart';
import 'package:verso/src/api/kavita_client.dart';
import 'package:verso/src/auth/session.dart';
import 'package:verso/src/downloads/downloads_provider.dart';
import 'package:verso/src/downloads/downloads_service.dart';
import 'package:verso/src/features/reader/reader_screen.dart';
import 'package:verso/src/settings/reading_settings.dart';
import 'package:verso/src/theme.dart';

import 'test_support.dart';

const _pages = 50;

class _ReaderAdapter implements HttpClientAdapter {
  _ReaderAdapter(this.posted);

  /// Every progress post, in the order the reader made them.
  final List<int> posted;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    if (options.path == '/api/Reader/progress') {
      posted.add((options.data as Map<String, dynamic>)['pageNum'] as int);
      return ResponseBody.fromString('{}', 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });
    }
    if (options.path == '/api/Reader/chapter-info') {
      return ResponseBody.fromString(
        jsonEncode({
          'seriesId': 3,
          'volumeId': 4,
          'libraryId': 1,
          'pages': _pages,
          'seriesName': 'Berserk',
          'title': 'Chapter 1',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    // Pages themselves are not the subject here.
    return ResponseBody.fromBytes(const [], 404);
  }

  @override
  void close({bool force = false}) {}
}

/// A chapter already on disk, as `DownloadsService.scan()` expects to find it:
/// page files plus the `meta.json` that makes the directory complete.
void _writeSavedChapter(Directory root, {required int pagesRead}) {
  final dir = Directory('${root.path}/7')..createSync(recursive: true);
  for (var page = 0; page < 3; page++) {
    File('${dir.path}/${DownloadsService.pageFileName(page)}')
        .writeAsBytesSync(const [0]);
  }
  File('${dir.path}/meta.json').writeAsStringSync(
    jsonEncode({
      'chapterId': 7,
      'seriesId': 3,
      'volumeId': 4,
      'libraryId': 1,
      'seriesName': 'Berserk',
      'title': 'Chapter 1',
      'pages': _pages,
      'bytes': 3,
      'pagesRead': pagesRead,
    }),
  );
}

Future<List<int>> _pumpReader(
  WidgetTester tester, {
  required int initialPage,
  ReadingDirection direction = ReadingDirection.webtoon,
  int? savedPagesRead,
}) async {
  final dir = mockPathProvider();
  final downloads = Directory('${dir.path}/downloads')..createSync();
  if (savedPagesRead != null) {
    _writeSavedChapter(downloads, pagesRead: savedPagesRead);
  }

  final posted = <int>[];
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    refreshToken: 'refresh',
    apiKey: 'key',
  );
  final adapter = _ReaderAdapter(posted);
  client.httpClient.httpClientAdapter = adapter;
  client.refreshHttpClient.httpClientAdapter = adapter;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(
          DownloadsService(root: downloads),
        ),
        initialReadingDirectionProvider.overrideWithValue(direction),
      ],
      child: MaterialApp(
        theme: versoTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReaderScreen(chapterId: 7, initialPage: initialPage),
      ),
    ),
  );
  // Not pumpAndSettle: the page placeholders spin forever behind a server
  // that serves no images, which is not what these tests are about.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  return posted;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the webtoon opens where the chapter was left, not at page 0', (
    tester,
  ) async {
    final posted = await _pumpReader(tester, initialPage: 20);
    expect(posted, [20], reason: 'the page it opened at is saved on open');

    // The strip starts at offset 0 until it is placed. A scroll before that
    // reports page 0 and posts it back, wiping the reader's place.
    await tester.drag(find.byType(ListView), const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 300));

    expect(posted, isNot(contains(0)));
  });

  testWidgets('a paged chapter opens where it was left too', (tester) async {
    final posted = await _pumpReader(
      tester,
      initialPage: 20,
      direction: ReadingDirection.leftToRight,
    );

    expect(posted, [20]);
  });

  testWidgets('opening a saved chapter elsewhere does not write in build', (
    tester,
  ) async {
    // Saving mirrors progress into the stored copy, which is a provider:
    // reaching it from build is what Riverpod refuses outright.
    final posted = await _pumpReader(
      tester,
      initialPage: 20,
      savedPagesRead: 5,
    );

    expect(tester.takeException(), isNull);
    expect(posted, [20]);
  });
}
