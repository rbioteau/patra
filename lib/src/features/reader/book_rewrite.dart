/// The one pass that turns a page of a book into a document an engine may be
/// given (ADR-0013, #126).
///
/// Kavita sanitises nothing — it keeps a book's `<script>` on purpose and
/// leaves its inline handlers alone — so this pass is the whole of the trust
/// boundary between a file somebody dropped into a library and the engine a
/// page is rendered in. It is not a defence a JavaScript switch could stand in
/// for: switching script off would also cost the app its own scroll bridge,
/// and it closes no network channel at all, the plugin wrapping no
/// interception of a page's subresources. So a URL that survives this pass is
/// a URL that reaches the network unseen, and a handler that survives it runs.
///
/// It runs identically on a streamed page and on a stored one, and it is the
/// only place any of this happens. What it answers is **a whole document**:
///
/// - **Nothing that can execute** — no script, no handler, no frame, no
///   element that holds a document of its own, no `<base>`, no `<meta>`.
/// - **No remote address** — every URL a page can fetch from is a local file
///   the caller names, a fragment of the page itself, or data the page
///   carries; everything else is removed rather than rewritten, and a link
///   that leaves the page is not a link any more.
/// - **A content policy first**, since a policy only governs what is asked
///   for after it is read. It is the backstop to the two rules above, not a
///   substitute for them.
/// - **The reader's three settings**, in a cascade layer declared before the
///   book, whose `!important` outranks every `!important` a book can make —
///   and the files the chosen face is set from, since an engine has none of
///   the faces the app bundles. The same layer sets the page on the reader's
///   canvas, as a default the book's own colours outrank.
/// - **The book's language** on the document where it is known, and none
///   where it is not — an engine given none declines to hyphenate, which is
///   the behaviour wanted and needs nothing built.
/// - **A stable name per block**, `data-patra-block`, for a reading position
///   to be anchored to.
///
/// Every tag it keeps is **rebuilt** rather than edited: its attributes are
/// read the way a browser's tokenizer reads them (`bookAttributes`), and
/// written back quoted and escaped. What leaves this pass is therefore markup
/// a browser can only read one way, which is the way it was checked.
/// Sanitising HTML is notoriously hard, and that is ADR-0013's residual risk:
/// this file is kept small enough to be read in one sitting so that it can be
/// audited in one.
library;

import 'dart:math' as math;
import 'dart:ui' show Color;

import '../../settings/reading_settings.dart';
import '../../theme.dart';
import 'book_markup.dart';

/// The file on the device that stands for what a page named [src], or null
/// where there is none.
typedef LocalFile = String? Function(String src);

/// What the reader chose a book be set in — the three things that follow the
/// reader's eyes rather than the work (#75, #92).
typedef BookSetting = ({double textSize, double lineHeight, ReadingFace face});

/// The files on the device the face the reader chose is set from: the app's
/// own, which an engine does not have until a document says where they are.
typedef FaceFiles = ({String roman, String italic});

/// The document an engine may be given for one page of a book.
///
/// [html] is the page as the server handed it over, or as a copy stored it.
/// [language] is the book's own declared BCP-47 code (#125), never a guess.
/// [localFile] names the file on the device that stands for a picture or a
/// font the page refers to — given the name exactly as the page wrote it, the
/// one `pictureSources` reads — or null where there is none; an answer that is
/// not itself local is refused like no answer at all. [faceFiles] are where
/// the face [setting] names is set from, refused the same way; with none, the
/// face is named and left to whatever the engine holds of it.
String rewriteBookPage(
  String html, {
  required String? language,
  required BookSetting setting,
  required LocalFile localFile,
  FaceFiles? faceFiles,
}) {
  final lang = _language(language);
  return '<!DOCTYPE html>\n'
      '<html${lang == null ? '' : ' lang="$lang"'}>\n'
      '<head>\n'
      '<meta http-equiv="Content-Security-Policy" content="$_policy">\n'
      '<meta charset="utf-8">\n'
      '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
      '<style>\n${_faces(setting, faceFiles)}${_overrides(setting)}\n</style>\n'
      '</head>\n'
      '<body>\n${_Rewrite(html, localFile).run()}\n</body>\n'
      '</html>\n';
}

