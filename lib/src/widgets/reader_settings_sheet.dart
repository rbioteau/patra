import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../features/reader/book_layout.dart';
import '../features/reader/reading_direction.dart';
import '../features/reader/strip_geometry.dart';
import '../settings/profile_preferences.dart';
import '../settings/reading_settings.dart';
import '../theme.dart';
import 'direction_icon.dart';

/// The reader's settings, in one sheet.
///
/// The top bar used to carry the reading direction on a pill of its own, which
/// was right while the direction was the only thing there was to say. It is
/// not any more: magnifying cannot be drawn as an icon the way a direction can
/// — a page glyph with a flow arrow really does say "left to right", and
/// nothing says "a one-finger drag magnifies instead of turning the page" —
/// and a second pill would eat the chapter title, which already ellipsizes.
/// The pill was a menu opener rather than a toggle, so a cog costs no extra
/// tap; what it loses is the direction glyph visible in the bar, and the
/// chrome is hidden while reading anyway, so that glance is only ever had by
/// someone who has just tapped for a control.
///
/// What the reader's sheet came back with.
///
/// Not a direction only, because the sheet can answer four other things: the
/// direction in force can be promoted to the library's own or to the
/// profile's own default, and a library's or a series' own direction can be
/// dropped. All four are answers rather than side-effects for the one reason
/// the direction was: the sheet has no series or library id of its own to
/// write against, and the reader has both in hand.
sealed class ReaderSettingsOutcome {
  const ReaderSettingsOutcome();
}

/// A direction was picked: it becomes the series being read's own.
final class DirectionPicked extends ReaderSettingsOutcome {
  const DirectionPicked(this.direction);

  final ReadingDirection direction;
}

/// The direction in force was made the one every series in this library opens
/// in (#65): one tap, for a library the guess gets wrong wholesale.
final class DirectionPromotedToLibrary extends ReaderSettingsOutcome {
  const DirectionPromotedToLibrary();
}

/// The series being read's own direction was dropped: it follows the default
/// again.
final class SeriesDirectionCleared extends ReaderSettingsOutcome {
  const SeriesDirectionCleared();
}

/// The library being read in's own direction was dropped: its series follow
/// what stands below it again.
final class LibraryDirectionCleared extends ReaderSettingsOutcome {
  const LibraryDirectionCleared();
}

