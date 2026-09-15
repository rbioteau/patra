/// One page of a book, as this app draws it.
///
/// Kavita hands a book over one page of HTML at a time, its markup and its CSS
/// already scoped for a reader (ADR-0008), and that HTML is the server's
/// output — nothing here parses an EPUB, and nothing here is a browser. What
/// is taken apart is the handful of tags a page of a book is actually made of:
/// paragraphs, headings, quotations, list items and pictures. They are then set
/// in the app's own type on the app's own background, which is what a book
/// opened in this app is meant to look like — and which is also why a page is
/// drawn by us rather than handed to a web view: a web view's own `<img>` can
/// carry no header of ours, and a book's pictures are header-authenticated.
library;

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../theme.dart';

/// A run of words inside a block, and how the book set it.
class BookSpan {
  const BookSpan(this.text, {this.bold = false, this.italic = false});

  final String text;
  final bool bold;
  final bool italic;

  InlineSpan toSpan(TextStyle base) => TextSpan(
    text: text,
    style: base.copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    ),
  );
}

/// How one block of words is set.
enum BookBlockStyle { paragraph, heading, quotation, item }

/// A block a page is made of.
sealed class BookBlock {
  const BookBlock();
}

/// Words: a paragraph, a heading, a quotation, or an item of a list.
class BookWords extends BookBlock {
  const BookWords(this.spans, {this.style = BookBlockStyle.paragraph});

  final List<BookSpan> spans;
  final BookBlockStyle style;
}

/// A picture the page refers to, named the way the page's own HTML names it.
///
/// Not a URL: what a page says is a path inside the book, and turning it into
/// a request is the client's job (`KavitaClient.bookResourceUrl`).
class BookPicture extends BookBlock {
  const BookPicture(this.src);

  final String src;
}

/// One page of a book: the server's HTML, taken apart once.
class BookPage {
  const BookPage(this.blocks);

  final List<BookBlock> blocks;

  /// Nothing to draw is a page the server did not produce, whatever it
  /// answered with.
  bool get isEmpty => blocks.isEmpty;

  factory BookPage.fromHtml(String html) => BookPage(parseBookPage(html));
}

/// The size a book is set at.
///
/// Somebody's own reading size from #75 on; until then it is the size a page
/// of words is comfortable at, which is not the size the rest of the app's
/// copy is set at.
const double bookTextSize = 16;

/// The leading between a page's lines — the other half of what #75 makes a
/// choice, and the half that decides whether dense text is readable.
const double bookLineHeight = 1.55;

/// The room a page is set in.
///
/// The bottom is four times the top because the page counter sits there: a
/// page allowed to end under it is a page whose last line cannot be read.
const EdgeInsets _pagePadding = EdgeInsets.fromLTRB(
  gutter,
  gutter,
  gutter,
  4 * gutter,
);

/// One page of a book, read top to bottom.
class BookPageBody extends StatelessWidget {
  const BookPageBody({super.key, required this.page, required this.picture});

  final BookPage page;

  /// What a picture the page refers to is drawn with: a [BookPicture]'s own
  /// name in, a widget out. The reader owns it, because resolving that name
  /// into a request is the client's job and not a page's.
  final Widget Function(String src) picture;

  TextStyle get _paragraph => PatraText.body().copyWith(
    fontSize: bookTextSize,
    height: bookLineHeight,
    fontWeight: FontWeight.w400,
  );

