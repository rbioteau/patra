import 'package:flutter/material.dart';

import '../branding/patra_signature.dart';

/// The wordmark: the kit's own outlines for "patra", with the accent period.
///
/// One definition, because there are three of it on screen — the launch
/// animation's, the home header's and the login masthead's — and the launch
/// animation *lands* its own on the other two. A shape, a size or a spacing
/// that drifted between them would show up as a shift at the moment they cross
/// over, which is the one moment they are compared directly.
///
/// It is drawn from the paths rather than set in the interface serif, and that
/// is what keeps the mark the kit's now that the app's serif is Literata: the
/// outlines are the kit's own shaping of the signature, spacing included, and
/// a text version would wear whatever tracking it was given instead. See
/// [PatraSignature], which the launch animation draws through as well.
class PatraWordmark extends StatelessWidget {
  const PatraWordmark({super.key, required this.size, this.dotScale = 1});

  /// The size the signature is set at, in points — the em the kit shaped its
  /// outlines at, and the size the word beside it is measured against.
  final double size;

  /// The accent period springs in a beat after the word during the launch
  /// animation. Everywhere else it is simply there.
  final double dotScale;

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
    return PatraSignature(
      size: size,
      dotScale: dotScale,
    );
  }
}
