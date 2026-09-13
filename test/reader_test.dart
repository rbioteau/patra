import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/auth/session.dart';
import 'package:patra/src/downloads/downloads_provider.dart';
import 'package:patra/src/downloads/downloads_service.dart';
import 'package:patra/src/features/reader/reader_screen.dart';
import 'package:patra/src/features/reader/page_rail.dart';
import 'package:patra/src/features/reader/strip_geometry.dart';
import 'package:patra/src/features/reader/thumb_strip.dart';
import 'package:patra/src/settings/profile_preferences.dart';
import 'package:patra/src/settings/reading_settings.dart';
import 'package:patra/src/theme.dart';

import 'test_support.dart';

const _pages = 50;

class _ReaderAdapter implements HttpClientAdapter {
  _ReaderAdapter(
    this.posted, {
    this.wide = const {},
    this.pages = _pages,
    this.dimensions = true,
    this.offline = false,
  });

  /// Every progress post, in the order the reader made them.
  final List<int> posted;

  /// Pages the server reports as double-page scans.
  final Set<int> wide;

  /// How long the chapter is.
  final int pages;

  /// Whether the server measured the pages at all. A server that has not
  /// crawled a chapter yet answers with no dimensions, and so does no server
  /// at all.
  final bool dimensions;

  /// Nothing answers: the reader is on its own, with what the device kept.
  final bool offline;

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
    // Nothing answers but the reader itself, which is what it is like to
    // open a chapter with no server: the stored copy is all there is.
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    if (options.path == '/api/Reader/chapter-info') {
      return ResponseBody.fromString(
        jsonEncode({
          'seriesId': 3,
          'volumeId': 4,
          'libraryId': 1,
          'pages': pages,
          'seriesName': 'Berserk',
          'title': 'Chapter 1',
          if (dimensions)
            'pageDimensions': [
              for (var page = 0; page < pages; page++)
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
///
/// Written through the service so it lands under the profile that saved it —
/// a copy put straight in the downloads root is what the previous layout
/// wrote, and the scan deletes those rather than listing them.
Future<void> _writeSavedChapter(
  DownloadsService service, {
  required int pagesRead,
  int pages = _pages,
}) async {
  final dir = (await service.chapterDir(7))..createSync(recursive: true);
  for (var page = 0; page < 3 && page < pages; page++) {
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
      'pages': pages,
      'bytes': 3,
      'pagesRead': pagesRead,
    }),
  );
}

/// Somebody reading, so that a preference set in the reader has an owner to
/// be kept for. Every other test here reads the device's defaults, which is
/// what a profile that has never chosen gets.
final _reader = Profile(
  baseUrl: 'http://kavita.test',
  accountId: 1,
  username: 'romain',
  apiKey: 'key',
  token: signedToken(1),
);

Future<List<int>> _pumpReader(
  WidgetTester tester, {
  required int initialPage,
  ReadingDirection direction = ReadingDirection.verticalScroll,
  bool magnify = false,
  double widthFactor = 1.0,
  int? savedPagesRead,
  SliderComponentShape? sliderThumb,
  Set<int> wide = const {},
  Profile? profile,
  ProfilePreferencesStore? store,
  Key? readerKey,
  int pages = _pages,
  bool dimensions = true,
  bool offline = false,
}) async {
  final dir = mockPathProvider();
  final downloads = DownloadsService(
    root: Directory('${dir.path}/downloads')..createSync(),
    profileId: 'https://kavita.test#1',
  );
  if (savedPagesRead != null) {
    await _writeSavedChapter(
      downloads,
      pagesRead: savedPagesRead,
      pages: pages,
    );
  }

  final posted = <int>[];
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    username: 'romain',
    apiKey: 'key',
  );
  final adapter = _ReaderAdapter(
    posted,
    wide: wide,
    pages: pages,
    dimensions: dimensions,
    offline: offline,
  );
  client.httpClient.httpClientAdapter = adapter;
  client.bareHttpClient.httpClientAdapter = adapter;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        testKeychain(),
        kavitaClientProvider.overrideWithValue(client),
        downloadsServiceProvider.overrideWithValue(downloads),
        if (profile != null)
          initialAuthStateProvider.overrideWithValue(
            AuthState(profiles: [profile], activeId: profile.id),
          ),
        // No session unless [profile] says otherwise, so these are the
        // device's own defaults — which is what a profile that has never
        // chosen reads in.
        profilePreferencesStoreProvider.overrideWithValue(
          store ??
              ProfilePreferencesStore(
                keychain: MemoryKeychain(),
                deviceDirection: direction,
                deviceMagnify: magnify,
                deviceWidthFactor: widthFactor,
              ),
        ),
      ],
      child: MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: sliderThumb == null
            ? ReaderScreen(key: readerKey, chapterId: 7, initialPage: initialPage)
            : SliderTheme(
                data: SliderThemeData(thumbShape: sliderThumb),
                child: ReaderScreen(
                  key: readerKey,
                  chapterId: 7,
                  initialPage: initialPage,
                ),
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

/// The reader's chrome — a tap in the middle, which in vertical scrolling is
/// the whole screen and when paging is the middle zone — and then the cog's
/// sheet, where the width a chapter opens at is set.
Future<void> _showChromeAndCog(WidgetTester tester) async {
  final size = tester.getSize(find.byType(Scaffold));
  await tester.tapAt(Offset(size.width / 2, size.height / 2));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byIcon(Icons.settings));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The width a chapter opens at, in the cog's sheet. The chrome has a slider
/// of its own, for pages, so the two are told apart by what they slide over.
Finder get _widthSlider => find.byWidgetPredicate(
  (widget) => widget is Slider && widget.max == StripGeometry.maxWidthFactor,
);

/// Drags the width slider to its left end: the narrowest a strip is laid
/// out, and the furthest a chapter can be from the width it opens at today.
Future<void> _narrowStrip(WidgetTester tester) async {
  // Three rows of settings do not fit the part of a short screen a sheet is
  // given, so the sheet scrolls and the row is brought into view first.
  await tester.ensureVisible(_widthSlider);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.drag(_widthSlider, const Offset(-2000, 0));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Where the strip is scrolled to, which is the only thing in a widget test
/// that says what a chapter is actually showing.
double _stripOffset(WidgetTester tester) => tester
    .widget<CustomScrollView>(find.byType(CustomScrollView))
    .controller!
    .offset;

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

  testWidgets(
    'vertical scrolling opens where the chapter was left, not at page 0',
    (tester) async {
      final posted = await _pumpReader(tester, initialPage: 20);
      expect(posted, [20], reason: 'the page it opened at is saved on open');

      // The strip starts at offset 0 until it is placed. A scroll before that
      // reports page 0 and posts it back, wiping the reader's place.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 300));

      expect(posted, isNot(contains(0)));
    },
  );

  testWidgets('the strip asks the decoder for the width it draws at', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await _pumpReader(tester, initialPage: 0);

    // A chapter opens at the whole screen, so what the decoder is asked for
    // is the screen, in device pixels — the same width for every page, and
    // not the size the files happen to be. Narrowing the strip changes it,
    // and with it the memory a page costs to decode.
    final asked = {
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        (image.image as ResizeImage).width,
    };
    expect(asked, {tester.view.physicalSize.width.round()});
  });

  testWidgets('a chapter opens at the width that was chosen', (tester) async {
    // The same measurement as above, at the narrow end of the range: the
    // width a page is decoded at is the width the strip is laid out at.
    final posted = await _pumpReader(
      tester,
      initialPage: 20,
      widthFactor: StripGeometry.minWidthFactor,
    );

    final asked = {
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        (image.image as ResizeImage).width,
    };
    expect(asked, {
      (tester.view.physicalSize.width * StripGeometry.minWidthFactor).ceil(),
    });
    expect(posted, [
      20,
    ], reason: 'the page it was left at is still the page it opened at');
  });

  testWidgets('a width chosen in the reader does not move the reader’s place', (
    tester,
  ) async {
    // Every height changes when the width does, so the offset the strip sat
    // at is a different page afterwards. Nothing scrolls, so nothing is
    // reported: the strip would simply be showing page 40 to somebody the
    // reader still believes is on page 20, and the next flick would post
    // that page back as progress.
    final posted = await _pumpReader(tester, initialPage: 20);
    expect(posted, [20]);
    final before = _stripOffset(tester);

    await _showChromeAndCog(tester);
    await _narrowStrip(tester);

    expect(tester.widget<Slider>(_widthSlider).value, 0.5);
    expect(
      _stripOffset(tester),
      closeTo(before * StripGeometry.minWidthFactor, 1),
      reason:
          'the strip was re-anchored on the page it was on, not left to '
          'drift down the chapter',
    );
    expect(posted, [20], reason: 'a width is not the reader moving');
  });

  testWidgets('a width chosen in the reader is the profile’s, and outlives '
      'the chapter', (tester) async {
    final keychain = MemoryKeychain();
    // Vertical, like the reader's own tests: the store carries the device's
    // default, and a store handed in brings its own.
    final store = ProfilePreferencesStore(
      keychain: keychain,
      deviceDirection: ReadingDirection.verticalScroll,
    );
    await _pumpReader(tester, initialPage: 0, profile: _reader, store: store);

    await _showChromeAndCog(tester);
    await _narrowStrip(tester);

    expect(store.widthFactorFor(_reader.id), 0.5);
    expect(keychain.values['profilePreferences'], contains('0.5'));
    // Written once, at the end of the gesture, and not once per step of it:
    // a drag is dozens of values and the keychain hears about the choice.
    expect(keychain.writes, 1);

    // Leaving the chapter and the app: a device restarted reads it back off
    // the keychain, and the next chapter opens at it — at the page it is
    // opened at, which is the whole of what a narrower strip must not cost.
    final reopened = await preferencesStore(
      keychain: MemoryKeychain({...keychain.values}),
      deviceDirection: ReadingDirection.verticalScroll,
    );
    expect(reopened.widthFactorFor(_reader.id), 0.5);

    // A key of its own, so this is a chapter being *opened* and not the
    // reader's state carried over: `pumpWidget` hands the new tree the old
    // element when the shapes match, and a reopened chapter has to save its
    // own place from scratch.
    final posted = await _pumpReader(
      tester,
      initialPage: 40,
      profile: _reader,
      store: reopened,
      readerKey: const ValueKey('reopened'),
    );
    final asked = {
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        (image.image as ResizeImage).width,
    };
    expect(
      asked,
      {(tester.view.physicalSize.width * StripGeometry.minWidthFactor).ceil()},
      reason: 'the chapter opens at the width that was chosen',
    );
    expect(posted, [40], reason: 'and at the page it was left at');
  });

  testWidgets('a width change at the end of a chapter clamps, and keeps the '
      'last page', (tester) async {
    // At a document edge the anchor cannot be held — there is no content left
    // below to put under it — so the strip clamps, which is what ADR-0006
    // says of the pinch. What it must not do is overscroll or lose the page.
    final posted = await _pumpReader(tester, initialPage: _pages - 1);
    await _showChromeAndCog(tester);
    await _narrowStrip(tester);

    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(tester.takeException(), isNull);
    expect(posted, [_pages], reason: 'the last page still reports the total');
  });

  testWidgets('turning the device keeps the page, and the place within it', (
    tester,
  ) async {
    // Every height follows the canvas, so the offset the strip is sitting at
    // is a different page the moment the screen is turned — and nothing
    // scrolls, so nothing is reported. At a width other than full, which is
    // the whole of the feature.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final posted = await _pumpReader(
      tester,
      initialPage: 20,
      widthFactor: 0.7,
    );
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final before = controller.offset;

    tester.view.physicalSize = const Size(2532, 1170);
    await tester.pump();
    await tester.pump();

    // The strip is anchored on the top of page 20, and every height is
    // proportional to the width it is laid out at — so the offset it lands
    // on is the same place, scaled by what the canvas became: 844/390.
    expect(controller.offset, closeTo(before * 844 / 390, 1));
    expect(posted, [20], reason: 'a rotation is not the reader moving');
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning the device with the chrome open keeps the place too', (
    tester,
  ) async {
    // The scrubber is on screen while the canvas is turned, which is the case
    // #46 asks the lifecycle to cover: the strip is not the only thing being
    // laid out at the new width, and this screen has died on a layout that
    // rebuilt under it before.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final posted = await _pumpReader(tester, initialPage: 20);
    final screen = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(screen.width / 2, screen.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The rail is the vertical chrome's seek control, built with it and
    // hidden with it (#52) — the strip and the slider are paged's now.
    expect(find.byType(PageRail), findsOneWidget);

    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final before = controller.offset;

    tester.view.physicalSize = const Size(2532, 1170);
    await tester.pump();
    await tester.pump();

    expect(controller.offset, closeTo(before * 844 / 390, 1));
    expect(find.byType(PageRail), findsOneWidget, reason: 'the chrome stays');
    expect(posted, [20]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vertical reading shows the rail', (tester) async {
    // The rail replaces the thumbnail strip and its slider: the seek control
    // runs along the axis the chapter is scrolled on (#52), and the vertical
    // chrome carries that one and no other.
    await _pumpReader(tester, initialPage: 0);
    final screen = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(screen.width / 2, screen.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PageRail), findsOneWidget);
    expect(find.byType(ThumbStrip), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paged reading keeps the strip and the slider', (tester) async {
    // The rail is vertical reading's; this work leaves paged alone (#46) —
    // the paged chrome keeps the chrome it has, strip and slider together.
    await _pumpReader(
      tester,
      initialPage: 0,
      direction: ReadingDirection.leftToRight,
    );
    final screen = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(screen.width / 2, screen.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ThumbStrip), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(PageRail), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rail\'s handle sits where the fraction of the chapter '
      'above it ends', (tester) async {
    // Height is what the rail is honest about: every page takes the share of
    // the rail its height has of the chapter, and where the handle sits is
    // where the reader actually is. At the top of page 10, with every page
    // as tall as the next, the handle is a fifth of the way down the rail;
    // at the top of the first page it is at the very top of it.
    await _pumpReader(tester, initialPage: 10);
    final screen = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(screen.width / 2, screen.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final rail = tester.getRect(find.byType(PageRail));
    // The rail runs between the chrome bars: 72pt under the top bar and 62pt
    // above the bottom counter, whatever the device's safe area says.
    expect(rail.height, moreOrLessEquals(600 - 72 - 62, epsilon: 0.5));
    // 10 of 50 pages, each 1200 of a 60000-point chapter.
    expect(
      tester.getCenter(find.byKey(const ValueKey('pageRailHandle'))).dy,
      moreOrLessEquals(rail.top + rail.height * 10 / 50, epsilon: 1.5),
    );

    // Reopened at the start of the chapter, where the fraction above the
    // handle is nothing.
    await _pumpReader(
      tester,
      initialPage: 0,
      readerKey: const ValueKey('opened-top'),
    );
    final restarted = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(restarted.width / 2, restarted.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester.getCenter(find.byKey(const ValueKey('pageRailHandle'))).dy,
      moreOrLessEquals(rail.top, epsilon: 1.5),
      reason:
          'the handle sits at the top of the rail at the top of the chapter',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the rail lands on the page asked for, first and last', (
    tester,
  ) async {
    final posted = await _pumpReader(tester, initialPage: 20);
    final screen = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(screen.width / 2, screen.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final rail = tester.getRect(find.byType(PageRail));
    final x = rail.center.dx;
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;

    // To the bottom of the rail: the far end of the chapter, which is the
    // top of its last page — 49 pages of 1200 each.
    final finger = await tester.startGesture(Offset(x, rail.top + 4));
    await tester.pump();
    await finger.moveTo(Offset(x, rail.bottom - 2));
    await tester.pump();
    await finger.up();
    await tester.pump();
    // The last seek posted progress; the request needs a clock to land in
    // the adapter's list, so let it drain before reading the list.
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      controller.offset,
      moreOrLessEquals(49 * 1200, epsilon: 1),
      reason: 'the strip landed on the top of the last page',
    );
    // The last page reports the total, which is how a chapter reads as read.
    expect(posted, contains(50));

    // And to the top: the first page, offset zero. The seek is a seek
    // whichever way it runs.
    final finger2 = await tester.startGesture(Offset(x, rail.bottom - 2));
    await tester.pump();
    await finger2.moveTo(Offset(x, rail.top + 2));
    await tester.pump();
    await finger2.up();
    await tester.pump();

    expect(controller.offset, moreOrLessEquals(0, epsilon: 0.5));
    expect(posted, contains(0));
    // The seek posted progress; let the request drain before the end of the
    // test, which is when the binding checks for pending timers.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the rail shows its page number while dragged and never '
      'otherwise', (tester) async {
    await _pumpReader(tester, initialPage: 0);
    final screen = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(screen.width / 2, screen.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('1'),
      findsNothing,
      reason: 'no number on the rail while nobody touches it',
    );

    final rail = tester.getRect(find.byType(PageRail));
    final finger = await tester.startGesture(
      Offset(rail.center.dx, rail.top + 4),
    );
    await tester.pump();
    // Halfway down the chapter: the address the seek would land on.
    await finger.moveTo(
      Offset(rail.center.dx, rail.top + rail.height / 2),
    );
    await tester.pump();
    expect(
      find.text('26'),
      findsOneWidget,
      reason: 'the number is up while the finger is down',
    );

    await finger.up();
    await tester.pump();
    expect(find.text('26'), findsNothing, reason: 'and gone with it');
    // The seek posted progress; let the request drain before the end of the
    // test, which is when the binding checks for pending timers.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chapter of one page draws nothing to seek with', (tester) async {
    // A lone thumbnail over a slider with one position is furniture that
    // cannot be used. Where there is nowhere to seek to, the reader draws
    // the counter and nothing else.
    final posted = await _pumpReader(tester, initialPage: 0, pages: 1);

    // The chrome: in vertical scrolling a tap anywhere brings it up.
    final screen = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(screen.width / 2, screen.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ThumbStrip), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(PageRail), findsNothing, reason: 'nowhere to seek to');
    expect(find.text('1 / 1'), findsOneWidget);
    expect(posted, [1], reason: 'the one page is the last page too');
    expect(tester.takeException(), isNull);
  });

  testWidgets('paging keeps the chrome it has for a chapter of one page', (
    tester,
  ) async {
    // The rule above is the vertical strip's, where the thumbnail strip is the
    // seek control. Paged reading is left as it was (#46).
    await _pumpReader(
      tester,
      initialPage: 0,
      pages: 1,
      direction: ReadingDirection.leftToRight,
    );
    final screen = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(screen.width / 2, screen.height / 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ThumbStrip), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chapter the server measured nothing about still lays out', (
    tester,
  ) async {
    // A server that has not crawled a chapter answers with no dimensions, so
    // every page shares the default ratio: a portrait comic page, half as
    // wide again as it is tall.
    final posted = await _pumpReader(
      tester,
      initialPage: _pages - 1,
      dimensions: false,
    );
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final screen = tester.getSize(find.byType(Scaffold));

    // The whole strip, less the screen it is seen through: exact, which is
    // what makes the last page reachable rather than a guess away.
    expect(
      controller.position.maxScrollExtent,
      moreOrLessEquals(
        _pages * screen.width / PageDimension.defaultAspectRatio -
            screen.height,
        epsilon: 1,
      ),
    );
    // And the end of the chapter is there to be reached: not an extent
    // guessed at an average page and short of the truth.
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(
      controller.offset,
      moreOrLessEquals(controller.position.maxScrollExtent, epsilon: 0.5),
    );
    expect(posted, [_pages]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved chapter reads the same with no server to ask', (
    tester,
  ) async {
    // Offline is not a lesser reader. What the device kept has no dimensions
    // in it either, so this is the same strip as above, read from the stored
    // copy, and it must answer to the width the same way.
    final posted = await _pumpReader(
      tester,
      initialPage: 40,
      savedPagesRead: 5,
      offline: true,
    );
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final screen = tester.getSize(find.byType(Scaffold));
    final before = controller.offset;

    expect(
      controller.position.maxScrollExtent,
      moreOrLessEquals(
        _pages * screen.width / PageDimension.defaultAspectRatio -
            screen.height,
        epsilon: 1,
      ),
      reason: 'the stored page count is the strip, to its last page',
    );

    await _showChromeAndCog(tester);
    await _narrowStrip(tester);

    // Half the width, and the same page: every height halved with it, so the
    // offset is half of what it was.
    expect(controller.offset, closeTo(before * 0.5, 1));
    expect(posted, [40], reason: 'a width is not the reader moving');
    expect(tester.takeException(), isNull);
  });

  testWidgets('reading a chapter writes no width back', (tester) async {
    // The width a chapter opens at is the one thing the reading path must
    // never touch. #50 lets a pinch narrow the strip for the chapter in hand,
    // and a pinch is a live adjustment on top of the preference: it writes
    // nothing. So does a scroll, for the same reason.
    final keychain = MemoryKeychain();
    final store = ProfilePreferencesStore(
      keychain: keychain,
      deviceDirection: ReadingDirection.verticalScroll,
    );
    await _pumpReader(tester, initialPage: 20, profile: _reader, store: store);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 300));

    expect(keychain.writes, 0);
    expect(store.widthFactorFor(_reader.id), 1.0);
  });

  testWidgets('a pinch narrows the strip, and writes nothing', (tester) async {
    // Two fingers change the width a chapter is read at, for the chapter in
    // hand and nothing else: the width a chapter *opens* at is a preference
    // and a pinch is a live adjustment on top of it (#50).
    final keychain = MemoryKeychain();
    final store = ProfilePreferencesStore(
      keychain: keychain,
      deviceDirection: ReadingDirection.verticalScroll,
    );
    final posted = await _pumpReader(
      tester,
      initialPage: 20,
      profile: _reader,
      store: store,
    );
    final controller = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    final screen = tester.getSize(find.byType(Scaffold));
    final whole = controller.position.maxScrollExtent;

    // Two fingers half as far apart: half the width, and the whole strip half
    // as long with it.
    const y = 270.0;
    final a = await tester.startGesture(Offset(screen.width / 2 - 60, y));
    final b = await tester.startGesture(Offset(screen.width / 2 + 60, y));
    await tester.pump();
    for (var step = 1; step <= 16; step++) {
      final span = 120 - 60 * step / 16;
      await a.moveTo(Offset(screen.width / 2 - span / 2, y));
      await b.moveTo(Offset(screen.width / 2 + span / 2, y));
      await tester.pump();
    }
    expect(
      controller.position.maxScrollExtent,
      moreOrLessEquals((whole + screen.height) * 0.5 - screen.height, epsilon: 1),
      reason: 'the strip is laid out at half the width',
    );

    // Nothing written, and nothing read: the width a chapter opens at belongs
    // to the person, and a pinch is not the reader moving through the chapter.
    expect(keychain.writes, 0);
    expect(store.widthFactorFor(_reader.id), 1.0);
    expect(posted, [20]);

    // Reopened: the chapter opens at the width that was chosen, and not at
    // the one the last one was pinched to.
    await _pumpReader(
      tester,
      initialPage: 20,
      profile: _reader,
      store: store,
      readerKey: const ValueKey('reopened'),
    );
    final asked = {
      for (final image in tester.widgetList<Image>(find.byType(Image)))
        (image.image as ResizeImage).width,
    };
    expect(
      asked,
      {(tester.view.physicalSize.width * StripGeometry.maxWidthFactor).ceil()},
      reason: 'a chapter opens at the width the preference says',
    );
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

  testWidgets(
    'seeking to the second page of a spread does not setState in a build',
    (tester) async {
      // Landscape pairs pages, so a seek to an odd page lands on a spread whose
      // *first* page is the one before it. `_PagedView.didUpdateWidget` follows
      // the seek with `jumpToPage`, which dispatches a scroll notification
      // synchronously — and `PageView` turns that into `onPageChanged`, which
      // reports the pair's first page. That is a different page from the one
      // just asked for, so the reader called `setState` from inside the build
      // that delivered the seek: "setState() or markNeedsBuild() called during
      // build". The error widget then replaced the Scaffold's body, and the rest
      // of the frame died on the Scaffold laying out a body it was never handed.
      tester.view.physicalSize = const Size(2412, 1080);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await _pumpReader(
        tester,
        initialPage: 20,
        direction: ReadingDirection.leftToRight,
      );
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 27 is the second page of the 26–27 spread.
      expect(find.byKey(const ValueKey(27)), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey(27)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rotating with the scrubber open does not rebuild mid-layout', (
    tester,
  ) async {
    // A lazy list builds its children during **layout**, so everything the
    // strip's item builder reaches for is reached for there — and what the
    // reader used to reach for was its own MediaQuery, its client and its
    // saved copy. Asking for an inherited widget in a layout makes this
    // element one of its dependents from inside that layout, and what wakes
    // those dependents is a change of screen. A rotation then rebuilds the
    // reader while it is being laid out, its Scaffold is handed a body that is
    // not the one it laid out, and the frame dies with "Each child must be
    // laid out exactly once".
    await _pumpReader(
      tester,
      initialPage: 20,
      direction: ReadingDirection.leftToRight,
    );
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(ThumbStrip), findsOneWidget);

    for (final size in const [
      Size(2412, 1080), // on its side
      Size(1080, 2412), // and back
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'rotated to $size');
    }
  });

  testWidgets('scrubbing to a far page does not scroll inside a build', (
    tester,
  ) async {
    // A tap on a thumbnail comes back to the strip as a new `current`, so the
    // strip hears about it in `didUpdateWidget` — which runs inside a build.
    // Starting a scroll from there rebuilds a widget while the tree is being
    // laid out, and this Scaffold answers that with "Each child must be laid
    // out exactly once": the body it was handed is not the one it laid out.
    //
    // On a phone in landscape, which is what this surface is: sixteen
    // thumbnails are on screen there, so a tap is almost always more than one
    // page away and takes the strip's landing path rather than its glide.
    tester.view.physicalSize = const Size(2412, 1080);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpReader(
      tester,
      initialPage: 20,
      direction: ReadingDirection.leftToRight,
    );
    // Bring the chrome up: the strip is only built with it.
    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ThumbStrip), findsOneWidget);
    // Several pages along, and still on screen at this width.
    await tester.tap(find.byKey(const ValueKey(26)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    // Landscape pairs pages, so the counter names the spread it landed on.
    expect(find.text('27–28 / $_pages'), findsOneWidget);
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
      expect(
        find.text('Drag to magnify'),
        findsOneWidget,
        reason: 'the sheet should still be open',
      );
    });

    testWidgets('turning magnifying on takes effect without leaving the '
        'chapter', (tester) async {
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

    testWidgets('the width row says where it applies, and stays settable', (
      tester,
    ) async {
      // Paged, no strip is laid out at a width of its own — a page is fitted
      // to the screen. The row says so in place of its explanation and stays
      // settable, which is the magnifying row's rule mirrored: the width
      // belongs to the person, and the next chapter may well be read
      // vertically.
      final store = ProfilePreferencesStore(
        keychain: MemoryKeychain(),
        deviceDirection: ReadingDirection.leftToRight,
      );
      await _pumpReader(
        tester,
        initialPage: 10,
        direction: ReadingDirection.leftToRight,
        profile: _reader,
        store: store,
      );
      await showChrome(tester);
      await openSheet(tester);

      expect(find.text('Page width'), findsOneWidget);
      expect(find.textContaining('Not while paging'), findsOneWidget);
      expect(tester.widget<Slider>(_widthSlider).onChanged, isNotNull);

      // Settable, and what is set is kept: the width belongs to the person
      // and not to the chapter in hand, and the next one may well be read
      // vertically.
      await _narrowStrip(tester);
      expect(store.widthFactorFor(_reader.id), 0.5);
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

      expect(
        find.text('Drag to magnify'),
        findsNothing,
        reason: 'the sheet should have closed',
      );
      // The direction is per-chapter here, and the pager mirrors with it.
      expect(tester.widget<PageView>(find.byType(PageView)).reverse, isTrue);
    });
  });
}