  TextStyle get _heading => _paragraph.copyWith(
    fontSize: bookTextSize + 3,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  TextStyle get _quotation =>
      _paragraph.copyWith(color: patraTextMuted, fontStyle: FontStyle.italic);

  @override
  Widget build(BuildContext context) {
    // A page with nothing in it is a page the server did not produce, and it
    // says so rather than being a screen of nothing at all.
    if (page.isEmpty) return const BookPageUnavailable();
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: _pagePadding,
        child: ConstrainedBox(
          // A page is a page and not a flow: what the server laid out on one
          // is shorter than the screen more often than not — a cover, a
          // part's title, the last page of a chapter — and content that fits
          // is set in the middle of the page rather than left hanging off its
          // top edge. A page taller than the screen keeps the scroll it
          // already had, which is all a minimum height can leave it.
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - _pagePadding.vertical,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final block in page.blocks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: switch (block) {
                      BookWords() => _words(block),
                      BookPicture(:final src) => picture(src),
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _words(BookWords block) {
    final base = switch (block.style) {
      BookBlockStyle.paragraph || BookBlockStyle.item => _paragraph,
      BookBlockStyle.heading => _heading,
      BookBlockStyle.quotation => _quotation,
    };
    final words = Text.rich(
      TextSpan(children: [for (final span in block.spans) span.toSpan(base)]),
      // A page of a book is set justified, as the printed page it stands in
      // for is: both edges of the column are straight, which is what the eye
      // reads a block of prose by. Only the lines that break of their own
      // accord are stretched, so the last line of a paragraph stays where a
      // left-aligned one would be. A title is not prose and a list item is
      // a line, so neither is justified: stretching either would open holes
      // in a handful of words.
      textAlign: block.style == BookBlockStyle.paragraph ||
              block.style == BookBlockStyle.quotation
          ? TextAlign.justify
          : TextAlign.start,
    );
    return switch (block.style) {
      BookBlockStyle.item => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: base),
          Expanded(child: words),
        ],
      ),
      BookBlockStyle.quotation => Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: patraBorder, width: 2)),
        ),
        padding: const EdgeInsets.only(left: 12),
        child: words,
      ),
      _ => words,
    };
  }
}

/// A tag, or a comment. Anything else in a page is words.
final RegExp _markup = RegExp(r'<!--.*?-->|<[^>]*>', dotAll: true);

/// A bare tag name — `<p>`, `</P >`, `<br/>`, `<h2 class="x">`.
final RegExp _tagName = RegExp(r'<?/?\s*([a-zA-Z0-9]+)');

/// `src="OEBPS/images/cover.jpg"`, single-quoted, or bare.
final RegExp _attribute = RegExp(
  r'''([a-zA-Z-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))''',
);

/// `&amp;` and the four like it, plus numeric ones.
final RegExp _entity = RegExp(r'&(#\d+|#[xX][0-9a-fA-F]+|[a-zA-Z]+);');

const Map<String, String> _entities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'mdash': '—',
  'ndash': '–',
  'hellip': '…',
  'rsquo': '’',
  'lsquo': '‘',
  'rdquo': '”',
  'ldquo': '“',
};

/// Whitespace, including the newlines a file's own markup is full of.
final RegExp _runsOfSpace = RegExp(r'\s+');

/// The space a file's own indentation leaves either side of a `<br>`: only a
/// break the page asked for survives.
final RegExp _spaceAroundBreak = RegExp(r'[^\S\n]*\n[^\S\n]*');

/// Tags whose content is not words at all, and is dropped whole.
const Set<String> _dropped = {'script', 'style', 'head', 'title'};

/// Tags that end one block and begin the next, and how the next one is set.
const Map<String, BookBlockStyle> _blockTags = {
  'p': BookBlockStyle.paragraph,
  'div': BookBlockStyle.paragraph,
  'dt': BookBlockStyle.paragraph,
  'h1': BookBlockStyle.heading,
  'h2': BookBlockStyle.heading,
  'h3': BookBlockStyle.heading,
  'h4': BookBlockStyle.heading,
  'h5': BookBlockStyle.heading,
  'h6': BookBlockStyle.heading,
  'blockquote': BookBlockStyle.quotation,
  'li': BookBlockStyle.item,
};

