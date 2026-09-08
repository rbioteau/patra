import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/cover.dart';
import 'package:patra/src/widgets/cover_placeholder.dart';

import 'test_support.dart';

/// A cover with no picture of it: the ordinary case for a series the device
/// remembers past the sweep that took its artwork (ADR-0005).
void main() {
  final client = KavitaClient(
    baseUrl: 'https://kavita.example',
    token: 'jwt',
    username: 'someone',
    apiKey: 'key',
  );

  Future<void> pumpCover(WidgetTester tester, {double width = 100}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              height: width / coverAspectRatio,
              child: CoverImage(
                url: client.seriesCoverUrl(7),
                headers: client.imageHeaders,
                seriesId: 7,
                seriesName: 'Dungeon Meshi',
              ),
            ),
          ),
        ),
      );

  testWidgets('a cover that fails draws its series, not a book glyph', (
    tester,
  ) async {
    mockPathProvider();
    await pumpCover(tester);
    await tester.pumpAndSettle();

    // Nothing serves an image to a test binding, so this is the state a
    // trimmed cache and a dead server both land in.
    expect(find.byType(CoverPlaceholder), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
  });

  testWidgets('the same drawing stands in while the cover loads', (
    tester,
  ) async {
    mockPathProvider();
    await pumpCover(tester);

    // The first frame is the loading state: nothing has resolved yet.
    expect(find.byType(CoverPlaceholder), findsOneWidget);
    expect(find.text('D'), findsOneWidget);

    // And it is one drawing rather than two that happen to agree, so a grid
    // cannot flicker as its covers resolve at different times.
    final cover = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    final context = tester.element(find.byType(CachedNetworkImage));
    expect(
      identical(
        cover.placeholder!(context, ''),
        cover.errorWidget!(context, '', 'whatever went wrong'),
      ),
      isTrue,
    );
  });

  testWidgets('the drawing is sized off the box it is given', (tester) async {
    mockPathProvider();
    double initialSize(WidgetTester tester) =>
        tester.widget<Text>(find.text('D')).style!.fontSize!;

    // The two ends of what one drawing is asked for: a chapter row's cover
    // and a tablet's shelf tile.
    await pumpCover(tester, width: rowCoverWidth);
    final onARow = initialSize(tester);
    await pumpCover(tester, width: 152);
    expect(initialSize(tester), greaterThan(onARow));
  });

  testWidgets('a series with no name draws the hatch alone', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 150,
            child: CoverPlaceholder(seriesId: 7, seriesName: '  '),
          ),
        ),
      ),
    );
    expect(find.byType(Text), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  test('one series id is one pair of tones, every session', () {
    expect(coverPlaceholderTones(7), coverPlaceholderTones(7));
    // Consecutive ids are the ordinary case — a library numbers its series
    // in a row — and are exactly what an unmixed id would draw all alike.
    // These two are a red-leaning near-black and a blue-leaning one, which
    // is a difference a person can see; two hues a few degrees apart at this
    // darkness would come out two units apart, which is to say identical.
    expect(coverPlaceholderTones(7), isNot(coverPlaceholderTones(8)));
    expect(coverPlaceholderTones(7).light, const Color(0xFF2D2525));
    expect(coverPlaceholderTones(8).light, const Color(0xFF25252D));
  });

  test(
    'the tile is the same tile after an upgrade, not just after a rebuild',
    () {
      // The whole point of deriving the tones rather than authoring them is
      // that a shelf looks the same tomorrow. Nothing else in the app would
      // notice this changing, so it is pinned by value: a new mixer, a new
      // palette or a reordered sector list has to be a deliberate edit here.
      expect(coverPlaceholderTones(7).dark, const Color(0xFF261F1F));
      expect(coverPlaceholderTones(8).dark, const Color(0xFF1F1F26));
    },
  );

  test('the palette is small, and every tone in it is tellable apart', () {
    // Twenty-four: six hue sectors by four brightness steps. That is what
    // this darkness allows — see `coverPlaceholderTones` — so a library of
    // sixty series draws each tone two or three times, deliberately, rather
    // than giving each series a tone nobody could distinguish.
    final tones = {for (var id = 1; id <= 400; id++) coverPlaceholderTones(id)};
    expect(tones.length, 24);
    // No two of them within a couple of units of each other on all three
    // channels, which is the failure this palette was refitted to fix.
    for (final a in tones) {
      for (final b in tones) {
        if (a == b) continue;
        expect(
          _channelGap(a.light, b.light),
          greaterThan(2),
          reason: '$a and $b are the same colour to look at',
        );
      }
    }
  });

  test('the tones are near-black, and neither is a colour with a job', () {
    for (var id = 1; id <= 200; id++) {
      final pair = coverPlaceholderTones(id);
      // Dark and low-contrast, so the drawing never competes with the real
      // artwork beside it on a shelf.
      expect(pair.light.computeLuminance(), lessThan(.05));
      expect(
        pair.dark.computeLuminance(),
        lessThan(pair.light.computeLuminance()),
      );
      // patraAccent is reading progress and identity, patraOffline is
      // downloads. Neither is available to a cover with no picture.
      expect(pair.light, isNot(patraAccent));
      expect(pair.light, isNot(patraOffline));
      expect(pair.dark, isNot(patraAccent));
      expect(pair.dark, isNot(patraOffline));
    }
  });
}

/// The biggest single-channel difference between two colours.
int _channelGap(Color a, Color b) => [
  ((a.r - b.r) * 255).abs(),
  ((a.g - b.g) * 255).abs(),
  ((a.b - b.b) * 255).abs(),
].reduce((x, y) => x > y ? x : y).round();
