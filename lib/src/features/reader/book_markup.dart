/// The walk over a page of a book's markup, and nothing that draws one.
///
/// Every caller that reads or rewrites a page's HTML goes through the pieces
/// walked here — the parser a page is drawn from (`book_page.dart`), the face
/// and the direction a book declares (`book_face.dart`), and the downloader
/// that makes a page carry its own pictures (`downloads_service.dart`) — so
/// that there is one answer to what a tag is, what an attribute says, and what
/// a picture is named by. What a carried picture is named by is here too, for
/// the same reason: the downloader writes that name and the reader decodes it.
/// It is a module of its own so that a caller can have those answers without
/// depending on the renderer, which ADR-0013 demotes to a development-only
/// path.
library;

import 'dart:convert';
import 'dart:typed_data';

/// A tag, or a comment. Anything else in a page is words.
final RegExp _markup = RegExp(r'<!--.*?-->|<[^>]*>', dotAll: true);

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
/// (`book_face.dart`) and [renameBookPictures] all consume.
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
/// put back together out of the same pieces `parseBookPage` reads.
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
