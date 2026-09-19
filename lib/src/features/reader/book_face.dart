/// The face a book asks for in its own stylesheet, and the files it is set
/// from.
///
/// Kavita inlines a book's CSS into every page it hands over, scoped to a
/// container of its own, and rewrites every `@font-face` source to
/// `book-resources` — so a page says, in the book's own words, which face its
/// words are set in and where that face's files are. Nothing else of the
/// book's CSS is honoured: this app draws the page itself (ADR-0010), and the
/// face is the one thing it takes from the book's design.
///
/// The server's own client does the same thing by doing nothing — its font
/// choice resolves to CSS `inherit`, which leaves the book's stylesheet to win
/// — and this is that answer written out, because a page drawn by us has no
/// browser to inherit anything (see the reader's rules).
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'book_page.dart';
import '../../api/kavita_client.dart';
import '../../auth/session.dart';
import '../../downloads/downloads_provider.dart';
import '../../settings/reading_settings.dart';

/// The key for a book's font: the chapter it belongs to, and the face the
/// page asked for.
typedef BookFontsKey = ({int chapterId, BookFace? face});

/// What a book's stylesheet asks for: the family it names, and the files that
/// family is set from.
@immutable
class BookFace {
  const BookFace({required this.family, this.roman, this.italic});

  /// The book's own name for the face. Never shown to anybody: the row that
  /// offers the book's own face says what kind of type it is, not what the
  /// book calls it.
  final String family;

  /// The file the roman is set from, as the stylesheet wrote it — a path
  /// inside the book, or a whole address Kavita wrote out of its own idea of
  /// where it lives. Turning either into a request is the client's job, as it
  /// is for a page's pictures (`KavitaClient.bookPictureUrl`).
  final String? roman;

  /// The file the italic is set from, or null where the book ships none — in
  /// which case emphasis stays in the roman, exactly as it does for a face of
  /// ours that has no italic.
  final String? italic;

  /// Whether there is anything here to set a page in.
  bool get isEmpty => roman == null && italic == null;

  @override
  bool operator ==(Object other) =>
      other is BookFace &&
      other.family == family &&
      other.roman == roman &&
      other.italic == italic;

  @override
  int get hashCode => Object.hash(family, roman, italic);

  @override
  String toString() => 'BookFace($family, roman: $roman, italic: $italic)';
}

/// What a copy of a book calls the face it carries.
///
/// A copy is pages and nothing else — promotion deletes every file in a
/// chapter's directory that is not a page — so the face is the one exception
/// that rule has to know about. It is named here rather than in the download
/// code so that the two cannot disagree about it, and it is extension-less
/// like a page, because what the file holds is whatever the book shipped.
abstract final class BookFontFile {
  static const roman = 'book-font';
  static const italic = 'book-font-italic';

  /// Every name a copy may hold that is not a page of it.
  static const names = {roman, italic};

  /// Whether [name] is one of them.
  static bool isCarried(String name) => names.contains(name);
}

/// A book's resolved font: the family registered with the engine, and whether
/// it has an italic. Null where the book has no face or its font could not be
/// loaded — the caller then falls back to the app's sans via
/// [ReadingFace.resolve].
typedef BookFont = ({String family, bool italic})?;

/// The namespaced family name for a book's face: `book-{chapterId}-{family}`.
///
/// Namespaced because `FontLoader` registers a family for the whole process
/// and there is no way to unload one: a book shipping a font called `Literata`
/// would otherwise shadow the app's own. Spaces are replaced with hyphens to
/// keep it a family name the engine accepts.
String namespacedFamily(int chapterId, String family) {
  final sanitized = family.replaceAll(' ', '-');
  return 'book-$chapterId-$sanitized';
}

