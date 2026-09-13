import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/reader/page_rail.dart';
import 'package:patra/src/features/reader/strip_geometry.dart';

/// The rail's surface: a strip of 200 pages in a 400x600 viewport, the same
/// chapter geometry the strip's own tests measure, so the rail's share of a
/// page can be worked out by hand and not read off the arithmetic that asked
/// for it.
const _screenWidth = 400.0;
const _viewportHeight = 600.0;
const _pages = 200;

/// The gaps the rail is mounted between — the test's own stand-ins for the
/// reader's chrome bars: 72pt of top chrome and 62pt of bottom chrome, which
/// is the numbers the reader's real bars measure out to.
const _topGap = 72.0;
const _bottomGap = 62.0;
const _trackHeight = _viewportHeight - _topGap - _bottomGap;

/// The height of [page] at [_screenWidth]: mostly 400, with a short scan, a
/// tall one and an exceptionally tall one mixed in.
double _heightAt(int page) => switch (page) {
  7 => 200,
  100 => 800,
  150 => 1200,
  _ => 400,
};

/// Where [page] starts at [_screenWidth].
double _topAt(int page) => switch (page) {
  < 8 => 400.0 * page,
  <= 100 => 400.0 * page - 200,
  <= 150 => 400.0 * page + 200,
  _ => 400.0 * page + 1000,
};

/// The whole strip: the last page's bottom.
const _total = 81000.0;

StripGeometry _geometry() => StripGeometry(
  screenWidth: _screenWidth,
  pages: _pages,
  aspectRatioFor: (page) => _screenWidth / _heightAt(page),
);

/// Where [page] starts, which is what a seek to it lands on: its top.
double _topOf(int page) => _geometry().offsetFor(StripAnchor(page, 0));

/// The middle of [page]: where a finger lands to address it without grazing
/// the boundary it shares with its neighbour.
double _midOf(int page) => _topAt(page) + _heightAt(page) / 2;

class _Harness {
  const _Harness(this.scroll, this.seeks);

  final ScrollController scroll;

  /// Every page the rail asked to land on, in order.
  final List<int> seeks;
}

