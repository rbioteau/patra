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

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'book_face.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/reading_settings.dart';
import '../../theme.dart';
/// A run of words inside a block, and how the book set it.
class BookSpan {
  const BookSpan(this.text, {this.bold = false, this.italic = false});

  final String text;
  final bool bold;
  final bool italic;

  /// [face] is the face the page is set in, and what decides whether this
  /// run's emphasis has an italic to be set in: where it has none — Space
  /// Grotesk has none at all — emphasis is set in the roman rather than in a
  /// slant the engine drew (#92).
  InlineSpan toSpan(TextStyle base, BookType face) => TextSpan(
    text: text,
    style: base.copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: italic && face.canSetItalic
          ? FontStyle.italic
          : FontStyle.normal,
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
  const BookPage(this.blocks, {this.face});

  final List<BookBlock> blocks;

  /// The face the page's own stylesheet asks for, or null if it asks for
  /// nothing. This is parsed once from the page's HTML and carried so that
  /// the reader can load and register the font before drawing.
  final BookFace? face;

  /// Nothing to draw is a page the server did not produce, whatever it
  /// answered with.
  bool get isEmpty => blocks.isEmpty;

  /// Every picture the page refers to, in the order it refers to them: what a
  /// copy of the page has to carry with it if it is to be read with no
  /// server left to ask.
  Iterable<String> get pictureSources =>
      blocks.whereType<BookPicture>().map((picture) => picture.src);

  factory BookPage.fromHtml(String html) =>
      BookPage(parseBookPage(html), face: parseBookFace(html));
}

/// What a stored page carries a picture as, in place of the name it named it
/// by: the bytes themselves, so that a page read with no server needs nothing
/// but the page (ADR-0009).
///
/// No media type is claimed, because the one thing that reads this — the
/// decoder — sniffs the bytes as it does for a stored page of pictures, and a
/// type the server did not state is not invented.
String carriedPictureName(List<int> bytes) =>
    'data:;base64,${base64Encode(bytes)}';

/// The bytes a name carries, where it is a picture a stored page brought with
/// it. Null for any other name, which is one the server is still needed for.
Uint8List? carriedPictureBytes(String src) {
  if (!src.startsWith('data:')) return null;
  final comma = src.indexOf(',');
  if (comma == -1) return null;
  try {
    return base64Decode(src.substring(comma + 1));
  } on FormatException {
    // A copy whose page was damaged on the way here keeps its words.
    return null;
  }
}

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

/// Where in a page of a book the reader is.
///
/// A page of a book can be longer than the screen, so where a reader is is a
/// page *and* a place within it — and the progress call Kavita's own web
/// client uses has always carried a marker for that place, `bookScrollId`, a
/// string the reader defines and the server hands back. That client fills it
/// with the id of an element in the page; there is no element in a page this
/// app draws (ADR-0010), so what travels is how far down the page the reader
/// is.
///
/// A fraction of the room there is to scroll, and not a number of points,
/// because a fraction survives being read somewhere else: a text size (#75),
/// a rotation and a differently sized window all move the words, and an
/// offset saved at one size opens at another place entirely at another.
@immutable
class BookAnchor {
  const BookAnchor(this.fraction);

  /// The top of a page: where every page with no marker opens, and where a
  /// reader arrives on a page they have just turned to.
  static const top = BookAnchor(0);

  /// 0 at the top of the page, 1 at the end of it.
  final double fraction;

  /// What the server is asked to remember.
  String get id => fraction.toStringAsFixed(4);

  /// What the server handed back, or null where it is not a place this app
  /// wrote — the web client's element ids among them, which name nothing in a
  /// page drawn here.
  static BookAnchor? from(String? id) {
    if (id == null) return null;
    final fraction = double.tryParse(id);
    if (fraction == null || !fraction.isFinite) return null;
    return BookAnchor(fraction.clamp(0.0, 1.0));
  }

  /// Where in a page [offset] is, of the [extent] there is to scroll.
  factory BookAnchor.at(double offset, double extent) => extent <= 0
      ? BookAnchor.top
      : BookAnchor((offset / extent).clamp(0.0, 1.0));
}

/// One page of a book, read top to bottom and set at the size whoever is
/// reading chose.
class BookPageBody extends StatefulWidget {
  const BookPageBody({
    super.key,
    required this.page,
    required this.picture,
    required this.textSize,
    required this.lineHeight,
    required this.face,
    this.anchor,
    this.onScroll,
  });

  final BookPage page;

  /// What a picture the page refers to is drawn with: a [BookPicture]'s own
  /// name in, a widget out. The reader owns it, because resolving that name
  /// into a request is the client's job and not a page's.
  final Widget Function(String src) picture;

