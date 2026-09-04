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
  bool magnify = false,
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
        initialMagnifyProvider.overrideWithValue(magnify),
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

  group('the magnify gesture', () {
    // The gesture's own rules are covered against the pure module in
    // `magnify_gesture_test.dart`. What can only be seen in the real tree is
    // what the mode costs and what it leaves alone: it takes the one-finger
    // drag away from the page turn, and it must give it back on the way out.

    /// A phone held upright, which is what this mode is for — and, less
    /// obviously, what keeps the pager's index equal to the page number: a
    /// test's default surface is landscape, where a spread puts two pages on
    /// every index and page 10 is index 5.
    void portrait(WidgetTester tester) {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    /// Which page the pager is on. Read from the controller rather than from
    /// a progress post, which is queued and would need the whole network
    /// round trip pumped through before it said anything.
    double? pagerAt(WidgetTester tester) =>
        tester.widget<PageView>(find.byType(PageView)).controller?.page;

    /// Magnifying is the only thing in this tree that scales a child up.
    Matrix4? magnified(WidgetTester tester) => tester
        .widgetList<Transform>(find.byType(Transform))
        .map((t) => t.transform)
        .where((m) => m.storage[0] > 1.0)
        .firstOrNull;

    testWidgets('a drag magnifies the page instead of turning it', (
      tester,
    ) async {
      portrait(tester);
      await _pumpReader(
        tester,
        initialPage: 10,
        direction: ReadingDirection.leftToRight,
        magnify: true,
      );
      expect(magnified(tester), isNull, reason: 'nothing pressed yet');
      expect(pagerAt(tester), 10);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await tester.pump();
      await gesture.moveBy(const Offset(-40, 160));
      await tester.pump();

      final matrix = magnified(tester);
      expect(matrix, isNotNull, reason: 'the drag should magnify');
      expect(matrix!.storage[0], greaterThan(1.0));
      expect(pagerAt(tester), 10, reason: 'and must not turn the page');

      await gesture.up();
      // The release animation, pumped out: this screen never settles, since
      // its page placeholders spin forever behind a server serving no images.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        magnified(tester),
        isNull,
        reason: 'letting go returns the whole page',
      );
      expect(pagerAt(tester), 10);
    });

    testWidgets('the side taps still turn pages while it is on', (
      tester,
    ) async {
      portrait(tester);
      await _pumpReader(
        tester,
        initialPage: 10,
        direction: ReadingDirection.leftToRight,
        magnify: true,
      );
      // Tapping is the only thing left that advances a page in this mode, so
      // it has to keep working or the mode strands the reader where they are.
      final size = tester.getSize(find.byType(PageView));
      await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(pagerAt(tester), 11);
    });

    testWidgets('the first side tap turns the page, with or without it', (
      tester,
    ) async {
      portrait(tester);
      await _pumpReader(
        tester,
        initialPage: 10,
        direction: ReadingDirection.leftToRight,
      );
      final size = tester.getSize(find.byType(PageView));
      await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // The *first* tap is the one that used to do nothing: the pager's idea
      // of where it was initialised itself out of the page it was being asked
      // to move to, so the guard saw no change. The second tap then skipped a
      // page. This mode makes tapping the only way through a chapter, so it
      // is pinned here rather than left to the swipe path that hid it.
      expect(pagerAt(tester), 11);
    });

    testWidgets('with it off, a drag turns the page as it always did', (
      tester,
    ) async {
      portrait(tester);
      await _pumpReader(
        tester,
        initialPage: 10,
        direction: ReadingDirection.leftToRight,
      );
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(pagerAt(tester), closeTo(11, 0.01));
      expect(magnified(tester), isNull);
    });

    testWidgets('vertical scrolling keeps its scroll', (tester) async {
      // The one direction the mode is refused: there the drag *is* how the
      // chapter advances, so taking it would leave no way through at all.
      await _pumpReader(
        tester,
        initialPage: 10,
        direction: ReadingDirection.verticalScroll,
        magnify: true,
      );
      expect(
        tester.widget<Scrollable>(find.byType(Scrollable).first).physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
      );
    });
  });


  group('the reader settings sheet', () {
    // One cog, not a pill per setting. The direction pill it replaced was a
    // menu opener rather than a toggle, so this costs no extra tap; what it
    // buys is room for a control that cannot be drawn as an icon.

    /// Brings the reader's chrome up, which is where the cog lives.
    Future<void> showChrome(WidgetTester tester) async {
      final size = tester.getSize(find.byType(PageView));
      await tester.tapAt(Offset(size.width / 2, size.height / 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('the cog opens both settings at once', (tester) async {
      await _pumpReader(
        tester,
        initialPage: 10,
        direction: ReadingDirection.leftToRight,
      );
      // Nothing in the bar until the reader is asked for its chrome.
      expect(find.byIcon(Icons.settings), findsNothing);

      await showChrome(tester);
      expect(find.byIcon(Icons.settings), findsOneWidget);

      await openSheet(tester);
      expect(find.text('READING DIRECTION'), findsOneWidget);
      expect(find.text('Left to right'), findsOneWidget);
      expect(find.text('Right to left'), findsOneWidget);
      expect(find.text('Vertical'), findsOneWidget);
      expect(find.text('Drag to magnify'), findsOneWidget);
    });

    testWidgets('flipping the switch leaves the sheet open', (tester) async {
      // A direction row closes the sheet because picking one is the whole
      // errand. A switch must not: closing the surface it lives on would
      // leave no way to turn it back off without reopening it.
      mockSecureStorage();
      await _pumpReader(
        tester,
        initialPage: 10,
        direction: ReadingDirection.leftToRight,
      );
      await showChrome(tester);
      await openSheet(tester);

      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('Drag to magnify'), findsOneWidget,
          reason: 'the sheet should still be open');
    });

    testWidgets('turning magnifying on takes effect without leaving the '
        'chapter', (tester) async {
      mockSecureStorage();
      await _pumpReader(
        tester,
        initialPage: 10,
        direction: ReadingDirection.leftToRight,
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
      );

      await showChrome(tester);
      await openSheet(tester);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Close the sheet and let the reader rebuild.
      Navigator.of(tester.element(find.byType(Switch))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
        reason: 'the swipe should have been handed to the gesture',
      );
    });

    testWidgets('it says so when the gesture cannot apply', (tester) async {
      // Reading vertically the drag is the scroll, so magnifying is inert
      // there. The switch stays usable — the preference is global and the
      // next chapter may well be paged — but a switch reading "on" while
      // doing nothing, with nothing saying why, is the worst of both.
      await _pumpReader(
        tester,
        initialPage: 10,
        direction: ReadingDirection.verticalScroll,
        magnify: true,
      );
      final size = tester.getSize(find.byType(Scaffold));
      await tester.tapAt(Offset(size.width / 2, size.height / 2));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await openSheet(tester);

      expect(find.text('Drag to magnify'), findsOneWidget);
      expect(
        find.textContaining('Not while reading vertically'),
        findsOneWidget,
      );
      // Still switchable, for the next chapter that is paged.
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
    });

    testWidgets('picking a direction closes the sheet and applies it', (
      tester,
    ) async {
      await _pumpReader(
        tester,
        initialPage: 10,
        direction: ReadingDirection.leftToRight,
      );
      await showChrome(tester);
      await openSheet(tester);

      await tester.tap(find.text('Right to left'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Drag to magnify'), findsNothing,
          reason: 'the sheet should have closed');
      // The direction is per-chapter here, and the pager mirrors with it.
      expect(tester.widget<PageView>(find.byType(PageView)).reverse, isTrue);
    });
  });

}