/// A sheet rather than a `PopupMenuButton`: a [PopupMenuItem] pops its route
/// when tapped, so a switch inside one dismisses the menu as it is flipped.
Future<ReaderSettingsOutcome?> showReaderSettingsSheet(
  BuildContext context, {
  required ChapterDirection direction,
  required String libraryName,
}) async {
  final outcome = await showModalBottomSheet<ReaderSettingsOutcome>(
    context: context,
    backgroundColor: patraSurface,
    // Everything the sheet draws is read off [sheetContext], the context of
    // the sheet's own route — never off [context], which belongs to the cog
    // that opened it. The chrome that cog lives in is dismissed by the very
    // act of picking a direction, and the sheet outlives it: a sheet that
    // kept hold of the context it was opened with looks an ancestor up on a
    // deactivated element the next time it is asked to draw itself, which on
    // a phone is the next change of the window's metrics.
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      // What the library is called in the rows below — the server's own word,
      // which arrives with the library list. There is a moment where it has
      // not: a chapter opened before that list has landed still has a library
      // id, and a row trailing off into "the default for" is worse than one
      // saying "this library".
      final libraryLabel = libraryName.isNotEmpty
          ? libraryName
          : l10n.thisLibrary;
      return SafeArea(
        // Scrollable, because three rows of settings no longer fit the nine
        // sixteenths of the screen a sheet is given on the shortest phone: a
        // column that overflows there is a row nobody can see.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DirectionSection(
                direction: direction,
                libraryLabel: libraryLabel,
                forBook: false,
                onOutcome: (outcome) => Navigator.of(sheetContext).pop(outcome),
              ),
              const Divider(height: 24, indent: gutter, endIndent: gutter),
              _MagnifyRow(direction: direction.direction),
              const Divider(height: 24, indent: gutter, endIndent: gutter),
              // The width is inert in exactly the directions magnifying's is
              // not: a strip is laid out at one, and paging fits a page to the
              // screen instead.
              _WidthFactorRow(inert: !direction.direction.isVerticalScroll),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
  return outcome;
}

/// The reading direction, in either sheet: where the one in force came
/// from, the directions to pick from, and the one-shot actions on the rungs.
///
/// One widget for both sheets because the chain is one chain (ADR-0007): a
/// book resolves its direction through the same rungs a chapter of pictures
/// does (#118), and a way to write them that was worded twice would drift.
/// What differs for a book is said by [forBook] and nowhere else — it turns
/// in two directions, not three, and its detected rung is what it declared.
///
/// Every row here is one-shot and answers through [onOutcome]: the sheet has
/// no series or library id to write against, and the reader has both.
class _DirectionSection extends StatelessWidget {
  const _DirectionSection({
    required this.direction,
    required this.libraryLabel,
    required this.forBook,
    required this.onOutcome,
  });

  final ChapterDirection direction;

  /// The library's name, as the rows word it.
  final String libraryLabel;

  /// Whether what is being read is a book (#121). A book's pages are turned,
  /// never scrolled as a strip, so it is offered two directions, and every
  /// direction the sheet names is the one the book really turns in
  /// ([ReadingDirection.forBook]) — a series or a shelf set to vertical
  /// scrolling reads as the left to right the reader opens a book in.
  final bool forBook;

  final ValueChanged<ReaderSettingsOutcome> onOutcome;

  ReadingDirection _shown(ReadingDirection value) =>
      forBook ? value.forBook : value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetLabel(l10n.readingDirection),
        // Where the direction in force came from: a checked row on its own
        // reads as "I chose this", which a guess or a declaration is not.
        _ProvenanceLine(
          direction: direction,
          libraryLabel: libraryLabel,
          forBook: forBook,
        ),
        _DirectionRows(
          // What a book can turn in is what `forBook` makes of every
          // direction, so the two cannot drift apart.
          options: {
            for (final option in ReadingDirection.values) _shown(option),
          }.toList(),
          current: _shown(direction.direction),
          onPicked: (option) => onOutcome(DirectionPicked(option)),
        ),
        // The actions below are one-shot, like picking a direction: each is a
        // single thing done to the choice in force, and none is a switch that
        // has to be turned back off. So all of them close the sheet, where the
        // sliders and switches stay open. They come as two pairs — what can be
        // promoted, then what can be dropped — and the library's row leads
        // each pair, since it is the rung they are about.
        // For a book, only where the shelf would turn it differently: a
        // series scrolled as a strip on a shelf read left to right turns a
        // book left to right either way, and a promotion that changes nothing
        // would close the sheet having done nothing.
        if (forBook
            ? direction.library?.forBook != _shown(direction.direction)
            : direction.canPromoteToLibrary)
          _ActionRow(
            icon: Icons.grid_view_outlined,
            label: l10n.promoteLibraryDirection(libraryLabel),
            onTap: () => onOutcome(const DirectionPromotedToLibrary()),
          ),
        if (direction.hasLibraryDirection)
          _ActionRow(
            icon: Icons.restart_alt,
            label: l10n.followDefaultDirectionForLibrary(libraryLabel),
            landing: _shown(direction.withoutLibrary).label(l10n),
            onTap: () => onOutcome(const LibraryDirectionCleared()),
          ),
        if (direction.hasSeriesDirection)
          _ActionRow(
            icon: Icons.restart_alt,
            label: l10n.followDefaultDirection,
            // For a book this may land on what the book declares, which is
            // the right answer: the default for a book is the book's word.
            landing: _shown(direction.withoutSeries).label(l10n),
            onTap: () => onOutcome(const SeriesDirectionCleared()),
          ),
      ],
    );
  }
}

/// Where the direction in force came from: this series' own, this library's,
/// detected from the work — or, for a book, declared by it — or the built-in
/// left-to-right.
class _ProvenanceLine extends StatelessWidget {
  const _ProvenanceLine({
    required this.direction,
    required this.libraryLabel,
    required this.forBook,
  });

  final ChapterDirection direction;

  /// The library's name, as the rows word it.
  final String libraryLabel;