  /// How large the words are set, in points: the reader's own, one number for
  /// every book (#75).
  final double textSize;

  /// The room between the lines, as a share of [textSize].
  final double lineHeight;

  /// The face the words are set in: the resolved family and whether it can
  /// set italic. This is a record so it compares by value, which lets
  /// [didUpdateWidget] carry the reader's place across a face change exactly
  /// as it does for a size change.
  ///
  /// The page counter stays in the app's serif — that is the app's own
  /// furniture and is unchanged.
  final BookType face;

  /// Where in the page the reader was, when it is opened again: null, or the
  /// top, for a page with nowhere to be but its beginning.
  final BookAnchor? anchor;

  /// How far down the page the reader has come to rest, told once a scroll
  /// has settled rather than on every frame of one — what is told is what
  /// travels to the server, and a post a frame is not a thing to ask for.
  final ValueChanged<BookAnchor>? onScroll;

  @override
  State<BookPageBody> createState() => _BookPageBodyState();
}

class _BookPageBodyState extends State<BookPageBody> {
  final ScrollController _scroll = ScrollController();

  /// Whether the page has been put where it opens.
  ///
  /// Opening a page halfway down is a scroll as well, and one the reader did
  /// not make: the place it lands on is the place the server already holds,
  /// so it is not told back until it has been made.
  var _placed = false;

  @override
  void initState() {
    super.initState();
    _place(widget.anchor);
  }

  @override
  void didUpdateWidget(BookPageBody old) {
    super.didUpdateWidget(old);
    // A page set at another size, or in another face, is a different page to
    // scroll through, and the place the reader is in it has to be carried
    // across rather than left where the words used to be: an offset is a
    // number of points, and the points are not the same words any more. So
    // it is read as a fraction before the words move — which is the whole of
    // why an anchor is a fraction — and put back once they have been laid
    // out again.
    if (old.textSize != widget.textSize ||
        old.lineHeight != widget.lineHeight ||
        old.face != widget.face) {
      _place(_here());
    }
  }

  /// Where in the page the reader is, as it stands.
  BookAnchor? _here() => _scroll.hasClients
      ? BookAnchor.at(_scroll.position.pixels, _scroll.position.maxScrollExtent)
      : widget.anchor;

  /// Puts the page where [anchor] is, once the words have been laid out.
  void _place(BookAnchor? anchor) {
    // Offsets are not a number until the page has been laid out, and a page
    // that opens at its top has nowhere to be put.
    if (anchor == null || anchor.fraction == 0) {
      _placed = true;
      return;
    }
    _placed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _open(anchor));
  }

  /// Puts the page where the reader left it.
  void _open(BookAnchor anchor) {
    if (mounted && _scroll.hasClients) {
      final extent = _scroll.position.maxScrollExtent;
      // A page that cannot be scrolled has nowhere to be put: nothing has
      // been laid out under it yet, or it is a page that fits.
      if (extent > 0) {
        _scroll.jumpTo((anchor.fraction * extent).clamp(0.0, extent));
      }
    }
    // Placed either way: a page with nowhere to be put — one that is gone, or
    // one that fits — is still a page the reader reads, and one that has to
    // go on reporting where they are.
    _placed = true;
  }

