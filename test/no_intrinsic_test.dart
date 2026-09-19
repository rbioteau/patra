import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/widgets/no_intrinsic.dart';

/// A row whose height is the words' — one child that asks for a size and one
/// picture that must not.
Widget _row({required Widget leading}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 350,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leading,
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Vinland Saga', style: TextStyle(fontSize: 21)),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // **The picture's own pixels are not a layout decision.** A decoded image
  // answers the intrinsic passes with its pixel dimensions, so a row that
  // stretches a cover to the height of the words beside it ends up as tall as
  // the cover's file — 600pt here — the moment that picture is in the cache,
  // and only then: a test that never loads one sees nothing wrong.
  testWidgets('a loaded picture says nothing about the row it is in', (
    tester,
  ) async {
    final picture = await tester.runAsync(
      () => createTestImage(width: 1000, height: 1500),
    );

    await tester.pumpWidget(
      _row(
        leading: NoIntrinsic(
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: RawImage(image: picture),
          ),
        ),
      ),
    );
    final wrapped = tester.getSize(find.byType(IntrinsicHeight));
    final drawn = tester.getSize(find.byType(RawImage));

    // The same row with a box that asks for nothing instead of a picture: the
    // two are the same height, which is the whole of what this widget is for.
    await tester.pumpWidget(
      _row(leading: const SizedBox(width: 40)),
    );
    final without = tester.getSize(find.byType(IntrinsicHeight));

    expect(wrapped.height, without.height);
    // And the picture is still drawn — it takes the height it was given, with
    // its own ratio deciding the width, rather than being dropped or clipped
    // away.
    expect(drawn.height, wrapped.height);
    expect(drawn.width, closeTo(wrapped.height * 2 / 3, 0.5));
  });
}