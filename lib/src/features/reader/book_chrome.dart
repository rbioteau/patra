import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../theme.dart';

/// The chrome of the book reader: a bar across the top naming the book, with
/// its contents and its settings; a bar across the bottom saying where in the
/// book the reader is, with a seek bar under it; and, while both are away,
/// the page numeral alone.
///
/// A book's chrome is its own rather than the picture reader's: a page of
/// words is set on the app's night blue and is read a line at a time, so the
/// bars are solid `patraChrome` with a hairline rather than scrims fading
/// over a scan, and the seek bar is the book's only way to move far — it has
/// no strip of pages to scrub.
///
/// On a tablet the bars are a step up: taller, and the bottom one a single
/// row with the seek bar between the chapter and the numeral.

final _rule = BorderSide(color: patraBookBarRule);

class BookTopBar extends StatelessWidget {
  const BookTopBar({
    super.key,
    required this.title,
    required this.tablet,
    required this.onSettings,
    this.onContents,
  });

  final String title;
  final bool tablet;
  final VoidCallback onSettings;

  /// Null where the server listed no contents, and then no control is drawn:
  /// a book with none says nothing about the absence.
  final VoidCallback? onContents;

  /// How tall the bar is below the status bar, which is where a panel
  /// anchored under it starts.
  static double height({required bool tablet}) => tablet ? 60 : 56;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final contents = onContents;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: patraBookBar,
          border: Border(bottom: _rule),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: height(tablet: tablet),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tablet ? 10 : 4,
                0,
                tablet ? 16 : 8,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: patraText),
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PatraText.rowTitle(size: tablet ? 16 : 15),
                    ),
                  ),
                  if (contents != null)
                    IconButton(
                      icon: const Icon(
                        Icons.toc,
                        size: 22,
                        color: patraTextMuted,
                      ),
                      tooltip: l10n.bookContents,
                      onPressed: contents,
                    ),
                  const SizedBox(width: 4),
                  AaButton(tooltip: l10n.readerSettings, onTap: onSettings),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The book's settings, as the one round control on the page's own ground:
/// 44 across, in the fill and outline every control laid over a page wears.
class AaButton extends StatelessWidget {
  const AaButton({super.key, required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: patraOnPageFill,
      shape: CircleBorder(side: BorderSide(color: patraOnPageOutline)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox.square(
          dimension: minHitTarget,
          child: Icon(Icons.text_fields, size: 22, color: patraText),
        ),
      ),
    ),
  );
}

/// Where in the book the reader is: the chapter they are in, the page
/// numeral, and a seek bar across the whole book.
class BookBottomBar extends StatefulWidget {
  const BookBottomBar({
    super.key,
    required this.chapterName,
    required this.counter,
    required this.page,
    required this.pages,
    required this.onSeek,
    required this.tablet,
  });

  /// Null before the first entry of the contents, or where there are none.
  final String? chapterName;
  final String counter;
  final int page;
  final int pages;
  final ValueChanged<int> onSeek;
  final bool tablet;

  @override
  State<BookBottomBar> createState() => _BookBottomBarState();
}

class _BookBottomBarState extends State<BookBottomBar> {
  /// Where the thumb is while a finger holds it, or null at rest. The book
  /// moves once, where the finger lifts: every step of a drag turning to a
  /// page was a page fetched and a place posted to the server for each.
  int? _dragging;

  @override
  Widget build(BuildContext context) {
    final (:chapterName, :counter, :page, :pages, :tablet) = (
      chapterName: widget.chapterName,
      counter: widget.counter,
      page: _dragging ?? widget.page,
      pages: widget.pages,
      tablet: widget.tablet,
    );
    final chapter = Text(
      chapterName ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: PatraText.metadata(size: tablet ? 13 : 12),
    );
    final numeral = Text(
      counter,
      style: PatraText.pageNumeral(color: patraText)
          .copyWith(fontSize: tablet ? 14 : null),
    );
    final seek = pages > 1
        ? SizedBox(
            height: 28,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: patraAccent,
                inactiveTrackColor: patraTrack,
                thumbColor: patraAccent,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                // A book is hundreds of pages: a tick for each is a dotted
                // line, not a track.
                tickMarkShape: SliderTickMarkShape.noTickMark,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: page.clamp(0, pages - 1).toDouble(),
                max: (pages - 1).toDouble(),
                divisions: pages - 1,
                semanticFormatterCallback: (_) => counter,
                onChanged: (value) => setState(() => _dragging = value.round()),
                onChangeEnd: (value) {
                  setState(() => _dragging = null);
                  widget.onSeek(value.round());
                },
              ),
            ),
          )
        : const SizedBox(height: 28);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: patraBookBar,
          border: Border(top: _rule),
        ),
        child: SafeArea(
          top: false,
          // The chrome never turns with the book (#118): the numerals and the
          // seek bar read left to right whichever way the pages do.
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: tablet
                  ? const EdgeInsets.symmetric(horizontal: 32, vertical: 14)
                  : const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: tablet
                  ? Row(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 240),
                          child: chapter,
                        ),
                        const SizedBox(width: 20),
                        Expanded(child: seek),
                        const SizedBox(width: 20),
                        numeral,
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(child: chapter),
                            const SizedBox(width: 12),
                            numeral,
                          ],
                        ),
                        const SizedBox(height: 6),
                        seek,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The page numeral alone, while the chrome is away: centred near the foot
/// of the page, muted so it is found when looked for and not read otherwise.
class BookPageNumeral extends StatelessWidget {
  const BookPageNumeral({
    super.key,
    required this.counter,
    required this.tablet,
  });

  final String counter;
  final bool tablet;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: tablet ? 28 : 22),
        child: IgnorePointer(
          child: Text(
            counter,
            textAlign: TextAlign.center,
            style: PatraText.pageNumeral(color: patraTextMuted),
          ),
        ),
      ),
    ),
  );
}

/// Where a tap lands on a page of a book: a narrow band down either edge
/// turns the page, and everything between shows or hides the chrome.
///
/// Narrow on purpose, and a width in points rather than a share of the page:
/// a book is read with a thumb resting on it, and a third of the screen on
/// either side turning the page was a page turned by the hand holding it.
/// The two sides are named for where they are; which of them reads on is
/// passed in the other way round for a book that turns from the right.
class BookTapZones extends StatelessWidget {
  const BookTapZones({
    super.key,
    required this.edge,
    required this.onLeft,
    required this.onRight,
    required this.onMiddle,
  });

  /// How wide each edge band is: 48 on a phone, 64 on a tablet.
  final double edge;
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onMiddle;

  Widget _zone(VoidCallback onTap) =>
      GestureDetector(behavior: HitTestBehavior.translucent, onTap: onTap);

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          SizedBox(width: edge, child: _zone(onLeft)),
          Expanded(child: _zone(onMiddle)),
          SizedBox(width: edge, child: _zone(onRight)),
        ],
      ),
    ),
  );
}