  /// Whether the detected rung is a book's declaration rather than a
  /// measurement: for a book it is what the book said of itself (#118), and
  /// "detected" undersold it.
  final bool forBook;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The one in force, named as what is being read really turns in it.
    final shown = forBook ? direction.direction.forBook : direction.direction;
    final label = shown.label(l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
      child: Text(switch (direction.source) {
        ReadingDirectionSource.series => l10n.directionSourceSeries(label),
        ReadingDirectionSource.library => l10n.directionSourceLibrary(
          label,
          libraryLabel,
        ),
        ReadingDirectionSource.detected =>
          forBook
              ? l10n.directionSourceBook(label)
              : l10n.directionSourceDetected(label),
        ReadingDirectionSource.builtIn => l10n.directionSourceBuiltIn(label),
      }, style: PatraText.metadata(color: patraTextMuted)),
    );
  }
}

/// One row of the sheet that does a single thing to the direction in force and
/// closes the sheet doing it.
///
/// Four of them — promoting to the library's own or to the profile's, and
/// dropping either — and they are one widget because what they share is not
/// their wording but their behaviour: each is one thing done to the choice in
/// force, and none is a switch that has to be turned back off, so all of them
/// dismiss the sheet where the magnifying switch and the width slider stay
/// open. What each one is *for* is said where it is drawn, beside the
/// condition that draws it.
///
/// Promoting does not clear the rung below: one tap, one thing, and the way
/// back from the series stays free because it now lands on the same value
/// (ADR-0007). Both promotions are drawn only where the direction in force is
/// not that rung's already — and where the rung holds nothing at all they are
/// drawn for any direction, which is what lets a detected direction become
/// somebody's rather than being the one thing that can never outrank nothing.
/// Both ways back are worded with the direction the chapter will really open
/// in, because "follow the default" is not much of a promise without saying
/// which one, and it may be the library's own, the profile's own, or a
/// direction detected from the work.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.landing,
  });

  final IconData icon;

  /// What the row does. Not worded with the direction: the line above the
  /// three rows already names the one in force, and the row it is checked on
  /// shows it — and a label that starts with a capital does not sit
  /// mid-sentence in either language anyway.
  final String label;

  /// The direction the chapter lands on once the row is tapped, where the row
  /// has one to name.
  final String? landing;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, size: 22, color: patraText),
    title: Text(label, style: PatraText.body()),
    trailing: landing == null
        ? null
        : Text(landing!, style: PatraText.metadata()),
    onTap: onTap,
  );
}

/// The directions, as rows: all three for a chapter of pictures, the two a
/// book can turn in for a book.
///
/// It used to be shared with Settings' own picker, so the two could not drift
/// into wording the choice differently (#58). Settings has no reading section
/// now, so it is the reader's alone, and both of its sheets draw it.
class _DirectionRows extends StatelessWidget {
  const _DirectionRows({
    required this.options,
    required this.current,
    required this.onPicked,
  });

  final List<ReadingDirection> options;
  final ReadingDirection current;
  final ValueChanged<ReadingDirection> onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in options)
          ListTile(
            leading: DirectionIcon(
              option,
              color: option == current ? patraAccent : patraText,
            ),
            title: Text(
              option.label(l10n),
              style: PatraText.body(
                color: option == current ? patraAccent : patraText,
              ),
            ),
            trailing: option == current
                ? const Icon(Icons.check, color: patraAccent, size: 18)
                : null,
            onTap: () => onPicked(option),
          ),
      ],
    );
  }
}

/// Magnifying, in the reader's own sheet.
///
/// Writes the preference straight through rather than overriding it for this
/// chapter, which is the one way it deliberately differs from the direction
/// above it: a direction belongs to the book, and this belongs to the hand.
/// Made per-chapter it would forget itself every time a chapter was opened.
///
/// It stays switchable while reading vertically, where the gesture is inert —
/// the preference is global and the next chapter may well be paged, so
/// refusing the switch would be refusing to set it for anywhere else. What it
/// must not do is sit there reading "on" and quietly do nothing, so the line
/// under it says so.
class _MagnifyRow extends ConsumerWidget {
  const _MagnifyRow({required this.direction});

  final ReadingDirection direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final magnify = ref.watch(magnifyProvider);
    final inert = direction.isVerticalScroll;
    void set(bool on) => ref.read(magnifyProvider.notifier).set(on);

