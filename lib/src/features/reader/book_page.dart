/// One page of a book, taken apart: the parser, and the place in a page.
///
/// Kavita hands a book over one page of HTML at a time, its markup and its CSS
/// already scoped for a reader (ADR-0008), and that HTML is the server's
/// output — nothing here parses an EPUB, and nothing here is a browser. What
/// is taken apart is the handful of tags a page of a book is actually made of:
/// paragraphs, headings, quotations, list items and pictures.
///
/// **The parser is not optional**, whatever draws the page:
/// [BookPage.pictureSources] is what the downloader and the web engine both
/// read to know which pictures a page holds. What a reader sees is the
/// platform's web engine (`book_web_page.dart`, ADR-0013); the blocks are
/// drawn only by the development renderer (`development/`, #131), which is
/// not shipped.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';

import 'book_face.dart';
import 'book_markup.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/reading_settings.dart';
import '../../theme.dart';

/// A run of words inside a block, and how the book set it.
class BookSpan {
  const BookSpan(this.text, {this.bold = false, this.italic = false});

  final String text;
  final bool bold;
  final bool italic;
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
  const BookPage(this.blocks, {this.face, this.direction, this.html = ''});

  final List<BookBlock> blocks;

  /// The page as the server handed it over, or as a copy stored it: what the
  /// web engine is given, once the rewrite pass has been over it (#127).
  final String html;

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

  /// The direction the page's own stylesheet declares the book is written in,
  /// or null where it declares none this app acts on. Parsed once beside the
  /// face, out of the same `<style>`, and carried so the reader can record it
  /// against the work as evidence for the chain's detected rung (#118).
  final ReadingDirection? direction;

  /// Takes [html] apart without holding the thread the app draws on.
  ///
  /// A page past [parsesInPlaceBelow] characters is taken apart in an isolate
  /// of its own. Such pages are real: a copy saved before a copy was a
  /// directory carries its pictures inside its pages as data URIs, and pages
  /// of several megabytes were measured on a device, where three of them —
  /// the page and the two either side — held the thread long enough in a
  /// debug build for Android to kill the app. Below it the page is taken
  /// apart where it is, since starting an isolate costs more than a page of
  /// words does.
  static Future<BookPage> parse(String html) => html.length < parsesInPlaceBelow
      ? Future.value(BookPage.fromHtml(html))
      : Isolate.run(() => BookPage.fromHtml(html));

  /// [parse], of the page stored in [file] — read in the isolate too where
  /// it is large enough to go there, rather than read here and copied over.
  static Future<BookPage> read(File file) {
    if (file.lengthSync() < parsesInPlaceBelow) {
      return Future.value(BookPage.fromHtml(file.readAsStringSync()));
    }
    final path = file.path;
    return Isolate.run(() => BookPage.fromHtml(File(path).readAsStringSync()));
  }

  /// The size past which a page is taken apart off the drawing thread.
  static const parsesInPlaceBelow = 64 * 1024;

  factory BookPage.fromHtml(String html) => BookPage(
    parseBookPage(html),
    face: parseBookFace(html),
    direction: parseBookDirection(html),
    html: html,
  );
}

/// Where in a page of a book the reader is.
///
/// A page of a book can be longer than the screen, so where a reader is is a
/// page *and* a place within it — and the progress call Kavita's own web
/// client uses has always carried a marker for that place, `bookScrollId`, a
/// string the reader defines and the server hands back. The server stores it
/// and reads nothing into it, so the form is this app's to choose.
///
/// **A block and a fraction down it** (#128): which of the blocks the rewrite
/// pass named (`data-patra-block`, `book_rewrite.dart`) the top of the screen
/// is in, and how far through that block. Neither is a number of points, and
/// that is the whole of the argument: a text size (#75), a face, a rotation
/// and a differently sized window all move the words, and the paragraph a
/// reader is in is the one thing none of them can move. A fraction of the
/// whole page, which is what came before, is only nearly so — a page whose
/// words grow by a fifth does not grow by a fifth at every point of it,
/// because its pictures do not.
///
/// **A bare fraction is still read, as the fraction of the page it always
/// was**: it is already on servers and already in copies, and a reader who
/// had a place before this change keeps one. It is also what the development
/// renderer still writes (`DevelopmentBookPage`, #131), which has no blocks
/// to name. This is the rule a renamed
/// reading direction follows (`_legacyNames`): an old value is a value, not
/// an error.
@immutable
class BookAnchor {
  /// A place down the page as a whole: the form written before there were
  /// blocks to name, and the form a page with none still takes.
  const BookAnchor(this.fraction) : block = null;

  /// A place [fraction] of the way through the block the rewrite named
  /// [block].
  const BookAnchor.inBlock(int this.block, this.fraction);

  /// The top of a page: where every page with no marker opens, and where a
  /// reader arrives on a page they have just turned to.
  static const top = BookAnchor(0);

  /// The block the place is in, as the rewrite numbered it, or null for a
  /// place down the page as a whole.
  final int? block;

  /// 0 at the top of the block — or of the page, with no [block] — and 1 at
  /// the end of it.
  final double fraction;

  /// Whether this is the top of the page, which is a page with nowhere to be
  /// put.
  bool get isTop => block == null && fraction == 0;

  /// What the server is asked to remember.
  ///
  /// Written so that nothing could read it as the bare fraction it replaces,
  /// nor as the id of an element Kavita's own web client writes there.
  String get id {
    final at = fraction.toStringAsFixed(4);
    return block == null ? at : '$_mark$block@$at';
  }

  static const _mark = 'patra:';
  static final _inBlock = RegExp('^$_mark' r'(\d+)@(\d+(?:\.\d+)?)$');

  /// What the server handed back, or null where it is not a place this app
  /// wrote — the web client's element ids among them, which name nothing in a
  /// page drawn here.
  static BookAnchor? from(String? id) {
    if (id == null) return null;
    if (_inBlock.firstMatch(id) case final match?) {
      final block = int.tryParse(match.group(1)!);
      final fraction = double.tryParse(match.group(2)!);
      if (block == null || fraction == null) return null;
      return BookAnchor.inBlock(block, fraction.clamp(0.0, 1.0));
    }
    final fraction = double.tryParse(id);
    if (fraction == null || !fraction.isFinite) return null;
    return BookAnchor(fraction.clamp(0.0, 1.0));
  }

  /// What the app's own script in a page is told and tells back
  /// (`bookBridgeScript`): the same two numbers as [id], as JSON, since a
  /// script reads JSON and should not have to read this app's string.
  Map<String, Object> toJson() => {'block': ?block, 'at': fraction};

  /// What the page's script told, or null for anything that is not a place.
  static BookAnchor? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = json['at'];
    if (at is! num || !at.isFinite) return null;
    final fraction = at.toDouble().clamp(0.0, 1.0);
    return switch (json['block']) {
      null => BookAnchor(fraction),
      final int block when block >= 0 => BookAnchor.inBlock(block, fraction),
      _ => null,
    };
  }

  /// Where in a page [offset] is, of the [extent] there is to scroll.
  factory BookAnchor.at(double offset, double extent) => extent <= 0
      ? BookAnchor.top
      : BookAnchor((offset / extent).clamp(0.0, 1.0));

  @override
  bool operator ==(Object other) =>
      other is BookAnchor && other.block == block && other.fraction == fraction;

  @override
  int get hashCode => Object.hash(block, fraction);

  @override
  String toString() => 'BookAnchor($id)';
}

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
        final src = bookAttribute(tag, 'src') ?? bookAttribute(tag, 'href');
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
