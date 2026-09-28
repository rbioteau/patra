import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/reader/book_chrome.dart';
import 'package:patra/src/widgets/reader_settings_sheet.dart';

import 'book_reader_harness.dart';

/// The book reader's chrome: what is on screen when a book opens, where a
/// tap turns the page and where it does not, the bar that says where in the
/// book the reader is — and, on a tablet held sideways, two of the server's
/// pages at once with the settings in a panel rather than a sheet.

const _tabletLandscape = Size(1180, 820);
const _tabletPortrait = Size(820, 1180);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('on a phone', () {
    testWidgets('a book opens with its chrome up', (tester) async {
      await pumpBook(tester);

      expect(find.text(bookTitle), findsOneWidget);
      expect(find.byTooltip('Reader settings'), findsOneWidget);
      expect(find.byTooltip('Contents'), findsOneWidget);
      // The bottom bar: the chapter the page is in, the numeral and the
      // seek bar over the whole book.
      expect(find.text('Part one'), findsOneWidget);
      expect(find.text('1 / $bookPages'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('the middle takes the chrome away, leaving the numeral', (
      tester,
    ) async {
      await pumpBook(tester);
      final size = tester.getSize(find.byType(Scaffold));
      await tester.tapAt(Offset(size.width / 2, size.height / 2));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BookTopBar), findsNothing);
      expect(find.byType(BookPageNumeral), findsOneWidget);
      expect(find.text('1 / $bookPages'), findsOneWidget);
    });

    testWidgets('only a band down each edge turns the page', (tester) async {
      final (_, posted) = await pumpBook(tester);
      final size = tester.getSize(find.byType(Scaffold));

      // A third of the way in is the middle now: a thumb resting on a book
      // does not turn it.
      await tester.tapAt(Offset(size.width * .7, size.height / 2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(postedPages(posted), [0]);

      await tapBookEdge(tester, right: true);
      expect(postedPages(posted), [0, 1]);
    });

    testWidgets('the bar names the chapter the page is in', (tester) async {
      await pumpBook(tester, progressPage: 6);
      // Page 6 counted from zero is inside "The worm", which began on 5.
      expect(find.text('The worm'), findsOneWidget);
      expect(find.text('7 / $bookPages'), findsOneWidget);
    });

    testWidgets('the seek bar jumps', (tester) async {
      final (requested, posted) = await pumpBook(tester);
      final slider = tester.getRect(find.byType(Slider));
      await tester.tapAt(Offset(slider.right - 20, slider.center.dy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(postedPages(posted).last, greaterThan(bookPages ~/ 2));
      expect(requested.last, greaterThan(bookPages ~/ 2));
    });

    testWidgets('a drag on the seek bar moves the book once', (tester) async {
      final (requested, posted) = await pumpBook(tester);
      final before = requested.length;
      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // One place posted and the pages around it asked for — not one for
      // every step the thumb passed over.
      expect(postedPages(posted), hasLength(2));
      expect(requested.length - before, lessThanOrEqualTo(3));
    });

    testWidgets('Aa opens the sheet, not a panel', (tester) async {
      await pumpBook(tester);
      await tester.tap(find.byTooltip('Reader settings'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(BookSettingsPanel), findsNothing);
    });
  });

  group('on a tablet held sideways', () {
    testWidgets('two of the server\'s pages are read at once', (tester) async {
      final (requested, posted) = await pumpBook(
        tester,
        size: _tabletLandscape,
      );

      expect(find.text('1–2 / $bookPages'), findsOneWidget);
      // Both pages of the spread, and the pages either side of it.
      expect(askedPages(requested), containsAll([0, 1]));

      await tapBookEdge(tester, right: true);
      // A spread is two pages: the next one starts on the third, and what is
      // reported is the right-hand page, the last one on screen.
      expect(find.text('3–4 / $bookPages'), findsOneWidget);
      expect(postedPages(posted).last, 3);

      await tapBookEdge(tester, right: false);
      expect(find.text('1–2 / $bookPages'), findsOneWidget);
    });

    testWidgets('a book opened on an even page opens on its spread', (
      tester,
    ) async {
      // Page 5 counted from zero is the right-hand page of the third spread.
      await pumpBook(tester, size: _tabletLandscape, progressPage: 5);
      expect(find.text('5–6 / $bookPages'), findsOneWidget);
    });

    testWidgets('Aa opens a panel with no scrim, and the page closes it', (
      tester,
    ) async {
      await pumpBook(tester, size: _tabletLandscape);
      await tester.tap(find.byTooltip('Reader settings'));
      await tester.pumpAndSettle();

      expect(find.byType(BookSettingsPanel), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      // Compact: the faces as tiles, a step of two points a tap.
      expect(find.byType(BookFaceTiles), findsOneWidget);
      expect(find.text('16 pt'), findsOneWidget);
      await tester.tap(find.byTooltip('Larger'));
      await tester.pumpAndSettle();
      expect(find.text('18 pt'), findsOneWidget);

      // A tap on the page closes the panel and leaves the chrome where it
      // was.
      final size = tester.getSize(find.byType(Scaffold));
      await tester.tapAt(Offset(size.width * .3, size.height * .8));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BookSettingsPanel), findsNothing);
      expect(find.byType(BookTopBar), findsOneWidget);
    });
  });

  testWidgets('a tablet held upright reads one page', (tester) async {
    await pumpBook(tester, size: _tabletPortrait);
    expect(find.text('1 / $bookPages'), findsOneWidget);
  });
}