    return MergeSemantics(
      child: ListTile(
        leading: Icon(
          Icons.zoom_in,
          size: 22,
          color: magnify && !inert ? patraAccent : patraText,
        ),
        title: Text(
          l10n.dragToMagnify,
          style: PatraText.body(
            color: magnify && !inert ? patraAccent : patraText,
          ),
        ),
        subtitle: Text(
          inert ? l10n.dragToMagnifyInVertical : l10n.dragToMagnifyExplained,
          style: PatraText.metadata(color: inert ? patraDanger : null),
        ),
        trailing: Switch(value: magnify, onChanged: set),
        // The sheet stays open: unlike picking a direction, this is a switch,
        // and a switch that closed the surface it lives on could never be
        // turned back off without reopening it.
        onTap: () => set(!magnify),
      ),
    );
  }
}

/// How wide a chapter opens, as a fraction of the screen: the whole of it at
/// `1.0`, which is how a chapter has opened all along.
///
/// Set here and nowhere else (#58): Settings used to carry a row for it, and
/// the reader is where somebody notices they want one — the width is the page
/// under their eyes, and this sheet is already open over it.
/// A slider and not a switch, because this is a number a person picks rather
/// than a thing that is on or off. The range it slides over is
/// `StripGeometry`'s and not this row's — a pinch moves the same number and
/// the two must not clamp it differently.
///
/// Where it does not apply it **says so** in place of its explanation and
/// stays settable, which is the magnifying row's rule mirrored: the paged
/// directions fit a page to the screen rather than laying a strip out at a
/// width of its own, but the preference belongs to the person and not to the
/// chapter, and the next one may well be read vertically. A slider sitting at
/// 70% while the screen is drawn full width, with nothing saying why, would
/// be the worst of both.
class _WidthFactorRow extends ConsumerWidget {
  const _WidthFactorRow({required this.inert});

  /// Whether the width is inert where this row is drawn — the paged
  /// directions, where no strip is laid out at one.
  final bool inert;

  /// Ten divisions over the range: one stop every five per cent.
  static const _divisions = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final factor = ref.watch(widthFactorProvider);
    final percent = l10n.percent((factor * 100).round());
    final notifier = ref.read(widthFactorProvider.notifier);

    return _NumberRow(
      icon: Icons.width_normal,
      label: l10n.pageWidth,
      // Where it does not apply it **says so** in place of its explanation
      // and stays settable, which is the magnifying row's rule mirrored: the
      // paged directions fit a page to the screen rather than laying a strip
      // out at a width of its own, but the preference belongs to the person
      // and not to the chapter, and the next one may well be read
      // vertically. A slider sitting at 70% while the screen is drawn full
      // width, with nothing saying why, would be the worst of both.
      explained: inert ? l10n.pageWidthInPaged : l10n.pageWidthExplained,
      value: factor,
      defaultValue: StripGeometry.maxWidthFactor,
      min: StripGeometry.minWidthFactor,
      max: StripGeometry.maxWidthFactor,
      divisions: _divisions,
      display: percent,
      semantic: (value) => l10n.percent((value * 100).round()),
      onPreview: notifier.preview,
      onSet: notifier.set,
      inert: inert,
    );
  }
}

