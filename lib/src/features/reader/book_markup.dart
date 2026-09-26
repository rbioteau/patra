/// The walk over a page of a book's markup, and nothing that draws one.
///
/// Every caller that reads or rewrites a page's HTML goes through the pieces
/// walked here — the parser a page is drawn from (`book_page.dart`), the face
/// and the direction a book declares (`book_face.dart`), and the pass that
/// makes a page safe to hand an engine (`book_rewrite.dart`) — so that there
/// is one answer to what a tag is, what an attribute says, and what a picture
/// is named by. What file a picture is kept in is here too, for the same
/// reason: the downloader writes a copy's pictures under that name and the
/// reader looks for them by it.
/// It is a module of its own so that a caller can have those answers without
/// depending on the renderer, which ADR-0013 demotes to a development-only
/// path.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A bare tag name — `<p>`, `</P >`, `<br/>`, `<h2 class="x">`.
final RegExp _tagName = RegExp(r'<?/?\s*([a-zA-Z0-9]+)');

/// `src="OEBPS/images/cover.jpg"`, single-quoted, or bare.
final RegExp _attribute = RegExp(
  r'''([a-zA-Z-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+))''',
);

/// The name of the tag [tag] opens or closes, in lower case, or null where it
/// names nothing — the one definition of what a page's markup calls a tag.
///
/// Shared because the face a book asks for is read out of the page's own
/// `<style>` (`book_face.dart`), and that walk is the same grammar as the
/// parser's.
String? bookTagName(String tag) =>
    _tagName.firstMatch(tag)?.group(1)?.toLowerCase();

/// A page as its own markup splits it: a run of words, or one tag.
typedef MarkupPiece = ({String text, bool isTag});

/// The one walk over a page's markup, which `parseBookPage`
/// (`book_page.dart`), the face and direction a book declares
/// (`book_face.dart`) and the rewrite pass (`book_rewrite.dart`) all
/// consume, from [start] on.
///
/// Two walkers over one grammar is how two answers to "what is a tag" come
/// to exist, and the second one here has to reproduce a page exactly — so it
/// walks the same pieces and leaves every one of them alone but the one it
/// is rewriting.
///
/// **A tag ends where a browser ends it**, because the rewrite pass is the
/// trust boundary between a book and an engine (ADR-0013) and a pass that
/// reads a tag differently from the engine sanitises a different document
/// from the one that is run. So a `>` inside a quoted attribute value does not
/// end the tag, a `<` that opens nothing is a word, a comment that is never
/// closed runs to the end of the page, and a tag the page never finishes is
/// the rest of the page — each yielded as one tag piece that does not end in
/// `>`, which a browser drops and so does the pass.
Iterable<MarkupPiece> markupPieces(String html, [int start = 0]) sync* {
  var at = start;
  while (at < html.length) {
    final end = _markupEnd(html, at);
    if (end == null) {
      // Words, up to the next `<` — the one at [at] among them where it
      // opens nothing.
      final next = html.indexOf('<', at + 1);
      final stop = next == -1 ? html.length : next;
      yield (text: html.substring(at, stop), isTag: false);
      at = stop;
      continue;
    }
    yield (text: html.substring(at, end), isTag: true);
    at = end;
  }
}

/// Where the markup opening at [at] ends, or null where [at] opens none.
///
/// The states a browser's tokenizer passes through from a `<`, as far as
/// where they end: a comment ends at `-->`, a declaration, a processing
/// instruction or a `</` that names nothing at the next `>`, and a tag at the
/// first `>` outside a quoted attribute value.
int? _markupEnd(String html, int at) {
  if (html.codeUnitAt(at) != _lt || at + 1 >= html.length) return null;
  if (html.startsWith('<!--', at)) {
    // `<!-->` and `<!--->` are comments too, empty ones.
    for (final empty in const ['<!-->', '<!--->']) {
      if (html.startsWith(empty, at)) return at + empty.length;
    }
    final close = html.indexOf('-->', at + 4);
    return close == -1 ? html.length : close + 3;
  }
  final next = html.codeUnitAt(at + 1);
  final closing = next == _slash;
  if (next == _bang ||
      next == _question ||
      (closing &&
          (at + 2 >= html.length || !_isLetter(html.codeUnitAt(at + 2))))) {
    final close = html.indexOf('>', at + 1);
    return close == -1 ? html.length : close + 1;
  }
  if (!closing && !_isLetter(next)) return null;
  return _scanTag(html, at, null);
}

/// One attribute of a tag, as a browser reads it: its name as written, and
/// the value exactly as written — character references and all — or null
/// where it has none (`<video controls>`).
typedef BookAttribute = ({String name, String? value});

/// Every attribute [tag] carries, in the order it carries them, read the way
/// a browser's tokenizer reads them.
///
/// The rewrite pass rebuilds every tag it keeps out of these, which is why
/// they are read by the same states that decide where a tag ends: a value is
/// only a value where a name came before its `=`, and a quote is only a quote
/// where a value begins.
List<BookAttribute> bookAttributes(String tag) {
  final attributes = <BookAttribute>[];
  _scanTag(tag, 0, (name, value) => attributes.add((name: name, value: value)));
  return attributes;
}

