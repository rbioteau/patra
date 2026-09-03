import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/reader/reader_screen.dart';
import 'package:patra/src/settings/reading_settings.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

const _pages = 50;

class _ReaderAdapter implements HttpClientAdapter {
  _ReaderAdapter(this.posted, {this.wide = const {}});

  /// Every progress post, in the order the reader made them.
  final List<int> posted;

  /// Pages the server reports as double-page scans.
  final Set<int> wide;

  @override
  Future<ResponseBody> fetch(RequestOptions options, _, _) async {
    if (options.path == '/api/Reader/progress') {
      posted.add((options.data as Map<String, dynamic>)['pageNum'] as int);
      return ResponseBody.fromString(
        '{}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
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
          'pageDimensions': [
            for (var page = 0; page < _pages; page++)
              {
                'pageNumber': page,
                'width': wide.contains(page) ? 1600 : 800,
                'height': 1200,
                'isWide': wide.contains(page),
              },
          ],
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
  ReadingDirection direction = ReadingDirection.verticalScroll,
  int? savedPagesRead,
  SliderComponentShape? sliderThumb,
  Set<int> wide = const {},
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
  final adapter = _ReaderAdapter(posted, wide: wide);
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
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: sliderThumb == null
            ? ReaderScreen(chapterId: 7, initialPage: initialPage)
            : SliderTheme(
                data: SliderThemeData(thumbShape: sliderThumb),
                child: ReaderScreen(chapterId: 7, initialPage: initialPage),
              ),
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

/// Reports where the slider actually paints its handle, which nothing else in
/// a widget test can see.
class _ProbeThumb extends SliderComponentShape {
  _ProbeThumb(this.centres);

  /// The handle's centre, in global coordinates, once per paint.
  final List<double> centres;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(20, 20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    centres.add(center.dx + parentBox.localToGlobal(Offset.zero).dx);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('vertical scrolling opens where the chapter was left, not at page 0', (
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

  testWidgets('a double-page scan is read alone, not paired', (tester) async {
    // Landscape: an iPad on its side.
    tester.view.physicalSize = const Size(2360, 1640);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await _pumpReader(
      tester,
      initialPage: 0,
      direction: ReadingDirection.leftToRight,
      wide: {2},
    );

    // The counter in the chrome says what shares the screen.
    Future<void> showChrome() async {
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    final size = tester.getSize(find.byType(PageView));
    Future<void> stepForward() async {
      await tester.tapAt(Offset(size.width * .85, size.height / 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    // The two pages of a pair meet on the centre line rather than each
    // sitting in the middle of its own half, which would join them with a
    // gutter that widens with the screen.
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .map((i) => i.alignment)
          .toSet(),
      {Alignment.centerRight, Alignment.centerLeft},
    );

    await showChrome();
    expect(find.text('1–2 / $_pages'), findsOneWidget);

    await stepForward();
    expect(
      find.text('3 / $_pages'),
      findsOneWidget,
      reason: 'the wide page has the screen to itself',
    );

    // And the pairing picks up after it, on the other parity: a fixed
    // `page ~/ 2` would have put 2 with 3 and split the spread in half.
    await stepForward();
    expect(find.text('4–5 / $_pages'), findsOneWidget);

    // Back over the wide page, onto the *first* page of the pair before it.
    await tester.tapAt(Offset(size.width * .15, size.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('3 / $_pages'), findsOneWidget);
  });

  testWidgets('the slider handle sits under the swollen thumbnail', (
    tester,
  ) async {
    // The chrome's two "you are here" markers sit one above the other, so they
    // have to agree at the ends as well as in the middle — and the strip's end
    // centres move whenever the thumbnails change size, which is what makes
    // the slider's padding a computation rather than a number.
    final centres = <double>[];
    await _pumpReader(
      tester,
      initialPage: 0,
      direction: ReadingDirection.leftToRight,
      sliderThumb: _ProbeThumb(centres),
    );
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    // Not pumpAndSettle: the page behind the chrome spins forever against a
    // server that serves no images. This is long enough for the strip to have
    // placed itself and the accordion to have opened.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(centres, isNotEmpty, reason: 'the slider never painted its handle');
    expect(
      centres.last,
      moreOrLessEquals(
        tester.getCenter(find.byKey(const ValueKey(0))).dx,
        epsilon: 1,
      ),
    );
  });

  testWidgets('the system bars come and go with the reader\'s own chrome', (
    tester,
  ) async {
    // Every fullscreen mode hides the status bar and the home indicator on
    // iOS; `edgeToEdge` is the app's normal state everywhere else.
    final modes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pumpReader(
      tester,
      initialPage: 0,
      direction: ReadingDirection.leftToRight,
    );
    expect(modes.last, 'SystemUiMode.immersiveSticky');

    // The middle third of the screen toggles the chrome; the clock is one tap
    // away rather than gone for the length of the chapter.
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump();
    expect(modes.last, 'SystemUiMode.edgeToEdge');

    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump();
    expect(modes.last, 'SystemUiMode.immersiveSticky');

    // Leaving the chapter hands the bars back.
    await tester.pumpWidget(const SizedBox());
    expect(modes.last, 'SystemUiMode.edgeToEdge');
  });
}
