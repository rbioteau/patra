import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
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
/// A sheet rather than a `PopupMenuButton`: a [PopupMenuItem] pops its route
/// when tapped, so a switch inside one dismisses the menu as it is flipped.
/// It is also the shape Settings already uses for the same choice.
Future<void> showReaderSettingsSheet(
  BuildContext context, {
  required ReadingDirection direction,
  required ValueChanged<ReadingDirection> onDirectionChanged,
}) async {
  final picked = await showModalBottomSheet<ReadingDirection>(
    context: context,
    backgroundColor: patraSurface,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetLabel(AppLocalizations.of(context).readingDirection),
          ReadingDirectionRows(
            current: direction,
            onPicked: (option) => Navigator.of(sheetContext).pop(option),
          ),
          const Divider(height: 24, indent: gutter, endIndent: gutter),
          const _MagnifyRow(),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (picked != null) onDirectionChanged(picked);
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
class _MagnifyRow extends ConsumerWidget {
  const _MagnifyRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final magnify = ref.watch(magnifyProvider);
    void set(bool on) => ref.read(magnifyProvider.notifier).set(on);

    return MergeSemantics(
      child: ListTile(
        leading: Icon(
          Icons.zoom_in,
          size: 22,
          color: magnify ? patraAccent : patraText,
        ),
        title: Text(
          l10n.dragToMagnify,
          style: PatraText.body(color: magnify ? patraAccent : patraText),
        ),
        subtitle: Text(l10n.dragToMagnifyExplained, style: PatraText.metadata()),
        trailing: Switch(value: magnify, onChanged: set),
        // The sheet stays open: unlike picking a direction, this is a switch,
        // and a switch that closed the surface it lives on could never be
        // turned back off without reopening it.
        onTap: () => set(!magnify),
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
