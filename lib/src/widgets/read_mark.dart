import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme.dart';

/// The mark a finished row carries: a rail down its leading edge, in the
/// accent that already means reading progress.
///
/// Read is a **positive** signal, so nothing recedes: no filter, no fade, no
/// muted title. A lowered opacity is already spoken for in this app — it
/// means *unavailable, something must be done* (a chapter that cannot be
/// opened offline, a profile whose key the server has stopped accepting) —
/// and read says the opposite.
///
/// The rail is taken **out of** the row's leading gutter rather than added to
/// it: it is painted over the gutter the row already had, so neither cover
/// nor title moves between a read row and an unread one and a column of rows
/// keeps one left edge. Both screens that draw this row — the series screen's
/// chapters and the Downloads tab — use it, for the same reason
/// [rowCoverWidth] is not written twice.
class ReadRail extends StatelessWidget {
  const ReadRail({super.key, required this.read, required this.child});

  final bool read;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The [Stack] is there either way, and only the rail comes and goes:
    // marking a row read is optimistic, so this rebuilds under the reader's
    // finger — and a wrapper that appeared at that moment would reparent the
    // row, deactivating the thumbnail and the image behind it for nothing.
    return Stack(
      children: [
        child,
        if (read)
          const PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: readRailWidth,
              child: ColoredBox(color: patraAccent),
            ),
          ),
      ],
    );
  }
}

/// How many pages a row is, carrying the word — and the accent — where the
/// row has been read through.
///
/// One widget for the two screens that draw this row, for the same reason
/// [ReadRail] is one and [rowCoverWidth] is not written twice: the series
/// screen's chapters and the Downloads tab are the same row, and the last
/// time each held its own answer the two drifted apart.
///
/// The word is **inside** the sentence rather than concatenated onto the
/// count, so a translation orders it its own way rather than English's.
class PageCountLine extends StatelessWidget {
  const PageCountLine({
    super.key,
    required this.pages,
    required this.read,
    required this.size,
    this.trailing,
  });

  final int pages;
  final bool read;
  final double size;

  /// Appended after the count, and deliberately **not** in the accent: the
  /// Downloads row says how big its copy is, which is a fact about a file and
  /// not about reading progress. Gold is spoken for (see `CLAUDE.md`), so it
  /// stops where the sentence about reading does.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final base = PatraText.metadata(size: size);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: read ? l10n.readPageCount(pages) : l10n.pageCount(pages),
            style: read ? base.copyWith(color: patraAccent) : null,
          ),
          if (trailing != null) TextSpan(text: ' · $trailing'),
        ],
      ),
      style: base,
    );
  }
}