/// The reader's settings **for a book**: how the words are set, the direction
/// the book turns in, and nothing about pictures.
///
/// With no page sizes there is nothing to pair into a spread, no strip to lay
/// out at a width of its own, and no page for a magnifying gesture to carry —
/// so the sheet a book's cog opens offers none of them (#75). What is left is
/// the type: how large the words are, how much room there is between the
/// lines, and the face they are set in (#92). All three are one choice for
/// **every** book, and all three belong to the person reading rather than to
/// the work, because what is being chosen is how somebody reads.
///
/// All three are written straight through to the profile the way the width
/// is, and the sheet stays open over the page it is changing.
///
/// **Under them, the direction** (#121) — the one thing here about the work
/// rather than the person, and so the one thing that comes back: the chain a
/// book turns through has a series' rung and a library's, both choices, and
/// without a row a direction a book inherited from a shelf of scans, or read
/// wrongly off its own stylesheet, had no way back. It is last because it is
/// nearly always right and is there to be corrected, and it is one-shot like
/// the picture sheet's: picking one closes the sheet with an answer.
Future<ReaderSettingsOutcome?> showBookSettingsSheet(
  BuildContext context, {
  required ChapterDirection direction,
  required String libraryName,
  String? bookFamily,
}) => showModalBottomSheet<ReaderSettingsOutcome>(
  context: context,
  backgroundColor: patraSurface,
  // Lighter than a sheet's usual scrim: the page behind reflows with every
  // change made here, and is the preview of it.
  barrierColor: patraLightScrim,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard)),
  ),
  // Everything the sheet draws is read off [sheetContext], the context of
  // the sheet's own route — never off [context], which belongs to the
  // button that opened it and leaves the tree when the chrome does.
  builder: (sheetContext) {
    final l10n = AppLocalizations.of(sheetContext);
    return SafeArea(
      child: ConstrainedBox(
        // Never over the whole page: what the sheet changes is behind it.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 10, bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SheetHandle()),
              _BookSection(
                first: true,
                label: l10n.bookTextSize,
                caption: l10n.bookTextSizeExplained,
                child: const BookTextSizeControl(),
              ),
              _BookSection(
                label: l10n.bookLineSpacing,
                caption: l10n.bookLineSpacingExplained,
                child: const BookSpacingControl(),
              ),
              _BookSection(
                label: l10n.bookReadingFace,
                // The rows run the whole width, so the section only heads
                // them.
                inset: false,
                child: BookFaceRows(bookFamily: bookFamily),
              ),
              BookDirectionSection(
                direction: direction,
                libraryName: libraryName,
                onOutcome: (outcome) => Navigator.of(sheetContext).pop(outcome),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

/// The rows under how a book is set: the direction it turns in (#121), the
/// one thing in a book's settings about the work rather than the person, and
/// so the one that comes back as an answer rather than being written.
class BookDirectionSection extends StatelessWidget {
  const BookDirectionSection({
    super.key,
    required this.direction,
    required this.libraryName,
    required this.onOutcome,
  });

  final ChapterDirection direction;
  final String libraryName;
  final ValueChanged<ReaderSettingsOutcome> onOutcome;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _DirectionSection(
      direction: direction,
      libraryLabel: libraryName.isNotEmpty ? libraryName : l10n.thisLibrary,
      forBook: true,
      onOutcome: onOutcome,
    );
  }
}

/// The grip at the top of a sheet: 32 by 4, in the outline.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 4,
    decoration: BoxDecoration(
      color: patraOutline.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(radiusTrack),
    ),
  );
}

/// One of a book's three settings in the phone's sheet: its heading, the
/// control, and the sentence saying what it changes.
class _BookSection extends StatelessWidget {
  const _BookSection({
    required this.label,
    required this.child,
    this.caption,
    this.inset = true,
    this.first = false,
  });

  /// The first section sits under the handle; the others keep 24 from the
  /// one above.
  final bool first;

  final String label;
  final Widget child;
  final String? caption;

  /// Whether the control sits at the gutter, like the heading, or runs the
  /// sheet's width as rows do.
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final caption = this.caption;
    return Padding(
      padding: EdgeInsets.only(top: first ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 10),
            child: SectionLabel(label),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: inset ? gutter : 0),
            child: child,
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
              child: Text(caption, style: _captionStyle),
            ),
        ],
      ),
    );
  }
}

final _captionStyle = PatraText.metadata(size: 12).copyWith(height: 1.45);