/// The server's HTML, as the blocks a page is drawn from.
///
/// No tree is built and no CSS is honoured, which is the whole of what keeps
/// this small: Kavita has already scoped both, and a page is drawn in this
/// app's type rather than in the book's. Tags it does not know are transparent
/// — their words are kept and their layout is not, so a book that ships
/// something unusual reads as words rather than as nothing.
List<BookBlock> parseBookPage(String html) {
  final blocks = <BookBlock>[];
  var spans = <BookSpan>[];
  final words = StringBuffer();
  var bold = 0;
  var italic = 0;
  var style = BookBlockStyle.paragraph;

  /// The tag whose content is being dropped, until it closes.
  String? dropping;

  void keepWords() {
    if (words.isEmpty) return;
    // A break in the middle of a line keeps no space of its own: the words
    // either side of it are indented by the book's own markup, not by it.
    final text = words.toString().replaceAll(_spaceAroundBreak, '\n');
    spans.add(BookSpan(text, bold: bold > 0, italic: italic > 0));
    words.clear();
  }

  void endBlock([BookBlockStyle next = BookBlockStyle.paragraph]) {
    keepWords();
    // The indentation an EPUB's own markup carries is not the book's: a run
    // is trimmed where it meets the edge of its block and nowhere inside it,
    // so "Hello, <b>world</b>" keeps the space the two are joined by.
    if (spans.isNotEmpty) {
      _trimEdge(spans, 0, (text) => text.trimLeft());
      _trimEdge(spans, spans.length - 1, (text) => text.trimRight());
      if (spans.any((span) => span.text.isNotEmpty)) {
        blocks.add(BookWords(spans, style: style));
      }
    }
    spans = <BookSpan>[];
    style = next;
  }

  void write(String text) =>
      words.write(_decode(text).replaceAll(_runsOfSpace, ' '));

  var at = 0;
  while (at < html.length) {
    final markup = _markup.matchAsPrefix(html, at);
    if (markup == null) {
      // Words, up to the next tag.
      final next = html.indexOf('<', at);
      final end = next == -1 ? html.length : next;
      if (dropping == null) write(html.substring(at, end));
      at = end;
      continue;
    }
    final tag = markup.group(0)!;
    at = markup.end;
    if (tag.startsWith('<!--')) continue;

    final match = _tagName.firstMatch(tag);
    if (match == null) continue;
    final name = match.group(1)!.toLowerCase();
    final closing = tag.startsWith('</');

    if (dropping != null) {
      if (closing && name == dropping) dropping = null;
      continue;
    }
    if (!closing && _dropped.contains(name)) {
      dropping = name;
      continue;
    }

    final opens = _blockTags[name];
    if (opens != null) {
      endBlock(opens);
      continue;
    }
    switch (name) {
      case 'br':
        words.write('\n');
        break;
      case 'img' || 'image':
        // A picture sits between the words around it rather than inside a run
        // of them: what was said before it is its own block, so the page
        // keeps the order it was written in.
        final src = _attributeOf(tag, 'src') ?? _attributeOf(tag, 'href');
        endBlock();
        if (src != null && src.isNotEmpty) blocks.add(BookPicture(src));
        break;
      case 'b' || 'strong':
        // Flushed first, whichever way the tag goes: the words already
        // written were written at the weight that was in force.
        keepWords();
        bold = closing ? bold - 1 : bold + 1;
        if (bold < 0) bold = 0;
        break;
      case 'i' || 'em' || 'cite':
        keepWords();
        italic = closing ? italic - 1 : italic + 1;
        if (italic < 0) italic = 0;
        break;
    }
  }
  endBlock();
  return blocks;
}

/// What [tag] says [name] is, or null where it says nothing.
String? _attributeOf(String tag, String name) {
  for (final match in _attribute.allMatches(tag)) {
    if (match.group(1)!.toLowerCase() != name) continue;
    return match.group(2) ?? match.group(3) ?? match.group(4);
  }
  return null;
}

String _decode(String text) => text.replaceAllMapped(_entity, (match) {
  final body = match.group(1)!;
  if (body.startsWith('#')) {
    final code = body[1] == 'x' || body[1] == 'X'
        ? int.tryParse(body.substring(2), radix: 16)
        : int.tryParse(body.substring(1));
    if (code == null) return match.group(0)!;
    return String.fromCharCode(code);
  }
  return _entities[body] ?? match.group(0)!;
});

/// Trims one end of one run, in place, keeping how it is set.
void _trimEdge(List<BookSpan> spans, int index, String Function(String) trim) {
  final span = spans[index];
  final trimmed = trim(span.text);
  if (trimmed == span.text) return;
  spans[index] = BookSpan(trimmed, bold: span.bold, italic: span.italic);
}

/// What a page that is not there says.
///
/// A page the server could not produce is never an empty screen, which reads
/// as a book with no words in it.
class BookPageUnavailable extends StatelessWidget {
  const BookPageUnavailable({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(gutter),
        child: Text(
          AppLocalizations.of(context).bookPageUnavailable,
          textAlign: TextAlign.center,
          style: PatraText.body(color: patraTextMuted),
        ),
      ),
    );
  }
}