/// Nothing from anywhere but the device, and nothing run at all. The app's
/// own scroll bridge is not a script of the page's and is not governed by it.
const String _policy =
    "default-src 'none'; script-src 'none'; object-src 'none'; "
    "base-uri 'none'; form-action 'none'; "
    "style-src 'unsafe-inline'; img-src file: data:; font-src file: data:; "
    'media-src file: data:';

/// A BCP-47 tag in the shape one has, or null: the language is written into
/// an attribute, so a value that is not one is not written at all.
String? _language(String? language) {
  final tag = language?.trim();
  if (tag == null) return null;
  return RegExp(r'^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$').hasMatch(tag)
      ? tag
      : null;
}

/// The family the reader chose to impose, or null where the choice was the
/// book's own face — the book's stylesheet winning, as in the server's own
/// client: nothing is imposed.
String? _imposedFamily(ReadingFace face) => switch (face) {
  ReadingFace.book => null,
  ReadingFace.serif => fontLiterata,
  ReadingFace.sans => fontAtkinsonHyperlegibleNext,
};

/// Where the imposed family's roman and italic are, declared ahead of the
/// layer that imposes it. Every app face is variable, so one file answers
/// every weight.
String _faces(BookSetting setting, FaceFiles? files) {
  final family = _imposedFamily(setting.face);
  if (family == null || files == null) return '';
  String face(String file, String style) =>
      _isRemote(file) || file.contains(RegExp('["\\\\\n<>]'))
      ? ''
      : '@font-face { font-family: "$family"; src: url("$file"); '
            'font-style: $style; font-weight: 100 900; }\n';
  return face(files.roman, 'normal') + face(files.italic, 'italic');
}

/// The reader's settings as a layer the book comes after.
///
/// An `!important` in the **first** layer declared outranks every
/// `!important` declared later or in no layer at all, whatever its
/// specificity, which is what lets the book keep every other declaration it
/// makes. The size is set on the root alone — imposing it on every element
/// would flatten a heading to the size of the words under it — so a size the
/// book fixes is read as a share of it instead (see [_shareOfTheRoot]).
String _overrides(BookSetting setting) {
  final family = _imposedFamily(setting.face);
  return '@layer $_layer {\n'
      // The reader's canvas, and room at the foot for the page counter: a
      // default, not an override, so a book that sets its own colours or its
      // own margins is set in them.
      '  html { background-color: ${_hex(patraReaderCanvas)}; '
      'color: ${_hex(patraText)}; '
      'padding: ${_number(gutter)}px ${_number(gutter)}px '
      '${_number(4 * gutter)}px; }\n'
      '  html { font-size: ${_number(setting.textSize)}px !important; }\n'
      '  *, *::before, *::after { '
      'line-height: ${_number(setting.lineHeight)} !important; }\n'
      '${family == null ? '' : '  *, *::before, *::after, *::first-letter, '
                '*::first-line, *::marker { '
                'font-family: "$family" !important; }\n'}'
      '}';
}

const String _layer = 'patra';

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

String _number(double value) {
  final rounded = (value * 10000).round() / 10000;
  return rounded == rounded.truncateToDouble()
      ? rounded.toInt().toString()
      : rounded.toString();
}

/// Elements whose whole content goes with them, because a browser does not
/// read it as the page's words: a script's source, and what a frame or a
/// `<noscript>` holds.
const Set<String> _droppedWithContent = {
  'script',
  'noscript',
  'iframe',
  'noembed',
  'noframes',
};

/// Elements that go while their content stays: each holds a document of its
/// own, reaches elsewhere, or would stand the page on its head.
const Set<String> _droppedAlone = {
  'object',
  'embed',
  'applet',
  'frame',
  'frameset',
  'base',
  'link',
  'meta',
  'plaintext',
  'html',
  'head',
  'body',
  'portal',
  // An SVG animation can set any attribute to anything, after the pass has
  // read it: a link, a picture, a paint.
  'animate',
  'animatemotion',
  'animatetransform',
  'set',
  'discard',
};

/// Attributes nothing in a page needs and every one of which fetches, submits
/// or holds a document.
const Set<String> _droppedAttributes = {
  'srcset',
  'imagesrcset',
  'ping',
  'action',
  'formaction',
  'manifest',
  'codebase',
  'archive',
  'classid',
  'lowsrc',
  'dynsrc',
  'longdesc',
  'cite',
  'profile',
  'srcdoc',
};

