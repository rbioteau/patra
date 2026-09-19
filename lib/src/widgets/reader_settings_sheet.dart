import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
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
              _SheetLabel(l10n.readingDirection),
              // Where the direction in force came from. Only the reader's sheet
              // carries it, because only the reader's sheet has a series in
              // hand — and a checked row on its own reads as "I chose this",
              // which a guess is not.
              _ProvenanceLine(direction: direction, libraryLabel: libraryLabel),
              _DirectionRows(
                current: direction.direction,
                onPicked: (option) =>
                    Navigator.of(sheetContext).pop(DirectionPicked(option)),
              ),
              // The actions below are one-shot, like picking a direction:
              // each is a single thing done to the choice in force, and none
              // is a switch that has to be turned back off. So all of them
              // close the sheet, where the magnifying switch and the width
              // slider stay open. They come as two pairs — what can be
              // promoted, then what can be dropped — and the library's row
              // leads each pair, since it is the rung they are about.
              if (direction.canPromoteToLibrary)
                _ActionRow(
                  icon: Icons.grid_view_outlined,
                  label: l10n.promoteLibraryDirection(libraryLabel),
                  onTap: () =>
                      Navigator.of(sheetContext)
                          .pop(const DirectionPromotedToLibrary()),
                ),
              if (direction.hasLibraryDirection)
                _ActionRow(
                  icon: Icons.restart_alt,
                  label: l10n.followDefaultDirectionForLibrary(libraryLabel),
                  landing: direction.withoutLibrary.label(l10n),
                  onTap: () =>
                      Navigator.of(sheetContext)
                          .pop(const LibraryDirectionCleared()),
                ),
              if (direction.hasSeriesDirection)
                _ActionRow(
                  icon: Icons.restart_alt,
                  label: l10n.followDefaultDirection,
                  landing: direction.withoutSeries.label(l10n),
                  onTap: () =>
                      Navigator.of(sheetContext)
                          .pop(const SeriesDirectionCleared()),
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

/// Where the direction in force came from: this series' own, this library's,
/// detected from the work, or the built-in left-to-right.
class _ProvenanceLine extends StatelessWidget {
  const _ProvenanceLine({required this.direction, required this.libraryLabel});

  final ChapterDirection direction;

  /// The library's name, as the rows word it.
  final String libraryLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = direction.direction.label(l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
      child: Text(switch (direction.source) {
        ReadingDirectionSource.series => l10n.directionSourceSeries(label),
        ReadingDirectionSource.library => l10n.directionSourceLibrary(
          label,
          libraryLabel,
        ),
        ReadingDirectionSource.detected => l10n.directionSourceDetected(label),
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

/// The three directions, as rows.
///
/// It used to be shared with Settings' own picker, so the two could not drift
/// into wording the choice differently (#58). Settings has no reading section
/// now, so it is the reader's alone and private to its sheet.
class _DirectionRows extends StatelessWidget {
  const _DirectionRows({required this.current, required this.onPicked});

  final ReadingDirection current;
  final ValueChanged<ReadingDirection> onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in ReadingDirection.values)
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

/// The reader's settings **for a book**, and the only ones: how the words are
/// set, and nothing about pictures.
///
/// Which way pages turn is a question about pictures. With no page sizes
/// there is nothing for a detected direction to measure, nothing to pair into
/// a spread, no strip to lay out at a width of its own, and no page for a
/// magnifying gesture to carry — so the sheet a book's cog opens offers none
/// of them (#75). What is left is the type: how large the words are, how much
/// room there is between the lines, and the face they are set in (#92). All
/// three are one choice for **every** book, and all three belong to the
/// person reading rather than to the work, because what is being chosen is
/// how somebody reads.
///
/// Nothing comes back from it: all three are written straight through to the
/// profile the way the width is, and the sheet stays open over the page it is
/// changing.
Future<void> showBookSettingsSheet(
  BuildContext context, {
  String? bookFamily,
}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: patraSurface,
      // Everything the sheet draws is read off [sheetContext], the context of
      // the sheet's own route — never off [context], which belongs to the cog
      // that opened it and leaves the tree when the chrome does.
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BookTextSizeRow(),
              Divider(height: 24, indent: gutter, endIndent: gutter),
              _BookLineSpacingRow(),
              Divider(height: 24, indent: gutter, endIndent: gutter),
              _BookReadingFaceRow(bookFamily: bookFamily),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

/// One number a person picks with a slider, in a sheet that stays open.
///
/// The size a book is set at, the room between its lines, and the width a
/// chapter opens at are three numbers chosen the same way: a row naming the
/// choice, what it changes, and the value it stands at — then a slider whose
/// write happens once, when the finger lifts. What they share is not the
/// shape of the value but everything around it, so one row draws all three
/// rather than three rows that could drift apart.
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

/// How large the words of a book are, for whoever is reading.
///
/// The range it slides over is the setting's own (`reading_settings.dart`)
/// and not this row's, so every surface that sets a size sets the same one.
class _BookTextSizeRow extends ConsumerWidget {
  const _BookTextSizeRow();

  /// One point a step over the range: small print at one end, and a book
  /// held at arm's length at the other.
  static const _divisions = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final size = ref.watch(bookTextSizeProvider);
    final notifier = ref.read(bookTextSizeProvider.notifier);
    return _NumberRow(
      icon: Icons.format_size,
      label: l10n.bookTextSize,
      explained: l10n.bookTextSizeExplained,
      value: size,
      defaultValue: defaultBookTextSize,
      min: minBookTextSize,
      max: maxBookTextSize,
      divisions: _divisions,
      display: l10n.textSizePoints(size.round()),
      semantic: (value) => l10n.textSizePoints(value.round()),
      onPreview: notifier.preview,
      onSet: notifier.set,
    );
  }
}

/// The room between a book's lines, as a share of the size of its words.
///
/// The half of the same choice that decides whether dense text is readable,
/// and the one shown as a percentage: a leading *is* a share of the type
/// size, which is what a typographer means by 155%.
class _BookLineSpacingRow extends ConsumerWidget {
  const _BookLineSpacingRow();

  /// A twentieth of the range a step: a line pressed against the next at one
  /// end, and a page of air at the other.
  static const _divisions = 16;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final height = ref.watch(bookLineHeightProvider);
    final percent = l10n.percent((height * 100).round());
    final notifier = ref.read(bookLineHeightProvider.notifier);
    return _NumberRow(
      icon: Icons.format_line_spacing,
      label: l10n.bookLineSpacing,
      explained: l10n.bookLineSpacingExplained,
      value: height,
      defaultValue: defaultBookLineHeight,
      min: minBookLineHeight,
      max: maxBookLineHeight,
      divisions: _divisions,
      display: percent,
      semantic: (value) => l10n.percent((value * 100).round()),
      onPreview: notifier.preview,
      onSet: notifier.set,
    );
  }
}

/// The face a book is set in, for whoever is reading: the third row a book's
/// sheet offers, and the one that is not a number.
///
/// Three choices, not four families: the reader chooses a kind of type, not a
/// font by name. Each row says what kind of type it is ("The book's own",
/// "Serif", "Sans serif") and is **composed in the face it offers** — that is
/// the sample, and it is why the name is gone. The book's own row is set in
/// the family the book shipped (or the app's sans where it shipped none), so a
/// reader sees exactly what "the book's own" means for this book.
///
/// It is the one deliberate hole in the design system's serif rule: the serif
/// row, and the book's own row where the book ships a serif, are set in a
/// serif. The rule's purpose is to keep the wordmark and the titles of works
/// distinct from everything else, and a page of prose puts neither at risk —
/// see the reader's rules, where the hole is written down as one.
class _BookReadingFaceRow extends ConsumerWidget {
  const _BookReadingFaceRow({this.bookFamily});

  final String? bookFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final face = ref.watch(bookReadingFaceProvider);
    final chosen = face != defaultBookReadingFace;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(
            Icons.font_download,
            size: 22,
            color: chosen ? patraAccent : patraText,
          ),
          title: Text(
            l10n.bookReadingFace,
            style: PatraText.body(color: chosen ? patraAccent : patraText),
          ),
          subtitle: Text(
            l10n.bookReadingFaceExplained,
            style: PatraText.metadata(),
          ),
        ),
        for (final offered in ReadingFace.values)
          _FaceOption(
            face: offered,
            selected: offered == face,
            bookFamily: bookFamily,
            onPick: () =>
                ref.read(bookReadingFaceProvider.notifier).set(offered),
          ),
      ],
    );
  }
}

/// One of the faces a book can be set in, composed in the face it offers.
///
/// The row is not named after a font — it says what kind of type it is, and
/// the row itself is the sample. The family is resolved once through
/// [ReadingFace.resolve], which is the only place the fallback is decided.
class _FaceOption extends StatelessWidget {
  const _FaceOption({
    required this.face,
    required this.selected,
    required this.bookFamily,
    required this.onPick,
  });

  final ReadingFace face;
  final bool selected;
  final String? bookFamily;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolved = face.resolve(bookFamily: bookFamily);
    return ListTile(
      onTap: onPick,
      // As wide as the header's own icon, so the three names line up under
      // the row they belong to rather than under its leading edge.
      leading: SizedBox(
        width: 22,
        child: selected
            ? Icon(Icons.check, size: 18, color: patraAccent)
            : null,
      ),
      title: Text(
        face.label(l10n),
        // Set in the face it is offering: choosing a face one cannot see is
        // a choice made on its name alone.
        style: PatraText.body(color: selected ? patraAccent : patraText)
            .copyWith(fontFamily: resolved.family),
      ),
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