/// Walks the tag opening at [at] through the tokenizer's attribute states,
/// telling [onAttribute] what each attribute is, and answers where the tag
/// ends — the end of [html] where it never does.
int _scanTag(
  String html,
  int at,
  void Function(String name, String? value)? onAttribute,
) {
  var i = at + 1;
  if (i < html.length && html.codeUnitAt(i) == _slash) i++;
  // The tag's name.
  while (i < html.length) {
    final c = html.codeUnitAt(i);
    if (_isSpace(c) || c == _slash || c == _gt) break;
    i++;
  }
  while (true) {
    // Before an attribute's name.
    while (i < html.length &&
        (_isSpace(html.codeUnitAt(i)) || html.codeUnitAt(i) == _slash)) {
      i++;
    }
    if (i >= html.length) return html.length;
    if (html.codeUnitAt(i) == _gt) return i + 1;
    // Its name: the first character belongs to it whatever it is, an `=`
    // included.
    final nameStart = i++;
    while (i < html.length) {
      final c = html.codeUnitAt(i);
      if (_isSpace(c) || c == _slash || c == _gt || c == _equals) break;
      i++;
    }
    final name = html.substring(nameStart, i);
    // After it: an `=` only means a value if nothing but space comes first.
    var j = i;
    while (j < html.length && _isSpace(html.codeUnitAt(j))) {
      j++;
    }
    if (j >= html.length || html.codeUnitAt(j) != _equals) {
      onAttribute?.call(name, null);
      continue;
    }
    i = j + 1;
    while (i < html.length && _isSpace(html.codeUnitAt(i))) {
      i++;
    }
    if (i >= html.length) return html.length;
    final quote = html.codeUnitAt(i);
    if (quote == _doubleQuote || quote == _singleQuote) {
      final close = html.indexOf(String.fromCharCode(quote), i + 1);
      if (close == -1) return html.length;
      onAttribute?.call(name, html.substring(i + 1, close));
      i = close + 1;
      continue;
    }
    if (quote == _gt) {
      onAttribute?.call(name, '');
      return i + 1;
    }
    final valueStart = i;
    while (i < html.length &&
        !_isSpace(html.codeUnitAt(i)) &&
        html.codeUnitAt(i) != _gt) {
      i++;
    }
    onAttribute?.call(name, html.substring(valueStart, i));
  }
}

const _lt = 0x3C, _gt = 0x3E, _slash = 0x2F, _bang = 0x21, _question = 0x3F;
const _equals = 0x3D, _doubleQuote = 0x22, _singleQuote = 0x27;

bool _isLetter(int c) => (c | 0x20) >= 0x61 && (c | 0x20) <= 0x7A;

bool _isSpace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0C || c == 0x0D;

/// What [tag] says [name] is, or null where it says nothing.
///
/// Shared for the same reason [bookTagName] is: the wrapper's own class list
/// is read where the direction a book declares is (`book_face.dart`), and a
/// second answer to what an attribute is would be a second answer to what a
/// page says.
String? bookAttribute(String tag, String name) {
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

/// The directory a copy of a book keeps the pictures its pages name in,
/// beside the pages themselves (#129).
///
/// A copy is a directory like the one a page is written into for the engine
/// (`book_document.dart`): the page as the server laid it out, and the files
/// it names beside it. The page is not rewritten to point at them — it keeps
/// the names it was given, so a stored page and a streamed one go through the
/// rewrite pass as the same page.
const bookPicturesDirectory = 'pictures';

/// Where the copy of a book in [copy] keeps the picture its pages name by
/// [src] — the one place the downloader writes it and the reader looks for
/// it, so the two cannot disagree. It may not be there: a picture the server
/// refused, or a copy saved before a copy was a directory.
File bookPictureFile(Directory copy, String src) =>
    File('${copy.path}/$bookPicturesDirectory/${bookFileName(src)}');

/// The name a file a page names by [src] is kept under on the device: the
/// same for the same name, whichever of a copy and the engine's directory it
/// is kept in, and keeping the extension of what it names — an engine reading
/// a file names its type by it. A whole address's own `file` is what it
/// names, never its query, so a key in the address never reaches a file name.
String bookFileName(String src) {
  final named = Uri.tryParse(src.trim());
  final path = named?.queryParameters['file'] ?? named?.path ?? src;
  final extension = RegExp(r'\.([A-Za-z0-9]{1,5})$')
      .firstMatch(path)
      ?.group(1)
      ?.toLowerCase();
  final name = sha1.convert(src.codeUnits).toString().substring(0, 16);
  return extension == null ? name : '$name.$extension';
}

/// The bytes a name carries, where it is a picture a stored page brought with
/// it — which is how a copy saved before a copy was a directory carries its
/// pictures (ADR-0009), and still opens. Null for any other name.
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