/// How large a book's words are, stepped by a smaller and a larger button
/// either side of the size itself.
///
/// Buttons rather than the slider this was: a size is changed a step at a
/// time while the page reflows behind, and a step is what a tap is. The
/// range is the setting's own (`reading_settings.dart`). On a tablet the
/// [compact] panel steps two points a tap and names the setting under the
/// size, the panel having no captions.
class BookTextSizeControl extends ConsumerWidget {
  const BookTextSizeControl({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final size = ref.watch(bookTextSizeProvider);
    final notifier = ref.read(bookTextSizeProvider.notifier);
    final step = compact ? 2 : 1;
    void change(int delta) =>
        notifier.set(steppedTextSize(size, delta, step: step));
    final value = l10n.textSizePoints(size.round());

    return Row(
      children: [
        _StepButton(
          label: compact ? 'A' : 'A−',
          size: compact ? 13 : 14,
          tooltip: l10n.textSmaller,
          onTap: size > minBookTextSize ? () => change(-1) : null,
        ),
        SizedBox(width: compact ? 8 : 12),
        Expanded(
          child: Semantics(
            label: '${l10n.bookTextSize}, $value',
            hint: l10n.bookTextSizeExplained,
            excludeSemantics: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: PatraText.rowTitle(size: compact ? 15 : 16)),
                if (compact)
                  Text(l10n.bookTextSize, style: PatraText.metadata()),
              ],
            ),
          ),
        ),
        SizedBox(width: compact ? 8 : 12),
        _StepButton(
          label: compact ? 'A' : 'A+',
          size: compact ? 20 : 18,
          tooltip: l10n.textLarger,
          onTap: size < maxBookTextSize ? () => change(1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.label,
    required this.size,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final double size;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusCover),
      side: const BorderSide(color: patraBorder),
    );
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: minHitTarget,
            child: Center(
              child: Text(
                label,
                style: PatraText.rowTitle(
                  size: size,
                  color: onTap == null ? patraTextMuted : patraText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The room between a book's lines, as three segments: tight, normal, loose.
///
/// A height left off the three by the slider this replaced names no segment
/// rather than the nearest, and the first tap puts it on one.
class BookSpacingControl extends ConsumerWidget {
  const BookSpacingControl({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = BookSpacing.of(ref.watch(bookLineHeightProvider));
    final notifier = ref.read(bookLineHeightProvider.notifier);
    String name(BookSpacing spacing) => switch (spacing) {
      BookSpacing.tight => l10n.spacingTight,
      BookSpacing.normal => l10n.spacingNormal,
      BookSpacing.loose => l10n.spacingLoose,
    };
    return Row(
      children: [
        for (final spacing in BookSpacing.values) ...[
          if (spacing != BookSpacing.values.first)
            SizedBox(width: compact ? 6 : 8),
          Expanded(
            child: _Segment(
              selected: spacing == current,
              tooltip: compact ? l10n.bookLineSpacingExplained : null,
              onTap: () => notifier.set(spacing.height),
              height: minHitTarget,
              builder: (color) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (compact) ...[
                    Icon(Icons.format_line_spacing, size: 16, color: color),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      name(spacing),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PatraText.rowTitle(
                        size: compact ? 12.5 : 14,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One choice among a few, drawn as a bordered box: in the accent where it is
/// the one in force.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.selected,
    required this.onTap,
    required this.height,
    required this.builder,
    this.tooltip,
    this.selectedFill = .14,
  });

  final bool selected;
  final VoidCallback onTap;
  final double height;
  final Widget Function(Color color) builder;
  final String? tooltip;
  final double selectedFill;

  @override
  Widget build(BuildContext context) {
    final color = selected ? patraAccent : patraText;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusCover),
      side: BorderSide(color: selected ? patraAccent : patraBorder),
    );
    final segment = Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? patraAccent.withValues(alpha: selectedFill)
            : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(height: height, child: builder(color)),
        ),
      ),
    );
    final tooltip = this.tooltip;
    return tooltip == null
        ? segment
        : Tooltip(message: tooltip, child: segment);
  }
}

/// The faces a book can be set in, one row each, every row composed in the
/// face it offers — the row is the sample, and it is why a row says what
/// kind of type it is rather than a family's name. The book's own row is set
/// in the face the book resolved to, the app's sans where it has none; the
/// check is kept on every row and only shown on the one in force, so a pick
/// moves nothing.
///
/// It is the one deliberate hole in the design system's serif rule: the serif
/// row, and the book's own row where the book ships a serif, are set in a
/// serif — see the reader's rules, where the hole is written down as one.
class BookFaceRows extends ConsumerWidget {
  const BookFaceRows({super.key, this.bookFamily});

  final String? bookFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final face = ref.watch(bookReadingFaceProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final offered in ReadingFace.values)
          InkWell(
            onTap: () =>
                ref.read(bookReadingFaceProvider.notifier).set(offered),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      offered.label(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          PatraText.body(
                            color: offered == face ? patraAccent : patraText,
                          ).copyWith(
                            fontSize: 16,
                            fontFamily: offered
                                .resolve(bookFamily: bookFamily)
                                .family,
                          ),
                    ),
                  ),
                  Opacity(
                    opacity: offered == face ? 1 : 0,
                    child: const Icon(
                      Icons.check,
                      size: 22,
                      color: patraAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The same faces as tiles, for the tablet's compact panel: "Aa" set in the
/// face over a short name, the full one in the tooltip.
class BookFaceTiles extends ConsumerWidget {
  const BookFaceTiles({super.key, this.bookFamily});

  final String? bookFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final face = ref.watch(bookReadingFaceProvider);
    return Row(
      children: [
        for (final offered in ReadingFace.values) ...[
          if (offered != ReadingFace.values.first) const SizedBox(width: 6),
          Expanded(
            child: _Segment(
              selected: offered == face,
              selectedFill: .10,
              height: 56,
              tooltip: offered.label(l10n),
              onTap: () =>
                  ref.read(bookReadingFaceProvider.notifier).set(offered),
              builder: (color) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Aa',
                    style: TextStyle(
                      fontFamily: offered
                          .resolve(bookFamily: bookFamily)
                          .family,
                      fontSize: 20,
                      color: color,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    offered.shortLabel(l10n),
                    style: PatraText.rowTitle(size: 10, color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The reader's settings for a book on a tablet: a panel under the button
/// that opened it rather than a sheet, with **no scrim** — the whole spread
/// stays in view and reflows with every tap, which is the preview.
///
/// Compact: no captions, which go into each control's tooltip or semantics
/// instead. The direction rows close it, as they close the sheet.
class BookSettingsPanel extends StatelessWidget {
  const BookSettingsPanel({
    super.key,
    required this.direction,
    required this.libraryName,
    required this.onOutcome,
    this.bookFamily,
  });

  final ChapterDirection direction;
  final String libraryName;
  final ValueChanged<ReaderSettingsOutcome> onOutcome;
  final String? bookFamily;

  static const width = 360.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      decoration: BoxDecoration(
        color: patraSurface,
        border: Border.all(color: patraBorder),
        borderRadius: BorderRadius.circular(radiusCard),
        boxShadow: [
          BoxShadow(
            color: patraPanelShadow,
            blurRadius: 36,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BookTextSizeControl(compact: true),
              const SizedBox(height: 12),
              const BookSpacingControl(compact: true),
              const SizedBox(height: 12),
              BookFaceTiles(bookFamily: bookFamily),
              const SizedBox(height: 4),
              BookDirectionSection(
                direction: direction,
                libraryName: libraryName,
                onOutcome: onOutcome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One number a person picks with a slider, in a sheet that stays open.
///
/// The width a chapter of pictures opens at: a row naming the choice, what
/// it changes, and the value it stands at — then a slider whose write
/// happens once, when the finger lifts. It drew a book's size and spacing
/// too, until those became a stepper and three segments
/// ([BookTextSizeControl], [BookSpacingControl]): a size is changed a step
/// at a time with the page reflowing behind, and a spacing is one of three.
class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.icon,
    required this.label,
    required this.explained,
    required this.value,
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.semantic,
    required this.onPreview,
    required this.onSet,
    this.inert = false,
  });

  final IconData icon;
  final String label;

  /// What the choice changes — or, where it changes nothing here, why.
  final String explained;

  final double value;

  /// What [value] is where nobody has chosen, which is also what the accent
  /// is measured against: it says "not the default", the way "on" is said
  /// for the switch above.
  final double defaultValue;

  final double min;
  final double max;
  final int divisions;

  /// The value in words, beside the label and on the slider's own bubble.
  final String display;

  /// The value said out loud, for every step the slider can stand on rather
  /// than only for the one it was left at.
  final String Function(double value) semantic;

  final ValueChanged<double> onPreview;
  final ValueChanged<double> onSet;

  /// Whether the number does nothing where this row is drawn. It stays
  /// settable all the same, and says why in place of its explanation: the
  /// preference belongs to the person and not to the chapter in front of
  /// them, and the next one may well be read the other way.
  final bool inert;

  @override
  Widget build(BuildContext context) {
    final chosen = !inert && value != defaultValue;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(
            icon,
            size: 22,
            color: chosen ? patraAccent : patraText,
          ),
          title: Text(
            label,
            style: PatraText.body(color: chosen ? patraAccent : patraText),
          ),
          subtitle: Text(
            explained,
            style: PatraText.metadata(color: inert ? patraDanger : null),
          ),
          // The number, because a slider alone says nothing about where it
          // is standing.
          trailing: Text(
            display,
            style: PatraText.metadata(color: chosen ? patraAccent : null),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 4),
          child: Slider(
            // Clamped for the slider's own sake: the range belongs to the
            // module the number is for, and a value outside it is a corrupt
            // row rather than a choice anybody made.
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            semanticFormatterCallback: semantic,
            // The page follows the finger; the keychain hears about it once,
            // when the finger lifts. A drag is dozens of steps and a
            // preference is one choice.
            onChanged: onPreview,
            onChangeEnd: onSet,
          ),
        ),
      ],
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 6),
    child: SectionLabel(text),
  );
}
