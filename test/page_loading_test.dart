import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/l10n/generated/app_localizations.dart';
import 'package:patra/src/features/reader/page_loading.dart';
import 'package:patra/src/theme.dart';

/// A picture that arrives: four points of the reader's own page colour, drawn
/// rather than decoded, because a widget test has no decoder behind it.
class _Arrives extends ImageProvider<_Arrives> {
  const _Arrives();

  @override
  Future<_Arrives> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_Arrives>(this);

  @override
  ImageStreamCompleter loadImage(
    _Arrives key,
    ImageDecoderCallback decode,
  ) =>
      OneFrameImageStreamCompleter(_drawn());

  static Future<ImageInfo> _drawn() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xFF203040), BlendMode.src);
    return ImageInfo(
      image: await recorder.endRecording().toImage(4, 4),
      scale: 1,
    );
  }
}

/// A picture that never arrives: the state a page is in while a new one is
/// being decoded at a different width.
class _NeverArrives extends ImageProvider<_NeverArrives> {
  const _NeverArrives();

  @override
  Future<_NeverArrives> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_NeverArrives>(this);

  @override
  ImageStreamCompleter loadImage(
    _NeverArrives key,
    ImageDecoderCallback decode,
  ) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

Future<void> pumpPicture(
  WidgetTester tester, {
  required ImageProvider<Object> image,
}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: patraTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PageImage(
            image: image,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            explain: false,
          ),
        ),
      ),
    );

void main() {
  Future<void> pump(WidgetTester tester, {required bool explain}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: patraTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PageLoading(explain: explain)),
        ),
      );

  testWidgets('an ordinary page never explains itself', (tester) async {
    await pump(tester, explain: false);
    await tester.pump(PageLoading.explainAfter * 3);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Preparing the PDF'), findsNothing);
  });

  testWidgets('a PDF says what the server is doing, but not at once', (
    tester,
  ) async {
    await pump(tester, explain: true);

    // A page that arrives normally must not flash a wall of text on the way.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Preparing the PDF'), findsNothing);

    await tester.pump(PageLoading.explainAfter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Preparing the PDF'), findsOneWidget);
    expect(find.textContaining('Only the first open waits'), findsOneWidget);
  });

  testWidgets('a page with no picture yet says so', (tester) async {
    await pumpPicture(tester, image: const _NeverArrives());
    await tester.pump();

    expect(find.byType(PageLoading), findsOneWidget);
  });

  testWidgets('a new decode does not blank a page that has been read', (
    tester,
  ) async {
    // A picture arrives.
    await pumpPicture(tester, image: const _Arrives());
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(PageLoading), findsNothing);

    // And then the width changes, which asks for a new one — `ResizeImage`
    // puts the width it decodes at in its cache key, so a pinch settling or a
    // hand on the width slider is a new picture for every live page. This one
    // has not arrived yet, and the page keeps the picture it has rather than
    // showing the spinner on every step of the gesture.
    await pumpPicture(tester, image: const _NeverArrives());
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(PageLoading), findsNothing);
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      const _NeverArrives(),
    );
  });
}