/// Attributes that name something the page fetches.
const Set<String> _resourceAttributes = {
  'src',
  'poster',
  'background',
  'data',
  'href',
  'xlink:href',
};

/// What a reading position is anchored to (#128): the blocks a reader reads
/// in, in the order they are read.
const Set<String> _blocks = {
  'address',
  'article',
  'aside',
  'blockquote',
  'caption',
  'dd',
  'div',
  'dt',
  'figcaption',
  'figure',
  'footer',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'li',
  'p',
  'pre',
  'section',
  'td',
  'th',
};

/// The mark the app puts on a block, which a book is not allowed to forge:
/// what a reading position names (#128, `bookBridgeScript`).
const String bookBlockMark = 'data-patra-block';

final RegExp _writtenName = RegExp(r'^</?([^\s/>]+)');
final RegExp _validName = RegExp(r'^[A-Za-z][A-Za-z0-9:_.-]*$');
final RegExp _validAttribute = RegExp(r'^[A-Za-z_:][A-Za-z0-9:_.-]*$');

final Map<String, RegExp> _rawClose = {};

class _Rewrite {
  _Rewrite(this.html, this.localFile);

  final String html;
  final LocalFile localFile;
  final out = StringBuffer();
  var _block = 0;

  String run() {
    var at = 0;
    walk:
    while (true) {
      for (final piece in markupPieces(html, at)) {
        at += piece.text.length;
        if (!piece.isTag) {
          out.write(piece.text.replaceAll('<', '&lt;'));
          continue;
        }
        final tag = piece.text;
        // A comment, a declaration, a CDATA section, a processing
        // instruction, and a tag the page never finished: none is the page.
        if (!tag.endsWith('>') ||
            tag.startsWith('<!') ||
            tag.startsWith('<?')) {
          continue;
        }
        final closing = tag.startsWith('</');
        // The name as written, case and namespace kept, since the tag is
        // written back with it — where `bookTagName` answers what it means.
        final name = _writtenName.firstMatch(tag)?.group(1);
        if (name == null || !_validName.hasMatch(name)) continue;
        final lower = name.toLowerCase();
        final local = lower.substring(lower.lastIndexOf(':') + 1);
        if (_droppedWithContent.contains(local)) {
          if (!closing && !tag.endsWith('/>')) at = _rawEnd(local, at).end;
          continue walk;
        }
        if (_droppedAlone.contains(local)) continue;
        if (closing) {
          if (local != 'style') out.write('</$name>');
          continue;
        }
        // A `<style/>` is no more closed than a `<style>` is, to HTML: what
        // follows it is its CSS.
        final raw = local == 'style';
        out.write(_openingTag(name, local, tag, selfClosing: !raw));
        if (raw) {
          final end = _rawEnd('style', at);
          final css = _rewriteCss(html.substring(at, end.start), localFile);
          // Neither a `<` nor an `&` is left for anyone to read as markup —
          // in an SVG a `<style>` is not raw text but markup, and its
          // character references are decoded — and both escapes mean the
          // same character to CSS.
          out
            ..write(css.replaceAll('<', r'\3c ').replaceAll('&', r'\26 '))
            ..write('</$name>');
          at = end.end;
          continue walk;
        }
      }
      break;
    }
    return out.toString();
  }

  /// Where the raw text of an element named [name] opened at [at] ends, the
  /// way a browser ends it: at the first `</name` that is followed by a
  /// space, a slash or a `>`, whatever it is inside — and at the end of the
  /// page where there is none.
  ({int start, int end}) _rawEnd(String name, int at) {
    final close = _rawClose
        .putIfAbsent(name, () => RegExp('</$name[\\s/>]', caseSensitive: false))
        .allMatches(html, at)
        .firstOrNull;
    if (close == null) return (start: html.length, end: html.length);
    final start = close.start;
    final gt = html.indexOf('>', start);
    return (start: start, end: gt == -1 ? html.length : gt + 1);
  }