/// Loads and registers a book's own face with the Flutter engine.
///
/// The roman and the italic are added as separate `addFont` calls on the same
/// family; where the engine cannot match the italic, emphasis stays in the
/// roman — which is exactly what the app already does for a face with no
/// italic of its own, so nothing else is invented for it.
///
/// Bytes come from the chapter's copy where it has one ([chapterDirProvider]
/// and [BookFontFile]), and from the server otherwise
/// ([KavitaClient.bookPictureBytes], with the `src` the book's stylesheet
/// wrote). A load that throws leaves the book with no face rather than failing
/// the page: a book whose font cannot be had is a book set in the app's sans,
/// which is where every book started.
Future<BookFont> _loadBookFont({
  required Ref ref,
  required int chapterId,
  required BookFace face,
}) async {
  final familyName = namespacedFamily(chapterId, face.family);

  try {
    // Try to load from the chapter copy first.
    final dir = await ref.read(chapterDirProvider(chapterId).future);
    final hasRoman = await File('${dir.path}/${BookFontFile.roman}').exists();
    final hasItalicFile = await File('${dir.path}/${BookFontFile.italic}').exists();

    Uint8List? romanBytes;
    Uint8List? italicBytes;

    if (hasRoman || hasItalicFile) {
      // Load from local copy.
      if (hasRoman) {
        romanBytes = await File('${dir.path}/${BookFontFile.roman}').readAsBytes();
      }
      if (hasItalicFile) {
        italicBytes = await File('${dir.path}/${BookFontFile.italic}').readAsBytes();
      }
    } else if (face.roman != null || face.italic != null) {
      // Fall back to the server.
      final client = ref.read(kavitaClientProvider);
      if (face.roman != null) {
        try {
          romanBytes = Uint8List.fromList(await client.bookPictureBytes(chapterId, face.roman!));
        } catch (_) {
          // Ignore — we'll try italic and if both fail, the book gets no face.
        }
      }
      if (face.italic != null) {
        try {
          italicBytes = Uint8List.fromList(await client.bookPictureBytes(chapterId, face.italic!));
        } catch (_) {
          // Ignore.
        }
      }
    }

    // If we have no bytes at all, the book gets no face.
    if (romanBytes == null && italicBytes == null) {
      return null;
    }

    // Register with FontLoader.
    final loader = FontLoader(familyName);
    if (romanBytes != null) {
      loader.addFont(Future.value(ByteData.view(romanBytes.buffer)));
    }
    if (italicBytes != null) {
      loader.addFont(Future.value(ByteData.view(italicBytes.buffer)));
    }
    await loader.load();

    // Return the result.
    final hasItalic = italicBytes != null;
    return (family: familyName, italic: hasItalic);
  } catch (_) {
    // Any failure (decode, network, etc.) leaves the book with no face.
    // The caller falls back to the app's sans via ReadingFace.resolve.
    return null;
  }
}

/// The book faces that have been resolved, one entry per (chapter, face).
///
/// A Riverpod [Notifier] rather than an auto-disposed provider, because what
/// it holds outlives any one page: `FontLoader` registers a family for the
/// whole process and there is no way to unload one, so a second ask for the
/// same face must not fetch anything again.
///
/// The map stores `null` for a key that has been resolved to "no face" —
/// whether the book asks for nothing, the fetch failed, or the engine would
/// not decode the font. Recording the negative answer is what stops the retry
/// storm that would otherwise run on every frame for a book with no face, or
/// for a reader on a train: the same reason a failed thumbnail is marked done
/// and never retried.
class BookFontsCache extends Notifier<Map<BookFontsKey, BookFont>> {
  @override
  Map<BookFontsKey, BookFont> build() => {};

  /// Whether [key] has already been resolved, to a font or to "no face".
  bool knows(BookFontsKey key) => state.containsKey(key);

  /// Loads the font for [key] if not already loaded or loading.
  ///
  /// Returns the font once loaded, or null if the book has no face or loading
  /// failed. The result is cached for subsequent synchronous access.
  Future<BookFont> loadFont(BookFontsKey key) async {
    final face = key.face;
    if (face == null || face.isEmpty) {
      // The book asks for nothing — the app's sans stands in.
      state = {...state, key: null};
      return null;
    }

    // Already resolved (success or failure) — return synchronously.
    if (knows(key)) {
      return state[key];
    }

    // Not yet resolved — load asynchronously using the notifier's own ref.
    final font = await _loadBookFont(ref: ref, chapterId: key.chapterId, face: face);
    state = {...state, key: font};
    return font;
  }
}

/// Provider for the shared book fonts cache.
final bookFontsCacheProvider =
    NotifierProvider<BookFontsCache, Map<BookFontsKey, BookFont>>(
      BookFontsCache.new,
    );

