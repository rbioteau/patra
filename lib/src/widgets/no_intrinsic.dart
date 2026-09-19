import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A box that lays its child out with the constraints it is given, and
/// answers nothing at all to the intrinsic passes.
///
/// **For a picture beside text whose height is the one that counts.** A
/// decoded image reports its own pixels as its intrinsic size, so an
/// `IntrinsicHeight` row holding one — the way a cover is held beside the
/// words of a card, so the cover can be stretched to the words' height — is
/// as tall as the *picture*: a 1500px cover makes the band 1500pt tall the
/// moment the picture lands in the cache, and not before, which is a bug no
/// widget test that never loads an image can see. Nothing here asks the child
/// anything, and the height comes from whatever else is in the row.
///
/// Where the child has an intrinsic size that is worth knowing — a fixed
/// cover, a box that must keep its own ratio — say so outside this widget
/// instead: the widest thing a picture may say about a layout is nothing.
class NoIntrinsic extends SingleChildRenderObjectWidget {
  const NoIntrinsic({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNoIntrinsic();
}

class _RenderNoIntrinsic extends RenderProxyBox {
  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;
}