  String _openingTag(
    String name,
    String local,
    String tag, {
    required bool selfClosing,
  }) {
    final kept = StringBuffer('<$name');
    for (final (:name, :value) in bookAttributes(tag)) {
      final attribute = name.toLowerCase();
      if (!_validAttribute.hasMatch(name) ||
          attribute.startsWith('on') ||
          attribute.startsWith('data-patra') ||
          // A shadow root is a document the reader's layer does not reach.
          attribute.startsWith('shadowroot') ||
          _droppedAttributes.contains(attribute) ||
          (local == 'font' && attribute == 'size')) {
        continue;
      }
      if (value == null) {
        kept.write(' $name');
        continue;
      }
      final written = _attributeValue(local, attribute, value);
      if (written != null) kept.write(' $name="$written"');
    }
    if (_blocks.contains(local)) kept.write(' $bookBlockMark="${_block++}"');
    kept.write(selfClosing && tag.endsWith('/>') ? '/>' : '>');
    return kept.toString();
  }

  /// What [attribute] says, escaped to stand in double quotes, or null where
  /// it may not stay.
  String? _attributeValue(String element, String attribute, String value) {
    if (attribute == 'style') {
      final decoded = _decodeReferences(value);
      final css = _rewriteInlineStyle(decoded, localFile);
      return css == decoded ? _escapeRaw(value) : _escape(css);
    }
    if (!_resourceAttributes.contains(attribute)) {
      // An SVG paints, clips, filters and marks with a `url(` in an attribute
      // of its own, as CSS would in a stylesheet.
      final decoded = _decodeReferences(value);
      if (!_mayNameAnAddress.hasMatch(_spellLetters(decoded))) {
        return _escapeRaw(value);
      }
      return _escape(_rewriteAddresses(decoded, localFile));
    }
    final address = _decodeReferences(value);
    if (_isFragment(address)) return _escapeRaw(value);
    // A link that leaves the page is a request the reader never made.
    if (element == 'a' || element == 'area') return null;
    // Data a page carries is a picture it carried (ADR-0013), and nothing a
    // picture is not.
    if (_isData(address)) {
      return element == 'img' || element == 'image' ? _escapeRaw(value) : null;
    }
    final local = _localName(value, localFile);
    return local == null ? null : _escape(local);
  }
}

/// [value] written as it was, character references and all, escaped only
/// where it would otherwise end the quotes it now stands in.
String _escapeRaw(String value) => value
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// [value], a string of characters rather than of markup, escaped to stand
/// in double quotes.
String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// The local file the caller names for [src], exactly as the page wrote it,
/// or null where it names none — or names one that is not local, which a
/// caller's mistake must not be able to put back into the page.
///
/// The page's own name is asked about whatever it is, a whole address
/// included: Kavita names a picture by its own guess at where it lives, and
/// it is the caller that has fetched it and knows where it is on the device.
/// What reaches the page is only ever the answer.
String? _localName(String src, LocalFile localFile) {
  final local = localFile(src);
  return local == null || _isRemote(local) ? null : local;
}

/// Whether a browser would read [address] as leaving the device: any scheme
/// but `file:`, and any address that names a host of its own.
bool _isRemote(String address) {
  final url = _asBrowserReadsIt(address).replaceAll(r'\', '/');
  if (url.startsWith('//')) return true;
  final scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.-]*):').firstMatch(url);
  return scheme != null && scheme.group(1)!.toLowerCase() != 'file';
}

bool _isData(String address) =>
    _asBrowserReadsIt(address).toLowerCase().startsWith('data:');

bool _isFragment(String address) => _asBrowserReadsIt(address).startsWith('#');

/// [address] with what a URL parser throws away thrown away: every tab and
/// line break inside it, and the spaces and controls — U+0000 to U+0020 —
/// around it.
///
/// The edges are trimmed by walking in from each end rather than by a
/// pattern: an address can be a picture a page carries, a megabyte of it,
/// and a pattern anchored at the end is tried from every position of that
/// megabyte — measured, it was most of the time a heavy page took to pass.
String _asBrowserReadsIt(String address) {
  final kept = address.replaceAll(_lineBreaks, '');
  var start = 0;
  var end = kept.length;
  while (start < end && kept.codeUnitAt(start) <= 0x20) {
    start++;
  }
  while (end > start && kept.codeUnitAt(end - 1) <= 0x20) {
    end--;
  }
  return kept.substring(start, end);
}

final RegExp _lineBreaks = RegExp('[\t\n\r]');

