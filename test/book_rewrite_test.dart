import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/features/reader/book_markup.dart';
import 'package:patra/src/features/reader/book_rewrite.dart';
import 'package:patra/src/settings/reading_settings.dart';
import 'package:patra/src/theme.dart';

/// What the reader chose, where a test does not say otherwise.
const BookSetting _setting = (
  textSize: 18,
  lineHeight: 1.6,
  face: ReadingFace.serif,
);

/// The pictures and fonts already on the device, by the name the page gave
/// them. Anything else has no local file.
const _onDevice = {
  'OEBPS/images/worm.jpg': 'pictures/0.jpg',
  // As Kavita writes it: a bare `&`, and the name the parser reads too.
  '//kavita.example/api/book/7/book-resources?apiKey=k&file=cover.jpg':
      'pictures/1.jpg',
  'OEBPS/fonts/face.otf': 'fonts/0.otf',
};

String _rewrite(
  String html, {
  String? language = 'fr',
  BookSetting setting = _setting,
  String? Function(String src)? localFile,
  FaceFiles? faceFiles,
}) => rewriteBookPage(
  html,
  language: language,
  setting: setting,
  localFile: localFile ?? (src) => _onDevice[src],
  faceFiles: faceFiles,
);

/// Everything in [document] a browser could fetch from, execute, or be told
/// to go to: the whole of the document, lowered, so that case cannot hide it.
String _lowered(String document) => document.toLowerCase();

/// What [document] carries of the page, without what the app put around it.
String _body(String document) => document.substring(document.indexOf('<body'));

/// The tags of [document], as the one grammar a page is walked with reads
/// them.
List<String> _tags(String document) => [
  for (final piece in markupPieces(document))
    if (piece.isTag) piece.text,
];