  /// How far down the page the reader is, now that a scroll has settled.
  void _settle() {
    final onScroll = widget.onScroll;
    if (!_placed || onScroll == null || !_scroll.hasClients) return;
    final position = _scroll.position;
    onScroll(BookAnchor.at(position.pixels, position.maxScrollExtent));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Every block of words on the page is set in the face the reader chose,
  /// and the face is what the whole page is set in: a book set in a serif
  /// with sans intertitres reads as an interface rather than as a book.
  TextStyle get _paragraph => PatraText.body().copyWith(
    fontFamily: widget.face.family,
    fontSize: widget.textSize,
    height: widget.lineHeight,
    fontWeight: FontWeight.w400,
  );

  TextStyle get _heading => _paragraph.copyWith(
    fontSize: widget.textSize + 3,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// Set in the italic of the chosen face where the app ships one, and in the
  /// roman where it does not: Space Grotesk has no italic at all, and a slant
  /// the engine drew is not a letterform anybody designed.
  TextStyle get _quotation => _paragraph.copyWith(
    color: patraTextMuted,
    fontStyle: widget.face.canSetItalic ? FontStyle.italic : FontStyle.normal,
  );

  @override
  Widget build(BuildContext context) {
    // A page with nothing in it is a page the server did not produce, and it
    // says so rather than being a screen of nothing at all.
    if (widget.page.isEmpty) return const BookPageUnavailable();
    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        _settle();
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: _scroll,
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
                  for (final block in widget.page.blocks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: switch (block) {
                        BookWords() => _words(block),
                        BookPicture(:final src) => widget.picture(src),
                      },
                    ),
                ],
              ),
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
      TextSpan(
        children: [
          for (final span in block.spans) span.toSpan(base, widget.face),
        ],
      ),
      // A page of a book is set **ragged right**, and deliberately: the
      // engine honours a soft hyphen as a break but does not draw the hyphen
      // at the break, so justification has no hyphenation to open a narrow
      // column with and opens gaps instead — which reads as a rendering
      // fault rather than as typography. See the reader's rules; the
      // measurement is recorded there so this is not "fixed" back.
      textAlign: TextAlign.start,
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
  // Where a word may be broken, and invisible. Written as a code point
  // because a character nobody can see has no business being pasted into
  // source; what the break costs — no hyphen is drawn at it — is measured
  // in the reader's rules.
  'shy': '\u00AD',
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

/// The name of the tag [tag] opens or closes, in lower case, or null where it
/// names nothing — the one definition of what a page's markup calls a tag.
///
/// Public because the face a book asks for is read out of the page's own
/// `<style>`, and that walk is the same grammar as this one (`book_face.dart`).
String? bookTagName(String tag) =>
    _tagName.firstMatch(tag)?.group(1)?.toLowerCase();

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

  for (final piece in markupPieces(html)) {
    if (!piece.isTag) {
      if (dropping == null) write(piece.text);
      continue;
    }
    final tag = piece.text;
    if (tag.startsWith('<!--')) continue;

    final name = bookTagName(tag);
    if (name == null) continue;
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

/// A page as its own markup splits it: a run of words, or one tag.
typedef MarkupPiece = ({String text, bool isTag});

/// The one walk over a page's markup, which [parseBookPage] and
/// [renameBookPictures] both consume.
///
/// Two walkers over one grammar is how two answers to "what is a tag" come
/// to exist, and the second one here has to reproduce a page exactly — so it
/// walks the same pieces and leaves every one of them alone but the one it
/// is rewriting.
Iterable<MarkupPiece> markupPieces(String html) sync* {
  var at = 0;
  while (at < html.length) {
    final markup = _markup.matchAsPrefix(html, at);
    if (markup == null) {
      // Words, up to the next tag.
      final next = html.indexOf('<', at);
      final end = next == -1 ? html.length : next;
      yield (text: html.substring(at, end), isTag: false);
      at = end;
      continue;
    }
    yield (text: markup.group(0)!, isTag: true);
    at = markup.end;
  }
}

/// The same page as [html], with every picture named differently.
///
/// A page that is going to be read with no server has to carry its pictures
/// with it, and what a page says about one is only ever a name — a path
/// inside the book, or an address (ADR-0009). [rename] answers with the name
/// the copy should carry instead, or with null to leave the page's own.
///
/// The words of the page are not touched and no tree is built: the page is
/// put back together out of the same pieces [parseBookPage] reads.
String renameBookPictures(String html, String? Function(String src) rename) {
  final out = StringBuffer();
  for (final piece in markupPieces(html)) {
    if (!piece.isTag) {
      out.write(piece.text);
      continue;
    }
    final tag = piece.text;
    final name = bookTagName(tag);
    out.write(
      (name == 'img' || name == 'image') && !tag.startsWith('</')
          ? _renamedPicture(tag, rename)
          : tag,
    );
  }
  return out.toString();
}

/// [tag] with the name of its picture replaced, or [tag] itself where
/// [rename] has nothing to put in its place.
String _renamedPicture(String tag, String? Function(String src) rename) {
  // Which attribute named it is kept: a page that named it with `href` gets
  // its `href` back rather than a second `src` beside the first.
  for (final attribute in const ['src', 'href']) {
    final match = _attributeMatch(tag, attribute);
    if (match == null) continue;
    final renamed = rename(_attributeValue(match));
    return renamed == null
        ? tag
        : tag.replaceRange(match.start, match.end, '$attribute="$renamed"');
  }
  return tag;
}

/// What [tag] says [name] is, or null where it says nothing.
String? _attributeOf(String tag, String name) {
  final match = _attributeMatch(tag, name);
  return match == null ? null : _attributeValue(match);
}

/// What one attribute of a tag says, whichever of the three ways it said it.
String _attributeValue(RegExpMatch match) =>
    match.group(2) ?? match.group(3) ?? match.group(4)!;

RegExpMatch? _attributeMatch(String tag, String name) {
  for (final match in _attribute.allMatches(tag)) {
    if (match.group(1)!.toLowerCase() != name) continue;
    return match;
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