// ---------------------------------------------------------------------------
// Character references.

/// [value] with every character reference that can make an ASCII character
/// decoded — the numeric ones, and the named ones in [_asciiEntities] — and
/// every other named one left as written.
///
/// Only as far as a URL or a stylesheet could be changed by it: a reference
/// that decodes to anything outside ASCII cannot make a scheme, a slash, a
/// colon or a `url(`, so those are left for the browser, and the pass
/// decides nothing on them.
///
/// A value with no `&` has no reference in it, and is answered as it is
/// without being searched — a picture a page carries is a megabyte of none.
String _decodeReferences(String value) {
  if (!value.contains('&')) return value;
  return value.replaceAllMapped(
    RegExp(r'&(?:#[xX]([0-9A-Fa-f]+);?|#([0-9]+);?|([A-Za-z][A-Za-z0-9]*);)'),
    (match) {
      final named = match.group(3);
      if (named != null) return _asciiEntities[named] ?? match.group(0)!;
      final code = match.group(1) != null
          ? int.tryParse(match.group(1)!, radix: 16)
          : int.tryParse(match.group(2)!);
      if (code == null ||
          code == 0 ||
          code > 0x10FFFF ||
          (code >= 0xD800 && code <= 0xDFFF)) {
        return '\uFFFD';
      }
      return String.fromCharCode(code);
    },
  );
}

/// Every named reference HTML defines whose value is ASCII.
const Map<String, String> _asciiEntities = {
  'Tab': '\t',
  'NewLine': '\n',
  'excl': '!',
  'quot': '"',
  'QUOT': '"',
  'num': '#',
  'dollar': r'$',
  'percnt': '%',
  'amp': '&',
  'AMP': '&',
  'apos': "'",
  'lpar': '(',
  'rpar': ')',
  'ast': '*',
  'midast': '*',
  'plus': '+',
  'comma': ',',
  'period': '.',
  'sol': '/',
  'colon': ':',
  'semi': ';',
  'lt': '<',
  'LT': '<',
  'equals': '=',
  'gt': '>',
  'GT': '>',
  'quest': '?',
  'commat': '@',
  'lsqb': '[',
  'lbrack': '[',
  'bsol': r'\',
  'rsqb': ']',
  'rbrack': ']',
  'Hat': '^',
  'lowbar': '_',
  'UnderBar': '_',
  'grave': '`',
  'DiacriticalGrave': '`',
  'lcub': '{',
  'lbrace': '{',
  'verbar': '|',
  'vert': '|',
  'VerticalLine': '|',
  'rcub': '}',
  'rbrace': '}',
  'fjlig': 'fj',
};

// ---------------------------------------------------------------------------
// Stylesheets.

/// A `<style>`'s CSS with every address in it local or gone, every
/// `@import` gone, the reader's layer out of the book's reach, and every size
/// the book fixes made a share of the reader's.
String _rewriteCss(String css, LocalFile localFile) =>
    _shareOfTheRoot(_rewriteAddresses(css, localFile));

/// A `style` attribute's declarations, rewritten as a stylesheet's are, and
/// with the `!important` taken off the three the reader owns: an inline
/// `!important` outranks a stylesheet's, layer or not.
String _rewriteInlineStyle(String css, LocalFile localFile) =>
    _shareOfTheRoot(_rewriteAddresses(css, localFile)).replaceAllMapped(
      RegExp(
        r'(?<=(?:^|;)\s*)((?:font-size|font-family|font|line-height)'
        r'\s*:[^;]*?)\s*!\s*important',
        caseSensitive: false,
      ),
      (match) => match.group(1)!,
    );

/// What an attribute holds before the pass has to read it as CSS.
final RegExp _mayNameAnAddress = RegExp(
  r'url\(|image-set\(|image\(|cross-fade\(|src\(',
  caseSensitive: false,
);

/// Functions whose strings are addresses rather than words.
final RegExp _addressFunction = RegExp(
  r'(?:-webkit-)?image-set\(|image\(|cross-fade\(|src\(',
  caseSensitive: false,
);

