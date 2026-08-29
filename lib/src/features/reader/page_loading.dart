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
                color: _explaining ? versoAccent : Colors.white24,
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
                          style: VersoText.rowTitle(),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            l10n.pdfPreparingBody,
                            textAlign: TextAlign.center,
                            style: VersoText.metadata(),
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

typedef PageImageBuilder = Widget Function(
  int page, {
  int? cacheWidth,
  BoxFit fit,
  bool thumbnail,
});

// --- paged view -------------------------------------------------------------