void main() {
  group('nothing that can execute survives', () {
    const scripts = {
      'a plain script': '<p>a</p><script>alert(1)</script><p>b</p>',
      'a script in capitals': '<SCRIPT>alert(1)</SCRIPT>',
      'a script in mixed case': '<ScRiPt type="text/javascript">x()</sCrIpT>',
      'a self-closing script': '<script src="evil.js"/><p>b</p>',
      'a script with a spaced end tag': '<script>alert(1)</script  ><p>b</p>',
      'a script that is never closed': '<p>a</p><script>alert(1)',
      'a script inside a script': '<script><script>x()</script>y()</script>',
      'a script whose source hides a tag':
          '<script>if (a<b) { document.write("<p>") }</script>',
      'a script whose attribute hides a closing bracket':
          '<script data-x="a>b">alert(1)</script>',
      'a script inside an SVG': '<svg><script>alert(1)</script></svg>',
      'a namespaced script': '<svg><svg:script>alert(1)</svg:script></svg>',
      'a script inside a comment that is not closed':
          '<p>a</p><!-- <script>alert(1)</script>',
      'a script behind a CDATA section':
          '<![CDATA[ <script>alert(1)</script> ]]>',
    };
    for (final MapEntry(key: name, value: html) in scripts.entries) {
      test(name, () {
        final document = _lowered(_rewrite(html));
        expect(document, isNot(contains('<script')));
        expect(document, isNot(contains('script>')));
        expect(document, isNot(contains('alert(1)<')));
      });
    }

    test('the words around a script are kept', () {
      final document = _rewrite(
        '<p>before</p><script>x()</script><p>after</p>',
      );
      expect(document, contains('before'));
      expect(document, contains('after'));
      expect(document, isNot(contains('x()')));
    });

    test('a self-closing script keeps what follows it', () {
      // What Kavita itself writes for one (`EscapeTags` closes it), and in the
      // XHTML a book is made of it really does close.
      final document = _rewrite('<script src="evil.js"/><p>after</p>');
      expect(document, contains('<p'));
      expect(document, contains('after'));
    });

    const handlers = {
      'a handler': '<img src="OEBPS/images/worm.jpg" onerror="alert(1)">',
      'a handler in capitals': '<p ONCLICK="alert(1)">a</p>',
      'a handler in mixed case': '<body OnLoAd="alert(1)"><p>a</p></body>',
      'a handler with no quotes': '<p onclick=alert(1)>a</p>',
      'a handler in single quotes': "<p onmouseover='alert(1)'>a</p>",
      'a handler after a slash': '<img/onerror=alert(1) src=x>',
      'a handler with no space before it':
          '<img src="OEBPS/images/worm.jpg"onerror="alert(1)">',
      'a handler with spaces round its equals': '<p onclick = "alert(1)">a</p>',
      'a handler on an SVG': '<svg onload="alert(1)"><circle r="1"/></svg>',
      'a handler behind a quoted closing bracket':
          '<p title="a>b" onclick="alert(1)">a</p>',
      'a handler on a closing tag': '<p>a</p onclick="alert(1)">',
    };
    for (final MapEntry(key: name, value: html) in handlers.entries) {
      test(name, () {
        final document = _rewrite(html);
        for (final tag in _tags(document)) {
          expect(
            RegExp(
              r'[\s/"'
              "'"
              r']on[a-z]+\s*=',
              caseSensitive: false,
            ).hasMatch(tag),
            isFalse,
            reason: tag,
          );
        }
      });
    }

    test('a javascript: link goes nowhere', () {
      for (final html in const [
        '<a href="javascript:alert(1)">a</a>',
        '<a href="JaVaScRiPt:alert(1)">a</a>',
        '<a href=" javascript:alert(1)">a</a>',
        '<a href="java\tscript:alert(1)">a</a>',
        '<a href="&#106;avascript:alert(1)">a</a>',
        '<a href="&#x6A;avascript:alert(1)">a</a>',
        '<a href="javascript&colon;alert(1)">a</a>',
        '<a xlink:href="javascript:alert(1)">a</a>',
      ]) {
        final document = _lowered(_rewrite(html));
        expect(document, isNot(contains('javascript')), reason: html);
        expect(document, isNot(contains('&#106;')), reason: html);
        expect(document, isNot(contains('&colon;')), reason: html);
      }
    });

    test('an element that can hold a document of its own is gone', () {
      for (final html in const [
        '<iframe src="OEBPS/images/worm.jpg"></iframe>',
        '<iframe srcdoc="&lt;script&gt;alert(1)&lt;/script&gt;"></iframe>',
        '<object data="OEBPS/images/worm.jpg"></object>',
        '<embed src="OEBPS/images/worm.jpg">',
        '<frameset><frame src="x"></frameset>',
      ]) {
        final document = _lowered(_rewrite(html));
        for (final element in const ['iframe', 'object', 'embed', 'frame']) {
          expect(document, isNot(contains('<$element')), reason: html);
        }
        expect(document, isNot(contains('srcdoc')), reason: html);
      }
    });

    test('a book cannot redirect, rebase or reset the policy', () {
      final document = _lowered(
        _rewrite(
          '<meta http-equiv="refresh" content="0;url=https://evil.example">'
          '<base href="https://evil.example/">'
          '<meta http-equiv="Content-Security-Policy" content="default-src *">'
          '<p>a</p>',
        ),
      );
      expect(document, isNot(contains('refresh')));
      expect(document, isNot(contains('<base')));
      expect(document, isNot(contains('evil')));
      expect(document, isNot(contains('default-src *')));
    });

    test('noscript cannot smuggle markup past the pass', () {
      // With scripting on, a browser reads a noscript's contents as raw text
      // up to the first `</noscript` — inside an attribute or not.
      final document = _lowered(
        _rewrite(
          '<noscript><p title="</noscript><img src=x onerror=alert(1)>">'
          '</noscript>',
        ),
      );
      expect(document, isNot(contains('<noscript')));
      expect(document, isNot(contains('onerror')));
    });

    test('a stylesheet inside an SVG cannot open a tag', () {
      // In an SVG a style element is not raw text: its contents are markup,
      // and an HTML tag in them breaks out of the SVG altogether.
      final document = _lowered(
        _rewrite('<svg><style><img src=x onerror=alert(1)></style></svg>'),
      );
      expect(document, isNot(contains('<img')));
    });

    test('a stylesheet cannot close itself early', () {
      final document = _lowered(
        _rewrite(
          '<style>p { content: "</style><img src=x onerror=alert(1)>" }'
          '</style>',
        ),
      );
      expect(document, isNot(contains('onerror=alert')));
    });

    test('the attributes that forge the app\'s own marks are the app\'s', () {
      final document = _rewrite('<p data-patra-block="99">a</p>');
      expect(document, isNot(contains('"99"')));
    });
  });

  group('no remote address survives', () {
    const remote = {
      'a picture': '<img src="https://evil.example/pixel.gif">',
      'a picture with no scheme': '<img src="//evil.example/pixel.gif">',
      'a picture with backslashes': r'<img src="\\evil.example\pixel.gif">',
      'a picture in capitals': '<IMG SRC="HTTPS://EVIL.EXAMPLE/PIXEL.GIF">',
      'a picture named with entities':
          '<img src="&#104;ttps&#58;//evil.example/pixel.gif">',
      'a picture set': '<img srcset="https://evil.example/pixel.gif 2x">',
      'an SVG image': '<svg><image href="https://evil.example/p.gif"/></svg>',
      'an SVG image by xlink':
          '<svg><image xlink:href="https://evil.example/p.gif"/></svg>',
      'an SVG use': '<svg><use href="https://evil.example/s.svg#x"/></svg>',
      'a video poster': '<video poster="https://evil.example/p.gif"></video>',
      'a video source':
          '<video><source src="https://evil.example/v.mp4"></video>',
      'an audio track': '<audio src="https://evil.example/a.mp3"></audio>',
      'a legacy background': '<table background="https://evil.example/t.gif">',
      'a stylesheet link':
          '<link rel="stylesheet" href="https://evil.example/s.css">',
      'a ping': '<a href="#n" ping="https://evil.example/ping">a</a>',
      'a form':
          '<form action="https://evil.example/f"><button '
          'formaction="https://evil.example/g">go</button></form>',
      'a link out': '<a href="https://evil.example/">a</a>',
      'a background in a style attribute':
          '<p style="background: url(https://evil.example/b.gif)">a</p>',
      'a quoted background in a style attribute':
          "<p style=\"background-image: url('https://evil.example/b.gif')\">",
      'a background in a stylesheet':
          '<style>p { background: url("https://evil.example/b.gif") }</style>',
      'a background in capitals':
          '<style>p { background: URL(https://evil.example/b.gif) }</style>',
      'a url written with escapes':
          r'<style>p { background: \75 rl(https://evil.example/b.gif) }'
          '</style>',
      'a url written with a letter escape':
          r'<style>p { background: u\rl(https://evil.example/b.gif) }</style>',
      'a url in an attribute written with entities':
          '<p style="background: &#117;rl(https://evil.example/b.gif)">a</p>',
      'an import': '<style>@import "https://evil.example/s.css";</style>',
      'an import by url':
          '<style>@import url(https://evil.example/s.css) screen;</style>',
      'an import with no semicolon':
          '<style>@import "https://evil.example/s.css"</style>',
      'a font source':
          '<style>@font-face { font-family: X; '
          'src: url(https://evil.example/f.woff2) format("woff2") }</style>',
      'an image set':
          '<style>p { background: image-set("https://evil.example/b.png" 1x)'
          ' }</style>',
      'a webkit image set':
          '<style>p { background: -webkit-image-set('
          'url(https://evil.example/b.png) 1x) }</style>',
      'a url never closed':
          '<style>p { background: url(https://evil.example/b.gif</style>',
    };
    for (final MapEntry(key: name, value: html) in remote.entries) {
      test(name, () {
        final document = _lowered(_rewrite(html));
        expect(document, isNot(contains('evil')), reason: document);
      });
    }

    test('an SVG paint or effect that names an address', () {
      for (final attribute in const [
        'fill',
        'stroke',
        'filter',
        'mask',
        'clip-path',
        'marker-end',
        'cursor',
      ]) {
        final document = _lowered(
          _rewrite(
            '<svg><rect $attribute="url(https://evil.example/x.svg#g)"/>'
            '</svg>',
          ),
        );
        expect(document, isNot(contains('evil')), reason: attribute);
      }
    });

    test('an SVG animation cannot put an address back', () {
      for (final html in const [
        '<svg><a><set attributeName="href" to="https://evil.example"/>'
            'x</a></svg>',
        '<svg><image><animate attributeName="href" '
            'values="https://evil.example/p.gif"/></image></svg>',
        '<svg><animateMotion from="https://evil.example"/></svg>',
      ]) {
        final document = _lowered(_rewrite(html));
        expect(document, isNot(contains('evil')), reason: html);
      }
    });

    test('an image function', () {
      final document = _lowered(
        _rewrite(
          '<style>p { background: image("https://evil.example/a.png"), '
          'cross-fade("https://evil.example/b.png", red 50%) }</style>',
        ),
      );
      expect(document, isNot(contains('evil')));
    });

    test('data a page carries is a picture, never a document', () {
      final document = _lowered(
        _rewrite('<svg><use href="data:image/svg+xml,%3Csvg%3E"/></svg>'),
      );
      expect(document, isNot(contains('href="data:')));
    });

    test('a caller that names a remote file cannot put it back', () {
      final document = _lowered(
        _rewrite(
          '<img src="OEBPS/images/worm.jpg">'
          '<style>p { background: url(OEBPS/images/worm.jpg) }</style>',
          localFile: (_) => 'https://evil.example/pixel.gif',
        ),
      );
      expect(document, isNot(contains('evil')));
    });

    test('a link within the page keeps its target', () {
      final document = _rewrite('<a href="#note-1">1</a>');
      expect(document, contains('href="#note-1"'));
    });

    test('a picture carried inside the page stays where it is', () {
      // A copy saved before a copy was a directory carries its pictures as
      // data (ADR-0013): such a page is still valid and must keep opening.
      const carried = 'data:;base64,AQID';
      final document = _rewrite('<img src="$carried">');
      expect(document, contains('src="$carried"'));
    });
  });

  group('every picture is a local file', () {
    test('named by a path inside the book', () {
      final document = _rewrite('<p><img src="OEBPS/images/worm.jpg"/></p>');
      expect(document, contains('src="pictures/0.jpg"'));
      expect(document, isNot(contains('OEBPS')));
    });

    test('named by the address Kavita writes for one', () {
      final document = _rewrite(
        '<img src="//kavita.example/api/book/7/book-resources?apiKey=k&'
        'file=cover.jpg">',
      );
      expect(document, contains('src="pictures/1.jpg"'));
      expect(document, isNot(contains('apiKey')));
    });

    test('named in an SVG, by either attribute', () {
      for (final attribute in const ['href', 'xlink:href']) {
        final document = _rewrite(
          '<svg><image $attribute="OEBPS/images/worm.jpg"/></svg>',
        );
        expect(document, contains('$attribute="pictures/0.jpg"'));
      }
    });

    test('named in a stylesheet', () {
      final document = _rewrite(
        '<style>div { background: url("OEBPS/images/worm.jpg") }</style>',
      );
      expect(document, contains('url("pictures/0.jpg")'));
    });

    test('a font the book ships is its local file', () {
      final document = _rewrite(
        '<style>@font-face { font-family: Face; '
        "src: url('OEBPS/fonts/face.otf') }</style>",
      );
      expect(document, contains('url("fonts/0.otf")'));
    });

    test('a picture with no local file is named by nothing', () {
      final document = _rewrite('<img src="OEBPS/images/missing.jpg" alt="x">');
      expect(document, isNot(contains('missing')));
      expect(document, contains('alt="x"'));
    });
  });

  group('the content policy', () {
    test('is the first thing in the document', () {
      final document = _rewrite(
        '<style>@font-face { src: url(OEBPS/fonts/face.otf) }</style><p>a</p>',
      );
      final first = _tags(document).firstWhere(
        (tag) =>
            !RegExp(r'^<(!|/?html|/?head)', caseSensitive: false).hasMatch(tag),
      );
      expect(first, startsWith('<meta http-equiv="Content-Security-Policy"'));
    });

    test('allows nothing remote and nothing to run', () {
      final document = _rewrite('<p>a</p>');
      final policy = RegExp(r'Content-Security-Policy" content="([^"]*)"')
          .firstMatch(document)!
          .group(1)!;
      expect(policy, contains("default-src 'none'"));
      expect(policy, contains("script-src 'none'"));
      expect(policy, isNot(contains('http')));
      expect(policy, isNot(contains('*')));
    });
  });

  group('the viewport', () {
    // Content wider than the screen — a long line of code, a wide table —
    // lets an engine grow the layout viewport past the screen so it can zoom
    // out to show it, and then what is on screen is a window somewhere
    // inside that viewport: measured on a device at four screens tall, with
    // the screen at the bottom of it, which put a reading position three
    // screens behind the words the reader was on (#128).
    test('is never larger than the screen', () {
      final document = _rewrite('<pre>${'x' * 400}</pre>');
      final viewport = RegExp(r'<meta name="viewport" content="([^"]*)"')
          .firstMatch(document)!
          .group(1)!
          .split(',')
          .map((part) => part.trim())
          .toList();
      expect(viewport, contains('width=device-width'));
      expect(viewport, contains('initial-scale=1'));
      expect(viewport, contains('minimum-scale=1'));
    });
  });

  group("the reader's three settings", () {
    String overrides(String document) => RegExp(
      r'@layer patra \{.*?\n\}',
      dotAll: true,
    ).firstMatch(document)!.group(0)!;

    test('are imposed in a layer that comes before the book', () {
      final document = _rewrite('<style>p { font-size: 30px }</style>');
      final layer = document.indexOf('@layer patra');
      expect(layer, isNonNegative);
      expect(layer, lessThan(document.indexOf('<body')));
      final css = overrides(document);
      expect(css, contains('font-size: 18px !important'));
      expect(css, contains('line-height: 1.6 !important'));
      expect(css, contains('font-family: "$fontLiterata" !important'));
    });

    test('follow the face chosen', () {
      final sans = overrides(
        _rewrite(
          '<p>a</p>',
          setting: (textSize: 16, lineHeight: 1.2, face: ReadingFace.sans),
        ),
      );
      expect(sans, contains('font-family: "$fontAtkinsonHyperlegibleNext"'));
      expect(sans, contains('font-size: 16px !important'));
      expect(sans, contains('line-height: 1.2 !important'));
    });

    test('the face chosen is not imposed on code', () {
      // A reading face is for prose. Code set in it loses the fixed width its
      // columns are aligned by — so code, and whatever a highlighter wraps
      // inside it, keeps the book's own face or the engine's monospace.
      final css = overrides(_rewrite('<pre><code><span>a</span></code></pre>'));
      final rule = RegExp(
        r'([^{}]*)\{ font-family: "' + fontLiterata + r'" !important; \}',
      ).firstMatch(css)!;
      const code = ':is(pre, code, kbd, samp, tt)';
      // A selector list, split where a comma separates two selectors rather
      // than where it separates the arguments of one.
      final selectors = <String>[];
      var depth = 0, from = 0;
      final list = rule.group(1)!;
      for (var i = 0; i < list.length; i++) {
        if (list[i] == '(') depth++;
        if (list[i] == ')') depth--;
        if (list[i] == ',' && depth == 0) {
          selectors.add(list.substring(from, i).trim());
          from = i + 1;
        }
      }
      selectors.add(list.substring(from).trim());
      expect(selectors, hasLength(6));
      for (final selector in selectors) {
        expect(
          selector,
          startsWith(':not($code, $code *)'),
          reason: '$selector reaches code',
        );
      }
    });

    test("the book's own face imposes no face at all", () {
      final css = overrides(
        _rewrite(
          '<p>a</p>',
          setting: (textSize: 16, lineHeight: 1.55, face: ReadingFace.book),
        ),
      );
      expect(css, isNot(contains('font-family')));
    });

    test('a size the book fixes becomes a share of the reader\'s', () {
      // A layer outranks every `!important` the book makes, but only on the
      // element it sets — so the root carries the reader's size, and a size
      // the book fixed in points is read as a share of a default one.
      final document = _rewrite(
        '<style>p { font-size: 12pt } h1 { font-size: 24px !important }'
        ' small { font-size: x-small } .n { font: italic 8px/2 serif }'
        '</style>',
      );
      expect(document, contains('p { font-size: 1rem }'));
      expect(document, contains('h1 { font-size: 1.5rem !important }'));
      expect(document, contains('small { font-size: 0.625rem }'));
      expect(document, contains('font: italic 0.5rem/2 serif'));
    });

    test('a relative size the book declares is left alone', () {
      final document = _rewrite(
        '<style>h1 { font-size: 2em } h2 { font-size: 150% }</style>',
      );
      expect(document, contains('h1 { font-size: 2em }'));
      expect(document, contains('h2 { font-size: 150% }'));
    });

    test('an inline style cannot outrank them', () {
      // A style attribute's `!important` beats a stylesheet's, layer or not,
      // so it loses the mark on exactly the three the reader owns.
      final document = _rewrite(
        '<p style="font-size: 40px !important; line-height: 3 !IMPORTANT;'
        ' font-family: Comic !important; color: red !important">a</p>',
      );
      expect(document, contains('font-size: 2.5rem;'));
      expect(document, contains('line-height: 3;'));
      expect(document, contains('font-family: Comic;'));
      expect(document, contains('color: red !important'));
    });

    test('a comment is not a way round them', () {
      final document = _rewrite(
        '<style>p{/**/font-size:24px}</style>'
        '<p style="color:red;/**/font-size:80px !important">a</p>'
        '<p style="line-height:9!/**/important">b</p>',
      );
      expect(document, contains('p{font-size:1.5rem}'));
      expect(document, contains('font-size:5rem"'));
      expect(_body(document), isNot(contains('important')));
    });

    test('a shadow root is not a way round them', () {
      // The layer's `*` does not reach inside a shadow root, so a template
      // the engine would attach as one is left a template, which it draws as
      // nothing.
      final document = _lowered(
        _rewrite(
          '<div><template shadowrootmode="open" shadowroot="open">'
          '<style>p { font-family: Comic !important }</style><p>a</p>'
          '</template></div>',
        ),
      );
      expect(document, isNot(contains('shadowroot')));
    });

    test('the face reaches the parts of a line a book styles apart', () {
      final css = overrides(_rewrite('<p>a</p>'));
      for (final part in const ['::first-letter', '::first-line', '::marker']) {
        expect(css, contains(part));
      }
    });

    test("a family's name in a font shorthand is not a size", () {
      final document = _rewrite('<style>p { font: 12px Large Print }</style>');
      expect(document, contains('font: 0.75rem Large Print'));
    });

    test('a legacy font size is not a way round them', () {
      final document = _rewrite('<font size="7" color="red">a</font>');
      expect(document, isNot(contains('size=')));
      expect(document, contains('color="red"'));
    });
  });

  group('every other declaration survives', () {
    test('in a stylesheet', () {
      const css =
          '.body p { text-align: left; text-indent: 1.5em; margin: 0 }\n'
          '.body .it { font-style: italic; font-weight: bold }\n'
          '@media (min-width: 40em) { .body p { column-count: 2 } }';
      final document = _rewrite('<style>$css</style><p>a</p>');
      expect(document, contains(css));
    });

    test('in a style attribute', () {
      final document = _rewrite(
        '<p style="text-align: right; color: #333">a</p>',
      );
      expect(document, contains('style="text-align: right; color: #333"'));
    });

    test('on the elements themselves', () {
      final document = _rewrite(
        '<p class="first" id="c1" lang="en" dir="rtl" epub:type="z">a</p>'
        '<ruby>漢<rt>kan</rt></ruby>'
        '<td colspan="2">x</td>',
      );
      expect(document, contains('class="first"'));
      expect(document, contains('id="c1"'));
      expect(document, contains('lang="en"'));
      expect(document, contains('dir="rtl"'));
      expect(document, contains('epub:type="z"'));
      expect(document, contains('<rt>kan</rt>'));
      expect(document, contains('colspan="2"'));
    });

    test('with the words and the entities of the page', () {
      final document = _rewrite(
        '<p>The spice must flow, &amp; the worm <b>follows</b>&nbsp;—'
        ' 1 &lt; 2.</p>',
      );
      expect(
        document,
        contains(
          'The spice must flow, &amp; the worm <b>follows</b>&nbsp;—'
          ' 1 &lt; 2.',
        ),
      );
    });

    test('with an attribute that needed escaping still escaped', () {
      final document = _rewrite('<img alt=\'say "hi" &amp; &eacute;\'>');
      expect(document, contains('alt="say &quot;hi&quot; &amp; &eacute;"'));
    });
  });

  group('the face the reader chose is one the engine has', () {
    // The app's faces are bundled with the app and nowhere else: an engine
    // told to set a page in Literata has no Literata unless the document says
    // where its files are.
    const files = (
      roman: 'file:///cache/fonts/roman.ttf',
      italic: 'file:///cache/fonts/italic.ttf',
    );

    List<String> faces(String document) =>
        RegExp(r'@font-face \{[^}]*\}')
            .allMatches(document)
            .map((match) => match.group(0)!)
            .toList();

    test('is declared, roman and italic, before the layer imposing it', () {
      final document = _rewrite('<p>a</p>', faceFiles: files);
      final declared = faces(document);
      expect(declared, hasLength(2));
      expect(declared[0], contains('font-family: "$fontLiterata"'));
      expect(declared[0], contains('url("${files.roman}")'));
      expect(declared[0], contains('font-style: normal'));
      expect(declared[1], contains('url("${files.italic}")'));
      expect(declared[1], contains('font-style: italic'));
      expect(
        document.indexOf('@font-face'),
        lessThan(document.indexOf('@layer patra')),
      );
    });

    test('follows the face chosen', () {
      final document = _rewrite(
        '<p>a</p>',
        faceFiles: files,
        setting: (textSize: 16, lineHeight: 1.2, face: ReadingFace.sans),
      );
      expect(
        faces(document).first,
        contains('font-family: "$fontAtkinsonHyperlegibleNext"'),
      );
    });

    test("is not declared where the book's own face was chosen", () {
      final document = _rewrite(
        '<p>a</p>',
        faceFiles: files,
        setting: (textSize: 16, lineHeight: 1.55, face: ReadingFace.book),
      );
      expect(faces(document), isEmpty);
    });

    test('is never declared from anywhere but the device', () {
      final document = _lowered(
        _rewrite(
          '<p>a</p>',
          faceFiles: (
            roman: 'https://fonts.example/roman.ttf',
            italic: '//fonts.example/italic.ttf',
          ),
        ),
      );
      expect(document, isNot(contains('fonts.example')));
    });
  });

  group("the reader's canvas", () {
    String overrides(String document) => RegExp(
      r'@layer patra \{.*?\n\}',
      dotAll: true,
    ).firstMatch(document)!.group(0)!;

    test('is what a page with no colours of its own is set on', () {
      final css = overrides(_rewrite('<p>a</p>'));
      final canvas = RegExp(r'html \{[^}]*background-color[^}]*\}')
          .firstMatch(css)!
          .group(0)!;
      expect(canvas, contains('background-color: #000000'));
      expect(canvas, contains('color: #f3eee3'));
      // A default and nothing more: the book's own colours are its design.
      expect(canvas, isNot(contains('!important')));
    });

    test('sets a page shorter than the screen in the middle of it', () {
      // A page is a page, not a flow: a cover hung off the top edge is a
      // picture pinned to the ceiling — the rule the app's own renderer
      // keeps (`BookPageBody`), which the engine has to be told.
      final css = overrides(
        _rewrite('<p><img src="OEBPS/images/worm.jpg"></p>'),
      );
      final page = RegExp(r'html \{[^}]*align-content[^}]*\}')
          .firstMatch(css)!
          .group(0)!;
      expect(page, contains('display: grid'));
      expect(page, contains('align-content: center'));
      // The screen's height, room for the counter included: never taller, or
      // a page that fits would scroll.
      expect(page, contains('min-height: 100vh'));
      expect(page, contains('box-sizing: border-box'));
      expect(page, isNot(contains('!important')));
    });

    test("does not outrank a book's own colours", () {
      final document = _rewrite(
        '<style>p { color: #333; background: white }</style><p>a</p>',
      );
      expect(document, contains('p { color: #333; background: white }'));
    });
  });

  group('the language', () {
    String? declared(String document) => RegExp(r'<html([^>]*)>')
        .firstMatch(document)!
        .group(1)!
        .let(
          (attributes) =>
              RegExp(r'lang="([^"]*)"').firstMatch(attributes)?.group(1),
        );

    test('is carried where it is known', () {
      expect(declared(_rewrite('<p>a</p>', language: 'fr')), 'fr');
      expect(declared(_rewrite('<p>a</p>', language: 'en-GB')), 'en-GB');
    });

    test('is absent where it is not', () {
      expect(declared(_rewrite('<p>a</p>', language: null)), isNull);
      expect(declared(_rewrite('<p>a</p>', language: '')), isNull);
      expect(declared(_rewrite('<p>a</p>', language: '  ')), isNull);
    });

    test('is absent where what was declared is not a language', () {
      final document = _rewrite('<p>a</p>', language: 'fr" onload="alert(1)');
      expect(declared(document), isNull);
      expect(document, isNot(contains('onload')));
    });
  });

  group('the alignment', () {
    // Justification is the book's, like the rest of its composition; the
    // app's default stands in only where the book is silent (#130). It is a
    // default in the reader's layer, on the root alone: every declaration a
    // book makes outranks a layered one that is not `!important`, and one set
    // on the root reaches an element only by inheritance, which any
    // declaration of the book's on that element or above it outranks too.
    List<String> declarations(String document, String property) => [
      for (final rule in RegExp(r'([^{}\n]+)\{([^}]*)\}').allMatches(
        RegExp(
          r'@layer patra \{.*?\n\}',
          dotAll: true,
        ).firstMatch(document)!.group(0)!.replaceFirst('@layer patra {', ''),
      ))
        for (final declaration in rule.group(2)!.split(';'))
          if (declaration.trim().startsWith('$property:'))
            '${rule.group(1)!.trim()} { ${declaration.trim()} }',
    ];

    test('justifies and hyphenates where the language is known', () {
      final document = _rewrite('<p>a</p>', language: 'fr');
      expect(
        declarations(document, 'text-align'),
        contains('html { text-align: justify }'),
      );
      expect(
        declarations(document, 'hyphens'),
        contains('html { hyphens: auto }'),
      );
      // WebKit — the engine iOS embeds — reads the property only prefixed.
      expect(
        declarations(document, '-webkit-hyphens'),
        contains('html { -webkit-hyphens: auto }'),
      );
    });

    test('leaves the page ragged right where the language is not known', () {
      // Without a dictionary, justifying opens the rivers #119 measured; and
      // an engine told no language hyphenates nothing on its own.
      // `und`, `mul` and `zxx` are tags that say the language is not known,
      // is several, or is none: no dictionary answers any of them.
      for (final language in [
        null,
        '',
        'fr" onload="alert(1)',
        'und',
        'MUL',
        'zxx',
      ]) {
        final document = _rewrite('<p>a</p>', language: language);
        expect(declarations(document, 'text-align'), isEmpty);
        expect(declarations(document, 'hyphens'), isEmpty);
        expect(declarations(document, '-webkit-hyphens'), isEmpty);
      }
    });

    test('leaves code unbroken and unstretched', () {
      // A hyphen drawn inside an identifier is a character the listing does
      // not have, and a stretched line of code is columns out of line.
      final document = _rewrite('<pre><code>a</code></pre>', language: 'en');
      for (final (property, value) in [
        ('text-align', 'start'),
        ('hyphens', 'manual'),
        ('-webkit-hyphens', 'manual'),
      ]) {
        expect(
          declarations(document, property),
          contains(':is(pre, code, kbd, samp, tt) { $property: $value }'),
        );
      }
    });

    test('is outranked by an alignment the book declares', () {
      for (final align in ['left', 'start', 'justify']) {
        final document = _rewrite(
          '<style>p { text-align: $align }</style>'
          '<p style="text-align: $align">a</p>',
        );
        expect(document, contains('p { text-align: $align }'));
        expect(document, contains('style="text-align: $align"'));
        // A default, never an override, and nowhere but on the root.
        for (final property in ['text-align', 'hyphens', '-webkit-hyphens']) {
          for (final declaration in declarations(document, property)) {
            expect(
              declaration,
              anyOf(startsWith('html {'), startsWith(':is(pre, code')),
            );
            expect(declaration, isNot(contains('!important')));
          }
        }
      }
    });
  });

  group('every block is named', () {
    const page =
        '<h1>Title</h1><p>One</p><blockquote><p>Two</p></blockquote>'
        '<ul><li>Three</li></ul><div><p>Four</p></div><p>Five</p>';

    List<String> blocks(String document) => [
      for (final match in RegExp(
        r'<(\w+)[^>]*data-patra-block="([^"]*)"',
      ).allMatches(document))
        '${match.group(1)}:${match.group(2)}',
    ];

    test('once each, in the order they are read', () {
      expect(blocks(_rewrite(page)), [
        'h1:0',
        'p:1',
        'blockquote:2',
        'p:3',
        'li:4',
        'div:5',
        'p:6',
        'p:7',
      ]);
    });

    test('the same across two runs over the same page', () {
      expect(_rewrite(page), _rewrite(page));
      expect(blocks(_rewrite(page)), blocks(_rewrite(page)));
    });

    test('not by the settings it is set in', () {
      expect(
        blocks(_rewrite(page)),
        blocks(
          _rewrite(
            page,
            language: null,
            setting: (textSize: 22, lineHeight: 2, face: ReadingFace.book),
          ),
        ),
      );
    });
  });

  group('malformed markup', () {
    test('a stray bracket with nothing after it', () {
      final document = _rewrite('<p>1 < 2');
      expect(document, contains('1 &lt; 2'));
    });

    test('a bracket that is not a tag', () {
      final document = _rewrite('<p>a <3 b</p><p>c</p>');
      expect(document, contains('<p data-patra-block="1">c</p>'));
      expect(document, isNot(contains('<3 b')));
    });

    test('an attribute whose quote never closes', () {
      final document = _lowered(
        _rewrite('<p title="a>b onclick=alert(1)>c</p>'),
      );
      for (final tag in _tags(document)) {
        expect(tag, isNot(contains('onclick')));
      }
    });

    test('a quote in the middle of a bare value opens nothing', () {
      // A browser ends `b="c` at the `>`: the quote came after the value
      // began, so the handler after it is words, not an attribute.
      final document = _rewrite('<p a=b="c>d" onclick=x>t</p>');
      expect(document, contains('<p a="b=&quot;c" data-patra-block="0">'));
      expect(_tags(document).where((tag) => tag.contains('onclick')), isEmpty);
    });

    test('an equals where a name begins starts a name, not a value', () {
      final document = _rewrite('<p ="x>y" onclick=alert(1)>t</p>');
      expect(document, contains('<p data-patra-block="0">y"'));
      expect(_tags(document).where((tag) => tag.contains('onclick')), isEmpty);
    });

    test('a tag that never ends', () {
      final document = _lowered(
        _rewrite('<p>a</p><img src=x onerror=alert(1)'),
      );
      expect(document, isNot(contains('<img')));
    });

    test('nothing at all', () {
      final document = _rewrite('');
      expect(document, contains('<body>'));
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