/// The rail the way the reader mounts it: the module's own strip on the
/// surface — so the controller has a position to attach to and offsets mean
/// something — and the rail against the right edge, on top of it. A seek is
/// answered the way the reader answers it: the strip lands on the top of the
/// page asked for, which is also what lets the handle (and this test) see
/// where a drag put the reader.
Future<_Harness> _pump(WidgetTester tester) async {
  tester.view.physicalSize = Size(_screenWidth * 3, _viewportHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final geometry = _geometry();
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  final seeks = <int>[];
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox(
          width: _screenWidth,
          height: _viewportHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomScrollView(
                controller: scroll,
                slivers: <Widget>[
                  StripExtentList(
                    geometry: geometry,
                    itemBuilder: (_, int page) => SizedBox.expand(
                      key: ValueKey(page),
                      child: const ColoredBox(color: Color(0xFF203040)),
                    ),
                  ),
                ],
              ),
              PageRail(
                geometry: geometry,
                controller: scroll,
                topGap: _topGap,
                bottomGap: _bottomGap,
                onSeek: (page) {
                  seeks.add(page);
                  scroll.jumpTo(geometry.offsetFor(StripAnchor(page, 0)));
                },
                // Nothing in this test moves the strip from inside a build.
                seeking: () => false,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(scroll, seeks);
}

/// The rail's own reachable region, in the screen's coordinates.
Rect _rail(WidgetTester tester) => tester.getRect(find.byType(PageRail));

void main() {
  group('where the handle sits', () {
    testWidgets('is where the chapter above it ends, from top to bottom', (
      tester,
    ) async {
      final harness = await _pump(tester);
      final rail = _rail(tester);
      // The rail is the reachable region the module is given: between the
      // chrome bars, and both gaps are the module's own.
      expect(rail.height, moreOrLessEquals(_trackHeight, epsilon: 0.5));
      expect(rail.top, moreOrLessEquals(_topGap, epsilon: 0.5));

      double handle() =>
          tester.getCenter(find.byKey(const ValueKey('pageRailHandle'))).dy;

      // The top of the chapter: nothing above the handle.
      expect(handle(), moreOrLessEquals(rail.top, epsilon: 0.5));

      // Page 100's top at 40200 of 81000: a share of the rail to the point.
      harness.scroll.jumpTo(_topOf(100));
      await tester.pump();
      expect(
        handle(),
        moreOrLessEquals(
          rail.top + rail.height * _topAt(100) / _total,
          epsilon: 1,
        ),
        reason: 'page 100 of 200, where its top is',
      );

      // The last page reachable: the same page the drag seeks to.
      harness.scroll.jumpTo(harness.scroll.position.maxScrollExtent);
      await tester.pump();
      expect(
        handle(),
        moreOrLessEquals(
          rail.top + rail.height * (harness.scroll.offset / _total),
          epsilon: 1,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a height-proportional share is what the rail draws', (
      tester,
    ) async {
      // The chapter has pages of three heights, and the rail must give each
      // the share of itself its height has of the chapter: a page twice as
      // tall as its neighbour gets twice the rail (#52). An even map — one
      // page, one share — would put the handle somewhere else on the three
      // pages whose heights differ.
      final harness = await _pump(tester);
      final rail = _rail(tester);
      for (final page in [100, 150, 0]) {
        harness.scroll.jumpTo(_topOf(page));
        await tester.pump();
        expect(
          tester.getCenter(find.byKey(const ValueKey('pageRailHandle'))).dy,
          moreOrLessEquals(
            rail.top + rail.height * _topAt(page) / _total,
            epsilon: 1,
          ),
          reason: 'page $page',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('a drag', () {
    testWidgets('lands on the page under the finger, first and last', (
      tester,
    ) async {
      final harness = await _pump(tester);
      final rail = _rail(tester);
      final x = rail.center.dx;

      // The finger lands near the bottom of the rail: the far end of the
      // chapter, which is its last page — the point is inside page 199's
      // share, so the seek lands on 199.
      final finger = await tester.startGesture(Offset(x, rail.top + 4));
      await tester.pump();
      await finger.moveTo(Offset(x, rail.bottom - 2));
      await tester.pump();
      expect(harness.seeks.last, 199, reason: 'the last page');

      await finger.moveTo(Offset(x, rail.top + 2));
      await tester.pump();
      expect(harness.seeks.last, 0, reason: 'the first page');

      // A seek is a seek wherever the finger lands: the middle of page 100,
      // at a fifth of 40600 over 81000, straight down the rail.
      final y = rail.top + rail.height * _midOf(100) / _total;
      await finger.moveTo(Offset(x, y));
      await tester.pump();
      expect(harness.seeks.last, 100);

      await finger.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a seek lands on the top of the page asked for', (
      tester,
    ) async {
      final harness = await _pump(tester);
      final rail = _rail(tester);
      // Partway down a 1200-point page: the seek lands on its top, which is
      // what "lands on the page asked for" means for a chapter being read.
      final finger = await tester.startGesture(
        Offset(rail.center.dx, rail.top + rail.height / 2),
      );
      await tester.pump();
      final landed = harness.seeks.last;
      expect(
        harness.scroll.offset,
        moreOrLessEquals(_topOf(landed), epsilon: 0.5),
        reason: 'the strip is at the top of the page the finger addressed',
      );
      await finger.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('the page number', () {
    testWidgets('shows while a finger is on the rail, and not otherwise', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('1'), findsNothing);
      expect(find.text('101'), findsNothing);

      // The rail's number is the address a seek would land on, drawn in the
      // reader's numeral voice: page 100, one-based like the counter.
      final rail = _rail(tester);
      final finger = await tester.startGesture(
        Offset(rail.center.dx, rail.top + rail.height * _midOf(100) / _total),
      );
      await tester.pump();
      expect(find.text('101'), findsOneWidget);
      expect(
        find.text('1'),
        findsNothing,
        reason: 'the number is where the finger is, not where the seek was',
      );

      await finger.up();
      await tester.pump();
      expect(find.text('101'), findsNothing, reason: 'gone with the finger');
      expect(tester.takeException(), isNull);
    });

    testWidgets('clears a system bar that runs along the right edge', (
      tester,
    ) async {
      // Some devices put a gesture nav or a sidebar on the right edge of the
      // screen in portrait; the reader draws it in edge-to-edge, so the inset
      // is real and the rail must sit inside it, not under it (#52).
      // The inset is physical pixels on the view, at a DPR of 3: 24 of them
      // logical is 72 physical.
      tester.view.padding = const FakeViewPadding(right: 72.0);
      addTearDown(tester.view.reset);
      await _pump(tester);
      final rail = _rail(tester);

      expect(
        rail.right,
        moreOrLessEquals(_screenWidth - 24, epsilon: 0.5),
        reason: 'the rail tucks just inside the system bar',
      );
      expect(
        rail.left,
        moreOrLessEquals(_screenWidth - 24 - PageRail.hitWidth, epsilon: 0.5),
      );
      expect(tester.takeException(), isNull);
    });
  });
  group('the page number', () {
    testWidgets('floats clear of the thumb that is dragging the rail', (
      tester,
    ) async {
      // The thumb is what the rail is dragged by, and a number drawn where
      // it is holding is a number it covers (#52): in the body of the rail
      // the pill rides a thumb's height ABOVE the finger, and near the top
      // of the rail — where there is no room above to clear it — BELOW it.
      await _pump(tester);
      final rail = _rail(tester);
      final x = rail.center.dx;

      // Midway down the chapter, well inside the body of the rail.
      final mid = Offset(x, rail.top + rail.height / 2);
      final finger = await tester.startGesture(mid);
      await tester.pump();
      final above = tester.getRect(find.text('101'));
      expect(find.text('101'), findsOneWidget);
      expect(
        above.bottom,
        lessThan(mid.dy - 24),
        reason: "a thumb’s clearance above the finger, not under it",
      );
      expect(
        above.bottom,
        greaterThanOrEqualTo(rail.top),
        reason: 'and still inside the reachable region',
      );

      // Near the top of the rail: the pill flips below the finger.
      await finger.moveTo(Offset(x, rail.top + 2));
      await tester.pump();
      final below = tester.getRect(find.text('1'));
      expect(
        below.top,
        greaterThan(rail.top + 2 + 24),
        reason: 'below the finger where it cannot clear above it',
      );

      await finger.up();
      await tester.pump();
      expect(find.text('101'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