/// The one walk over CSS, token by token as far as an address is concerned:
/// a comment is dropped whole, a string is copied whole — so neither can
/// hide the start of a `url(` from the walk, or show one that is not there —
/// and every `url(`, every string inside `image-set(`, and every `@import`
/// is rewritten. Escapes that spell a letter are spelled out first, since
/// `\75 rl(` is a `url(` to CSS.
String _rewriteAddresses(String css, LocalFile localFile) {
  final source = _spellLetters(css);
  final out = StringBuffer();
  var addressDepth = 0;
  var depth = 0;
  var i = 0;
  String resolved(String raw) {
    final address = raw.trim();
    if (address.isEmpty) return 'none';
    if (_isFragment(address) || _isData(address)) {
      return 'url("${_cssString(address)}")';
    }
    final local = _localName(address, localFile);
    return local == null ? 'none' : 'url("${_cssString(local)}")';
  }

  while (i < source.length) {
    final c = source[i];
    if (source.startsWith('/*', i)) {
      final close = source.indexOf('*/', i + 2);
      final end = close == -1 ? source.length : close + 2;
      // Dropped rather than copied: a comment is no declaration, and one
      // left between two tokens hides the second from every rule below.
      i = end;
      continue;
    }
    if (c == '"' || c == "'") {
      final end = _stringEnd(source, i);
      final text = source.substring(i, end);
      out.write(addressDepth > 0 ? resolved(_unquoted(text)) : text);
      i = end;
      continue;
    }
    if (_startsWordAt(source, i, 'url(') &&
        (i == 0 || !_isNameChar(source[i - 1]))) {
      final end = _urlEnd(source, i + 4);
      out.write(resolved(_unquoted(source.substring(i + 4, end.value).trim())));
      i = end.next;
      continue;
    }
    if (c == '@' && _startsAtRule(source, i, 'import')) {
      i = _atRuleEnd(source, i);
      continue;
    }
    if (c == '@' && _startsAtRule(source, i, 'layer')) {
      // A book that names the reader's layer would be writing into it.
      final end = source.indexOf(RegExp(r'[{;]'), i);
      final stop = end == -1 ? source.length : end;
      out.write(
        source
            .substring(i, stop)
            .replaceAllMapped(
              RegExp('(?<![\\w-])$_layer(?![\\w-])', caseSensitive: false),
              (_) => 'book-$_layer',
            ),
      );
      i = stop;
      continue;
    }
    final function = _addressFunction.matchAsPrefix(source, i);
    if (function != null && (i == 0 || !_isNameChar(source[i - 1]))) {
      out.write(function.group(0));
      depth++;
      addressDepth = depth;
      i = function.end;
      continue;
    }
    if (c == '(') depth++;
    if (c == ')') {
      if (depth == addressDepth) addressDepth = 0;
      depth = math.max(0, depth - 1);
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// [css] with every escape that stands for an ASCII letter replaced by the
/// letter — which means the same thing to CSS wherever it stands.
String _spellLetters(String css) => css.replaceAllMapped(
  RegExp(r'\\(?:([0-9A-Fa-f]{1,6})(?:\r\n|[ \t\r\n\f])?|([G-Zg-z]))'),
  (match) {
    final letter = match.group(2);
    if (letter != null) return letter;
    final code = int.parse(match.group(1)!, radix: 16);
    final isLetter =
        (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
    return isLetter ? String.fromCharCode(code) : match.group(0)!;
  },
);

bool _startsWordAt(String source, int i, String word) =>
    source.length >= i + word.length &&
    source.substring(i, i + word.length).toLowerCase() == word;

/// Whether the `@` at [i] opens an at-rule named [name] — and not one whose
/// name merely begins with it.
bool _startsAtRule(String source, int i, String name) {
  final end = i + 1 + name.length;
  return _startsWordAt(source, i + 1, name) &&
      (end >= source.length || !_isNameChar(source[end]));
}

bool _isNameChar(String c) => _nameChar.hasMatch(c);

final RegExp _nameChar = RegExp(r'[\w-]');

/// Where the string opening at [i] ends: at its closing quote, or where a
/// line breaks or the sheet does, which ends a CSS string too.
int _stringEnd(String source, int i) {
  final quote = source[i];
  var j = i + 1;
  while (j < source.length) {
    final c = source[j];
    if (c == r'\') {
      j += 2;
      continue;
    }
    if (c == quote) return j + 1;
    if (c == '\n' || c == '\r' || c == '\f') return j;
    j++;
  }
  return source.length;
}

/// Where the argument of a `url(` beginning at [i] ends, and where the
/// function does.
({int value, int next}) _urlEnd(String source, int i) {
  var j = i;
  while (j < source.length && ' \t\n\r\f'.contains(source[j])) {
    j++;
  }
  if (j < source.length && (source[j] == '"' || source[j] == "'")) {
    j = _stringEnd(source, j);
  }
  while (j < source.length && source[j] != ')') {
    j += source[j] == r'\' ? 2 : 1;
  }
  final value = math.min(j, source.length);
  return (value: value, next: math.min(value + 1, source.length));
}

/// Where the at-rule opening at [i] ends: past its `;`, past its block, or
/// where the block around it closes, and at the end of the sheet where
/// nothing ends it.
int _atRuleEnd(String source, int i) {
  var j = i;
  while (j < source.length) {
    final c = source[j];
    if (c == '"' || c == "'") {
      j = _stringEnd(source, j);
      continue;
    }
    if (c == ';') return j + 1;
    if (c == '}') return j;
    if (c == '{') {
      final close = source.indexOf('}', j);
      return close == -1 ? source.length : close + 1;
    }
    j++;
  }
  return source.length;
}

String _unquoted(String text) {
  if (text.length >= 2 &&
      (text[0] == '"' || text[0] == "'") &&
      text.endsWith(text[0])) {
    return text.substring(1, text.length - 1);
  }
  if (text.isNotEmpty && (text[0] == '"' || text[0] == "'")) {
    return text.substring(1);
  }
  return text;
}

/// [value] escaped to stand inside a double-quoted CSS string.
String _cssString(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\a ');

// ---------------------------------------------------------------------------
// Sizes.

/// [css] with every size a `font-size` or a `font` fixes read as a share of
/// the root, which is the reader's.
///
/// A book's `12pt` is what a browser sets at 16 pixels, which is the size a
/// reader's text is meant to be; so it becomes `1rem`, and a heading the
/// book set half as large again stays half as large again, at the reader's
/// size. A relative size is already a share of something the reader set, and
/// is left alone.
String _shareOfTheRoot(String css) => css.replaceAllMapped(
  RegExp(
    r'(?<=(?:^|[{;])\s*)(font-size|font)(\s*:\s*)([^;}]*)',
    caseSensitive: false,
  ),
  (match) =>
      '${match.group(1)}${match.group(2)}'
      '${_relativeSizes(match.group(3)!, shorthand: match.group(1)!.toLowerCase() == 'font')}',
);

/// What each absolute unit is worth in the pixels a browser's default size
/// is 16 of.
const Map<String, double> _pixels = {
  'px': 1,
  'pt': 4 / 3,
  'pc': 16,
  'in': 96,
  'cm': 96 / 2.54,
  'mm': 96 / 25.4,
  'q': 96 / 101.6,
};

/// What each size keyword is, as a share of the default size.
const Map<String, double> _keywords = {
  'xx-small': 0.5625,
  'x-small': 0.625,
  'small': 0.8125,
  'medium': 1,
  'large': 1.125,
  'x-large': 1.5,
  'xx-large': 2,
  'xxx-large': 3,
};

/// A size, fixed in a unit or by a keyword.
final RegExp _fixedSize = RegExp(
  r'(?<![\w.-])(?:(\d*\.?\d+)(px|pt|pc|in|cm|mm|q)|(xxx-large|xx-large|'
  r'x-large|large|medium|small|x-small|xx-small))(?![\w-])',
  caseSensitive: false,
);

/// [value] with its fixed sizes made shares of the root — only the first in
/// a [shorthand], which is the one that is a size: every word after it is a
/// family's name, and `Large Print` is a face rather than a size.
String _relativeSizes(String value, {required bool shorthand}) {
  String share(Match match) {
    final keyword = match.group(3);
    final share = keyword != null
        ? _keywords[keyword.toLowerCase()]!
        : double.parse(match.group(1)!) *
              _pixels[match.group(2)!.toLowerCase()]! /
              16;
    return '${_number(share)}rem';
  }

  if (!shorthand) return value.replaceAllMapped(_fixedSize, share);
  final first = _fixedSize.firstMatch(value);
  return first == null
      ? value
      : value.replaceRange(first.start, first.end, share(first));
}
