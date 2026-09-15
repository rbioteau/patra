import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/models.dart';
import '../../theme.dart';
import '../../widgets/chrome_pill.dart';

/// How far one step of the hierarchy is set in from the step above it.
const double _contentsIndent = 16;

/// The contents of the book being read, and the page chosen from them — or
/// null where the sheet was dismissed instead.
///
/// It is the server's own list, read out of the file's navigation: a tree of
/// parts and their children, each with the page it begins on. Nothing is
/// derived from it and nothing is added to it, because the shape of a book is
/// the one thing about it this app cannot know better than the server does
/// (ADR-0008).
///
/// Offered only where there is something to offer: a book with no contents
/// has no control drawn for one at all, rather than a sheet saying so.
Future<int?> showBookContentsSheet(
  BuildContext context, {
  required List<BookContentsEntry> entries,
}) => showModalBottomSheet<int>(
  context: context,
  backgroundColor: patraSurface,
  // Everything the sheet draws is read off [sheetContext], the context of the
  // sheet's own route — never off [context], which belongs to the chrome it
  // was opened from and leaves the tree the moment that chrome does.
  builder: (sheetContext) => SafeArea(
    // Scrollable, because a book's contents are as long as the book has
    // parts: a chapter of a novel a line each is a list taller than the
    // screen, and a row nobody can reach is not an entry in a contents.
    child: SingleChildScrollView(child: _ContentsList(entries: entries)),
  ),
);

class _ContentsList extends StatelessWidget {
  const _ContentsList({required this.entries});

  final List<BookContentsEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 6),
          child: SectionLabel(l10n.bookContents),
        ),
        ..._rows(context, entries, 0),
      ],
    );
  }
}

/// One entry and everything nested under it, in the order the server sent
/// them.
///
/// The nesting is kept and drawn rather than flattened into one list: which
/// chapter belongs to which part is the whole of what a contents is for, and
/// the server is the only thing that knows it.
List<Widget> _rows(
  BuildContext context,
  List<BookContentsEntry> entries,
  int depth,
) => [
  for (final entry in entries)
    // An entry that says nothing and holds nothing is not an entry: Kavita
    // writes an empty title where the file's navigation carried none, and a
    // row that cannot be named cannot be chosen either.
    if (entry.title.isNotEmpty || entry.children.isNotEmpty) ...[
      _EntryRow(entry: entry, depth: depth),
      ..._rows(context, entry.children, depth + 1),
    ],
];

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.depth});

  final BookContentsEntry entry;

  /// How many entries deep this one sits, which is how far it is set in.
  final int depth;

  @override
  Widget build(BuildContext context) => ListTile(
    // The hierarchy is an indent rather than a heading: a part is not a
    // section of the sheet, it is the parent of the rows beneath it, and a
    // label saying so above them is a label where the indent already does
    // the work.
    contentPadding: EdgeInsets.only(
      left: gutter + depth * _contentsIndent,
      right: gutter,
    ),
    title: Text(
      entry.title,
      style: PatraText.body(color: depth == 0 ? patraText : patraTextMuted),
    ),
    // Where the entry begins, counted the way the reader's own counter
    // counts: the server numbers a book's pages from zero, so the page it
    // calls 5 is the one the counter calls 6.
    trailing: Text('${entry.page + 1}', style: PatraText.metadata()),
    onTap: () => Navigator.of(context).pop(entry.page),
  );
}

/// The reader's way into a book's contents: one control in the bottom chrome,
/// beside the page counter.
///
/// Worded rather than drawn, because the handoff's rule is that what a
/// control costs is said and never only pictured — and a list glyph alone is
/// a table of contents to one reader and a menu to another.
class BookContentsButton extends StatelessWidget {
  const BookContentsButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ChromePill(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.list, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            l10n.bookContents,
            style: PatraText.metadata(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
