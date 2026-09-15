import 'package:flutter/material.dart';

import '../theme.dart';

/// The wordmark: lowercase serif "patra" with the accent period.
///
/// One definition, because there are three of it on screen — the launch
/// animation's, the home header's and the login masthead's — and the launch
/// animation *lands* its own on the other two. A tracking or a weight that
/// drifted between them would show up as a shift at the moment they cross
/// over, which is the one moment they are compared directly.
class PatraWordmark extends StatelessWidget {
  const PatraWordmark({super.key, required this.size, this.dotScale = 1});

  final double size;

  /// The accent period springs in a beat after the word during the launch
  /// animation. Everywhere else it is simply there.
  final double dotScale;

  /// The handoff's -0.5px at 40px, kept as a fraction so the lockup reads the
  /// same at the header's size as at the masthead's.
  static const _tracking = -0.0125;

  /// How tall the word is drawn beside the signature, in ems of it.
  ///
  /// Not 1: the word's own extent runs from the shirorekha down through the
  /// त्र conjunct, which is Devanagari's ascender-to-descender span, and a
  /// signature's is its *point* size only in the abstract — set 1:1 the word
  /// reads about a quarter too big next to it, its headline clearing the
  /// Latin ascenders and its conjunct falling past the descender. 0.8 puts
  /// the two spans on top of one another, which is what makes them one
  /// lockup. One definition, or the header and the masthead drift apart.
  static const markEm = 0.8;

  @override
  Widget build(BuildContext context) {
    final style = PatraText.serifTitle(size: size)
        .copyWith(letterSpacing: size * _tracking);
    final dot = style.copyWith(color: patraAccent);
    return Text.rich(
      TextSpan(
        text: 'patra',
        style: style,
        children: [
          if (dotScale == 1)
            TextSpan(text: '.', style: dot)
          else
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Transform.scale(
                scale: dotScale,
                child: Text('.', style: dot),
              ),
            ),
        ],
      ),
    );
  }
}