/// The font a book's own face resolved to, watched by the page that is set in
/// it: null while the answer is still coming, and null for good where there is
/// no face — which is what leaves the app's sans standing in.
final bookFontProvider = Provider.family<BookFont, BookFontsKey>((ref, key) {
  final cache = ref.watch(bookFontsCacheProvider);
  return cache[key];
});

/// The face [html] asks for, or null where it asks for nothing this app can
/// set a page in.
///
/// Read out of the page's own `<style>`, which is the only place a book says
/// anything at all: the app parses no EPUB (ADR-0008), and a book whose CSS
/// asks for nothing — or asks for a face it does not ship — reads as asking
/// for none, which leaves the app's own sans standing in.
BookFace? parseBookFace(String html) {
  // The files each family is set from, in the order the stylesheet declared
  // them: the roman it asked for, and the italic beside it where it ships one.
  final sources = <String, ({String? roman, String? italic})>{};
  // The rules that *use* a family rather than declaring one, with what they
  // say. The first of them that names a family the book also ships is the one
  // that says which face its words are in.
  final usage = <({String selector, List<String> families})>[];

  for (final css in bookStyleSheets(html)) {
    for (final match in _fontFaceRule.allMatches(css)) {
      final body = match.group(1)!;
      final named = _declaration('font-family').firstMatch(body);
      final declared = _declaration('src').firstMatch(body);
      if (named == null || declared == null) continue;
      final families = _families(named.group(1)!);
      final src = _fontSource(declared.group(1)!);
      if (families.isEmpty || src == null) continue;
      final style = _declaration('font-style').firstMatch(body)?.group(1) ?? '';
      final italic = _isItalic(style);
      // A face declares a `@font-face` per weight, and a page is set in one
      // weight of the roman and one of the italic: the bold and the light are
      // not what the book's words are in, so they are not read as its roman.
      final weight = _declaration('font-weight').firstMatch(body)?.group(1) ?? '';
      if (!italic && !_isRoman(weight)) continue;
      final family = families.first;
      final was = sources[family] ?? (roman: null, italic: null);
      sources[family] = italic
          ? (roman: was.roman, italic: was.italic ?? src)
          : (roman: was.roman ?? src, italic: was.italic);
    }
    for (final match in _rule.allMatches(css.replaceAll(_fontFaceRule, ''))) {
      final named = _declaration('font-family').firstMatch(match.group(2)!);
      if (named == null) continue;
      usage.add((
        selector: match.group(1)!.trim().toLowerCase(),
        families: _families(named.group(1)!),
      ));
    }
  }

  if (sources.isEmpty) return null;
  final family = _faceInUse(sources.keys.toList(), usage);
  if (family == null) return null;
  final source = sources[family]!;
  final face = BookFace(
    family: family,
    roman: source.roman,
    italic: source.italic,
  );
  return face.isEmpty ? null : face;
}

/// The text of every `<style>` a page carries, in the order it carries them.
///
/// Walked with [markupPieces], which is the one grammar a page's markup is
/// read by — a second answer to what a tag is would be a second answer to what
/// a page says.
Iterable<String> bookStyleSheets(String html) sync* {
  final css = StringBuffer();
  var inside = false;
  for (final piece in markupPieces(html)) {
    if (!piece.isTag) {
      if (inside) css.write(piece.text);
      continue;
    }
    if (bookTagName(piece.text) != 'style') continue;
    if (piece.text.startsWith('</')) {
      if (!inside) continue;
      inside = false;
      yield css.toString();
      css.clear();
      continue;
    }
    inside = true;
  }
  // A `<style>` the page never closed is still a stylesheet: a page that stops
  // mid-markup says what it says.
  if (inside && css.isNotEmpty) yield css.toString();
}

/// Which of the families a book ships is the one its words are in.
///
/// A book says so in the CSS that *uses* the family, not in the `@font-face`
/// that declares it, and Kavita scopes every selector to a container of its
/// own — so the family is read off whatever rule names it, with the rules that
/// speak for a whole page preferred over the ones that name one element of it.
///
/// A book that ships exactly one family and never says where it goes is read
/// as asking for it everywhere; a book that ships several and says nothing
/// gets none of them, which is what leaves the app's own sans standing in
/// rather than setting a page of prose in whatever the book used for its
/// chapter titles.
String? _faceInUse(
  List<String> shipped,
  List<({String selector, List<String> families})> usage,
) {
  for (final speaksForThePage in [true, false]) {
    for (final rule in usage) {
      if (_speaksForThePage(rule.selector) != speaksForThePage) continue;
      for (final family in rule.families) {
        if (shipped.contains(family)) return family;
      }
    }
  }
  return shipped.length == 1 ? shipped.first : null;
}

