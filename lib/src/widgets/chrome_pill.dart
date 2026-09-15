import 'package:flutter/material.dart';

import '../theme.dart';

/// One control in the reader's chrome: a pill laid over the page.
///
/// The reader draws two — the cog in the top bar, and, for a book, the control
/// that opens its contents — and one widget draws both, because a pill that
/// reads as a control on top of a photograph is a decoration two copies of
/// which would be two decorations. The colours are shares of white rather
/// than colours of ours (see [patraOnPageFill]), since what sits underneath
/// may be anything from black ink to bare white paper.
///
/// [width] is for a control that is one glyph wide; left null, the pill is
/// the width of what it says.
class ChromePill extends StatelessWidget {
  const ChromePill({
    super.key,
    required this.onTap,
    required this.child,
    this.tooltip,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final VoidCallback onTap;
  final Widget child;

  /// What the control is, for a screen reader and for a long press: null
  /// where the pill already says it in words.
  final String? tooltip;

  final double? width;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final pill = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusPill),
      child: Container(
        height: 36,
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: patraOnPageFill,
          borderRadius: BorderRadius.circular(radiusPill),
          border: Border.all(color: patraOnPageOutline),
        ),
        // The row is what centres the contents, and the row is what keeps a
        // pill that says something to the width of its own words: a
        // `Container` given an alignment fills the width it is handed, and a
        // pill stretched across the bar stops reading as a control.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [child],
        ),
      ),
    );
    final message = tooltip;
    return message == null ? pill : Tooltip(message: message, child: pill);
  }
}
