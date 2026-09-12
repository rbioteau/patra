import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../theme.dart';

/// A page that has not arrived yet.
///
/// A spinner on its own, until waiting stops being ordinary: after
/// [PageLoading.explainAfter] it says what the server is doing, so a slow first PDF looks
/// like work rather than a failure. Never shown at once — a page that loads
/// normally must not flash a wall of text.
class PageLoading extends StatefulWidget {
  const PageLoading({super.key, required this.explain});

  /// Whether there is anything to explain: only a PDF has this wait.
  final bool explain;

  /// Long enough that an ordinary page never shows a word of this.
  static const explainAfter = Duration(milliseconds: 1800);

  @override
  State<PageLoading> createState() => _PageLoadingState();
}

class _PageLoadingState extends State<PageLoading> {
  Timer? _timer;
  var _explaining = false;

  @override
  void initState() {
    super.initState();
    if (!widget.explain) return;
    _timer = Timer(PageLoading.explainAfter, () {
      if (mounted) setState(() => _explaining = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _explaining ? patraAccent : Colors.white24,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _explaining
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          l10n.pdfPreparing,
                          textAlign: TextAlign.center,
                          style: PatraText.rowTitle(),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            l10n.pdfPreparingBody,
                            textAlign: TextAlign.center,
                            style: PatraText.metadata(),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(width: 260),
            ),
          ],
        ),
      ),
    );
  }
}

/// One page's picture, which keeps the one it has while the next arrives.
///
/// A page is decoded at the width it is drawn at, and `ResizeImage` puts that
/// width in its cache key — so every time the width moves, a new picture is
/// asked for: a pinch settling, a hand on the width slider, a rotation.
/// `gaplessPlayback` keeps the old one inside the widget, but it is
/// [Image.frameBuilder] that decides what is drawn, and a builder that shows
/// [PageLoading] whenever there is no frame covers the very picture it was
/// asked to keep — the strip then blinked once per step of the gesture. This
/// is the piece that remembers whether there is a picture to keep, so a new
/// decode never blanks a page that has already been read.
class PageImage extends StatefulWidget {
  const PageImage({
    super.key,
    required this.image,
    required this.fit,
    required this.alignment,
    required this.explain,
  });

  final ImageProvider image;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  /// Whether there is a wait worth explaining: see [PageLoading.explain].
  final bool explain;

  @override
  State<PageImage> createState() => _PageImageState();
}

class _PageImageState extends State<PageImage> {
  /// Whether a picture has been painted for this page.
  ///
  /// Noted down in [build] and not through `setState`: the frame that brings
  /// a picture is already a rebuild, and asking for another from inside one
  /// is the kind of thing this screen has already died on.
  var _painted = false;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: widget.image,
      fit: widget.fit,
      alignment: widget.alignment,
      // The old picture, held until the new one has decoded.
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white24),
      ),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) _painted = true;
        return _painted ? child : PageLoading(explain: widget.explain);
      },
    );
  }
}

typedef PageImageBuilder = Widget Function(
  int page, {
  int? cacheWidth,
  BoxFit fit,
  bool thumbnail,
  AlignmentGeometry alignment,
});

// --- paged view -------------------------------------------------------------
