import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/theme.dart';
import 'package:patra/src/widgets/read_mark.dart';

/// How a finished chapter is marked, away from the screens that mark one.
///
/// Read is a *positive* signal in this app and wears the accent that already
/// means reading progress: a rail on the row's leading edge, and — on a grid
/// tile, which has no row to put a rail on — the progress bar simply run
/// full. Nothing is dimmed and nothing is faded: a lowered opacity already
/// means *unavailable* here, which is the opposite of what read says.
void main() {
  group('a finished cover runs its bar full', () {
    Future<void> pumpBar(WidgetTester tester, double progress) =>
        tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                width: 200,
                height: 300,
                child: Stack(
                  fit: StackFit.expand,
                  children: [CoverProgressBar(progress: progress)],
                ),
              ),
            ),
          ),
        );

    double? filledShare(WidgetTester tester) {
      final bars = tester.widgetList<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      return bars.isEmpty ? null : bars.single.widthFactor;
    }

    testWidgets('nothing at all where nothing has been read', (tester) async {
      await pumpBar(tester, 0);
      expect(filledShare(tester), isNull);
    });

    testWidgets('a part-filled bar part of the way through', (tester) async {
      await pumpBar(tester, .5);
      expect(filledShare(tester), .5);
    });

    // It used to erase itself here, so the one signal that carried meaning
    // disappeared at the moment it was complete. On a library tile that bar
    // is the only mark a read series carries.
    testWidgets('a full bar once every page is read', (tester) async {
      await pumpBar(tester, 1);
      expect(filledShare(tester), 1);
    });
  });

  group('the read rail', () {
    Future<void> pumpRow(WidgetTester tester, {required bool read}) =>
        tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: ReadRail(
                  read: read,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: gutter,
                      vertical: 11,
                    ),
                    child: SizedBox(height: 66, child: Text('Chapter 1')),
                  ),
                ),
              ),
            ),
          ),
        );

    Finder railFinder() => find.descendant(
      of: find.byType(ReadRail),
      matching: find.byType(ColoredBox),
    );

    testWidgets('is drawn only over a row that is read', (tester) async {
      await pumpRow(tester, read: false);
      expect(railFinder(), findsNothing);

      await pumpRow(tester, read: true);
      expect(railFinder(), findsOneWidget);
    });

    testWidgets('wears the accent, full height, on the leading edge', (
      tester,
    ) async {
      await pumpRow(tester, read: true);
      expect(tester.widget<ColoredBox>(railFinder()).color, patraAccent);
      expect(
        tester.getSize(railFinder()),
        const Size(readRailWidth, 66 + 11 * 2),
      );
      expect(tester.getTopLeft(railFinder()).dx, 0);
    });

    // Taken *out of* the row's leading gutter rather than added to it: a read
    // row and an unread one line up, so a list of rows has one left edge.
    testWidgets('moves nothing inside the row', (tester) async {
      await pumpRow(tester, read: false);
      final unread = tester.getTopLeft(find.text('Chapter 1'));

      await pumpRow(tester, read: true);
      expect(tester.getTopLeft(find.text('Chapter 1')), unread);
    });
  });
}
