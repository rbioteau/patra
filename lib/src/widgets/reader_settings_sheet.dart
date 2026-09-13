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
/// Not a direction only, because the sheet can answer two other things: the
/// direction in force can be promoted to the profile's own default, and a
/// series' own direction can be dropped. Both are answers rather than
/// side-effects for the one reason the direction was: the sheet has no series
/// id of its own to write against, and the reader has it in hand.
sealed class ReaderSettingsOutcome {
  const ReaderSettingsOutcome();
}

/// A direction was picked: it becomes the series being read's own.
final class DirectionPicked extends ReaderSettingsOutcome {
  const DirectionPicked(this.direction);

  final ReadingDirection direction;
}

/// The direction in force was made the reading profile's own default.
final class DirectionPromoted extends ReaderSettingsOutcome {
  const DirectionPromoted();
}

/// The series being read's own direction was dropped: it follows the default
/// again.
final class SeriesDirectionCleared extends ReaderSettingsOutcome {
  const SeriesDirectionCleared();
}

/// A sheet rather than a `PopupMenuButton`: a [PopupMenuItem] pops its route
/// when tapped, so a switch inside one dismisses the menu as it is flipped.
Future<ReaderSettingsOutcome?> showReaderSettingsSheet(
  BuildContext context, {
  required ChapterDirection direction,
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
    builder: (sheetContext) => SafeArea(
      // Scrollable, because three rows of settings no longer fit the nine
      // sixteenths of the screen a sheet is given on the shortest phone: a
      // column that overflows there is a row nobody can see.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetLabel(AppLocalizations.of(sheetContext).readingDirection),
            // Where the direction in force came from. Only the reader's sheet
            // carries it, because only the reader's sheet has a series in
            // hand — and a checked row on its own reads as "I chose this",
            // which a guess is not.
            _ProvenanceLine(direction: direction),
            ReadingDirectionRows(
              current: direction.direction,
              onPicked: (option) => Navigator.of(sheetContext).pop(
                DirectionPicked(option),
              ),
            ),
            // The two actions below are one-shot, like picking a direction:
            // each is a single thing done to the choice in force, and neither
            // is a switch that has to be turned back off. So both close the
            // sheet, where the magnifying switch and the width slider stay
            // open.
            if (direction.canPromote)
              _PromoteRow(
                onTap: () => Navigator.of(sheetContext).pop(
                  const DirectionPromoted(),
                ),
              ),
            if (direction.hasSeriesDirection)
              _FollowDefaultRow(
                landsOn: direction.withoutSeries,
                onTap: () => Navigator.of(sheetContext).pop(
                  const SeriesDirectionCleared(),
                ),
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
    ),
  );
  return outcome;
}

/// Where the direction in force came from: this series' own, the profile's
/// default, or detected from the work.
class _ProvenanceLine extends StatelessWidget {
  const _ProvenanceLine({required this.direction});

  final ChapterDirection direction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = direction.direction.label(l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
      child: Text(
        switch (direction.source) {
          ReadingDirectionSource.series => l10n.directionSourceSeries(label),
          ReadingDirectionSource.profile => l10n.directionSourceProfile(label),
          ReadingDirectionSource.detected => l10n.directionSourceDetected(
            label,
          ),
          ReadingDirectionSource.device => l10n.directionSourceDevice(label),
        },
        style: PatraText.metadata(color: patraTextMuted),
      ),
    );
  }
}

/// Making the direction in force the reading profile's own default.
///
/// Drawn only where it is not that already — and where the profile has
/// stored no default at all it is drawn for any direction, which is what lets
/// a detected direction become somebody's default rather than being the one
/// thing that can never outrank nothing.
///
/// It does not clear the series' own direction: one tap, one thing, and the
/// way back from the series stays free because it now lands on the same
/// value (ADR-0007).
class _PromoteRow extends StatelessWidget {
  const _PromoteRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.person_outline, size: 22, color: patraText),
      // Not worded with the direction: the line above the three rows already
      // names the one in force, and the row it is checked on shows it — and a
      // label that starts with a capital does not sit mid-sentence in either
      // language anyway.
      title: Text(l10n.promoteReadingDirection, style: PatraText.body()),
      onTap: onTap,
    );
  }
}

/// Dropping this series' own direction, so that it follows the default
/// again.
///
/// Worded with the direction the series will actually land on, resolved
/// through the chain — "follow the default" is not much of a promise without
/// saying which one — and worded **neutrally**, because what it lands on may
/// be the profile's own default or a direction detected from the work. The
/// row is why setting a series to the value the default already holds is not
/// the same as leaving it unset: a series that is set stops following a
/// default that later changes, and this is the way back.
class _FollowDefaultRow extends StatelessWidget {
  const _FollowDefaultRow({required this.landsOn, required this.onTap});

  /// The direction the series lands on once its own is dropped.
  final ReadingDirection landsOn;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.restart_alt, size: 22, color: patraText),
      title: Text(l10n.followDefaultDirection, style: PatraText.body()),
      trailing: Text(landsOn.label(l10n), style: PatraText.metadata()),
      onTap: onTap,
    );
  }
}

/// The three directions, as rows. Shared so the reader's sheet and the
/// Settings screen's picker cannot drift into wording each one differently.
class ReadingDirectionRows extends StatelessWidget {
  const ReadingDirectionRows({
    super.key,
    required this.current,
    required this.onPicked,
  });

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
    // The accent says "not the width a chapter opens at having never
    // chosen", the way it says "on" for the switch above.
    final notFullWidth = !inert && factor != StripGeometry.maxWidthFactor;
    final percent = l10n.percent((factor * 100).round());
    final notifier = ref.read(widthFactorProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(
            Icons.width_normal,
            size: 22,
            color: notFullWidth ? patraAccent : patraText,
          ),
          title: Text(
            l10n.pageWidth,
            style: PatraText.body(color: notFullWidth ? patraAccent : patraText),
          ),
          subtitle: Text(
            inert ? l10n.pageWidthInPaged : l10n.pageWidthExplained,
            style: PatraText.metadata(color: inert ? patraDanger : null),
          ),
          // The number, because a slider alone says nothing about where it
          // is standing.
          trailing: Text(
            percent,
            style: PatraText.metadata(color: notFullWidth ? patraAccent : null),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 4),
          child: Slider(
            // Clamped for the slider's own sake: the module clamps the strip,
            // and a value out of the range is a corrupt row rather than a
            // choice anybody made.
            value: factor.clamp(
              StripGeometry.minWidthFactor,
              StripGeometry.maxWidthFactor,
            ),
            min: StripGeometry.minWidthFactor,
            max: StripGeometry.maxWidthFactor,
            divisions: _divisions,
            label: percent,
            semanticFormatterCallback: (value) =>
                l10n.percent((value * 100).round()),
            // The chapter follows the finger; the keychain hears about it
            // once, when the finger lifts. A drag is dozens of steps and a
            // preference is one choice.
            onChanged: notifier.preview,
            onChangeEnd: notifier.set,
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