/// Whether a selector speaks for a whole page rather than for one element of
/// it. Kavita scopes a book's CSS to a container of its own, so the book's own
/// `body` arrives carrying that container's name.
bool _speaksForThePage(String selector) =>
    selector.contains('body') ||
    selector.contains('html') ||
    selector.contains(':root') ||
    selector.contains('.book-content');

/// The file a `src` declaration should be fetched from.
///
/// A `src` may offer several, best format first, and this app can only decode
/// some of them — so a source whose file is plainly a font file the engine
/// reads is preferred over one that is merely first. Null where the
/// declaration offers no file at all.
String? _fontSource(String value) {
  final urls = _url
      .allMatches(value)
      .map((match) => (match.group(1) ?? match.group(2) ?? match.group(3)!).trim())
      .where((url) => url.isNotEmpty)
      .where((url) => !url.startsWith('data:'))
      .toList();
  if (urls.isEmpty) return null;
  for (final url in urls) {
    if (_isReadableFont(url)) return url;
  }
  // Nothing the engine certainly reads: a `.woff2` is offered anyway, because
  // whether it can be decoded is the engine's answer to give and a face that
  // does not load leaves the app's sans standing in rather than failing.
  return urls.first;
}

/// Whether a file is one Flutter's own font loader certainly reads.
///
/// A `book-resources` address names its file in the query, so the file is read
/// out of there where there is one — the path of that address is the endpoint,
/// not the font.
bool _isReadableFont(String url) {
  final file = Uri.tryParse(url)?.queryParameters['file'];
  final path = (file ?? url.split('?').first).toLowerCase();
  return path.endsWith('.ttf') ||
      path.endsWith('.otf') ||
      path.endsWith('.ttc') ||
      path.endsWith('.woff2');
}

/// Whether a `font-style` declaration asks for the italic of the face.
bool _isItalic(String value) {
  final style = value.trim().toLowerCase();
  return style.startsWith('italic') || style.startsWith('oblique');
}

/// Whether a `font-weight` declaration asks for the roman rather than for a
/// weight of its own.
///
/// Absent, `normal`, and anything spanning a range — which is what a variable
/// font declares — all mean the face's own roman.
bool _isRoman(String value) {
  final weight = value.trim().toLowerCase();
  if (weight.isEmpty || weight == 'normal') return true;
  if (weight.contains(' ') || weight.contains('-')) return true;
  if (weight == 'bold' || weight == 'bolder') return false;
  final number = int.tryParse(weight);
  return number == null || number <= 400;
}

/// One `@font-face` block, and what is between its braces. A block never
/// nests, which is what makes this enough of a CSS reader for one job.
final _fontFaceRule = RegExp(
  r'@font-face\s*\{([^{}]*)\}',
  caseSensitive: false,
  dotAll: true,
);

/// One rule: everything before its braces, and what is inside them.
final _rule = RegExp(r'([^{}]*)\{([^{}]*)\}');

/// One declaration of a rule's body, as the value it was given.
RegExp _declaration(String property) => RegExp(
  '\\b$property\\s*:\\s*([^;}]+)',
  caseSensitive: false,
  dotAll: true,
);

/// Every `url(…)` a declaration wrote, quoted or bare.
final _url = RegExp(
  r'''url\(\s*(?:"([^"]*)"|'([^']*)'|([^)]*))\s*\)''',
  caseSensitive: false,
);

/// The families a `font-family` value names, in the order it named them:
/// `"Literata", Georgia, serif` is three, and the quotes are not part of any.
List<String> _families(String value) => [
  for (final name in value.split(','))
    if (_unquoted(name).isNotEmpty) _unquoted(name),
];

/// [name] without the quotes a CSS family may be written with.
String _unquoted(String name) {
  final trimmed = name.trim();
  if (trimmed.length < 2) return trimmed;
  final first = trimmed[0];
  if ((first == '"' || first == "'") && trimmed.endsWith(first)) {
    return trimmed.substring(1, trimmed.length - 1).trim();
  }
  return trimmed;
}
