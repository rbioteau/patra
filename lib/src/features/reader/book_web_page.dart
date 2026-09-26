/// One page of a book, drawn by the platform's web engine (ADR-0013, #127).
///
/// What the engine is given has already been made inert and self-contained by
/// the rewrite pass (`book_rewrite.dart`), so nothing here decides what a book
/// may do: this is the host, and nothing more. JavaScript is enabled for the
/// app's own bridge and for nothing else — the page's own scripts are gone
/// before it gets here, and its policy runs none — because the room there is
/// to scroll is wrapped by no API at any layer, and a place in a page is a
/// block the rewrite named and a fraction down it (`BookAnchor`, #128), which
/// only a script inside the page can measure.
///
/// The engine is the platform's, reached through the official plugin: there
/// is none on Linux, and none under a test binding, which is why the reader
/// asks [bookWebEngineProvider] before it draws one and draws the page itself
/// where the answer is no.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme.dart';
import 'book_document.dart';
import 'book_page.dart';
import 'book_rewrite.dart';

/// Whether this build has a web engine to draw a book's page in: the two
/// platforms the app ships to do, and Linux and a test binding do not.
///
/// A provider rather than a test at the call site so a test can say which
/// reader it is asking about — an engine, once registered, cannot be
/// unregistered.
final bookWebEngineProvider = Provider<bool>(
  (ref) => WebViewPlatform.instance != null,
);

/// The name the app's bridge answers to inside a page. Nothing of the page's
/// own can call it: its scripts do not survive the rewrite.
const String bookBridge = 'PatraBridge';

/// One page of a book, loaded into the web engine from [file].
class BookWebPage extends StatefulWidget {
  const BookWebPage({
    super.key,
    required this.file,
    required this.html,
    required this.language,
    required this.setting,
    required this.files,
    this.faceFiles,
    this.anchor,
    this.onScroll,
  });

  /// Where the document is written and loaded from: at the root of the
  /// directory [files] are under, since that directory is all an engine on
  /// iOS is allowed to read.
  final File file;

  /// The page as the server handed it over, or as a copy stored it.
  final String html;

  /// The book's own declared language, or null where nobody recorded one.
  final String? language;

  /// What the reader chose the book be set in.
  final BookSetting setting;

  /// The files the page names, already on the device.
  final BookPageFiles files;

  /// Where the face [setting] names is set from.
  final FaceFiles? faceFiles;

  /// Where in the page the reader was, or null for the top.
  final BookAnchor? anchor;

  /// How far down the page the reader has come to rest.
  final ValueChanged<BookAnchor>? onScroll;

  @override
  State<BookWebPage> createState() => _BookWebPageState();
}

class _BookWebPageState extends State<BookWebPage> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(patraReaderCanvas)
    ..addJavaScriptChannel(bookBridge, onMessageReceived: _heard)
    ..setNavigationDelegate(
      NavigationDelegate(
        // The page is the one document this view ever shows. A link that
        // survived the rewrite is a fragment of it, and anything else is
        // somewhere a book has no business taking its reader.
        onNavigationRequest: (request) => _isThePage(request.url)
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onPageFinished: (_) => unawaited(_bridge()),
      ),
    );

  /// Where the reader is in the page, as the bridge last told it: what the
  /// page is put back at when it is set again at another size or in another
  /// face.
  BookAnchor? _here;

  /// Which load is the latest: a document written for settings that have
  /// since moved on is not loaded over the one written after it.
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _here = widget.anchor;
    unawaited(_load());
  }

  @override
  void didUpdateWidget(BookWebPage old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html ||
        old.language != widget.language ||
        old.setting != widget.setting ||
        !mapEquals(old.files, widget.files) ||
        old.faceFiles != widget.faceFiles ||
        old.file.path != widget.file.path) {
      unawaited(_load());
    }
  }

  bool _isThePage(String url) {
    final asked = Uri.tryParse(url)?.removeFragment();
    return asked != null &&
        asked.isScheme('file') &&
        asked.toFilePath() == widget.file.path;
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final file = await writeBookDocument(
      widget.file,
      widget.html,
      language: widget.language,
      setting: widget.setting,
      files: widget.files,
      faceFiles: widget.faceFiles,
    );
    if (!mounted || generation != _generation) return;
    await _controller.loadFile(file.path);
  }

  /// The app's own script, run once the page has loaded: it puts the page
  /// where the reader was and tells the reader where they come to rest.
  ///
  /// Run by the host rather than carried by the page, which is why the
  /// page's policy, which runs no script of its own, does not govern it.
  Future<void> _bridge() async {
    try {
      await _controller.runJavaScript(bookBridgeScript(_here));
    } on Object {
      // A page gone before its script ran is a page nobody is reading.
    }
  }

  void _heard(JavaScriptMessage message) {
    final here = bookAnchorHeard(message.message);
    if (here == null) return;
    _here = here;
    widget.onScroll?.call(here);
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(
      controller: _controller,
      // A vertical drag scrolls the page; a horizontal one is the pager's,
      // and a tap is the reader's side zones'. Without claiming it the page
      // would be handed a drag only once every other recogniser had given up
      // on it — at the finger's lift.
      gestureRecognizers: {
        Factory<VerticalDragGestureRecognizer>(
          VerticalDragGestureRecognizer.new,
        ),
      },
    );
  }
}

/// The app's own script for a page opened at [anchor]: it puts the page
/// there, and tells [bookBridge] where the reader comes to rest (#128).
///
/// A place is a block the rewrite named and a fraction down it, so the page
/// is put back on the same words whatever size they are set at today. The
/// block is the innermost one the top of the screen is in — blocks nest, and
/// the last of them in document order to hold that line is the deepest — or,
/// where that line falls between two, the next one down, at its top. A page
/// with no named block at all is told as a share of its height, the form a
/// place took before there were blocks, and a page scrolled to its very top
/// is at its top rather than in its first block. A place written in that old
/// form is put back as a share of the height too: it is what it meant.
///
/// Every one of those is measured against the **visual** viewport — what is
/// on screen — and not the layout viewport a page is laid out in. The two
/// are one where the page is no wider than the screen, which the rewrite's
/// viewport now insists on; measured on a device before it did, a page with
/// a line of code twenty screens wide had a layout viewport four screens
/// tall with the screen at the bottom of it, and a place told from its top
/// was three screens behind the reader. And the screen can move inside the
/// layout viewport without the layout viewport moving, which only the
/// visual viewport's own scroll says.
///
/// The page is put there again once its faces have loaded, since a face is a
/// file of its own and the words move when it arrives — unless the reader has
/// scrolled in the meantime, in which case the page is theirs. A scroll the
/// script makes itself is instant, whatever the book's own `scroll-behavior`
/// says, and is never told back: only the reader's own scrolling is a place
/// they have come to.
@visibleForTesting
String bookBridgeScript(BookAnchor? anchor) {
  final told = anchor == null || anchor.isTop
      ? 'null'
      : jsonEncode(anchor.toJson());
  return '''
(function () {
  var anchor = $told;
  var page = document.scrollingElement || document.documentElement;
  var mark = '$bookBlockMark';
  var moved = false;
  var placedAt = 0;
  var seen = window.visualViewport;
  // Where the screen's top edge is inside the layout viewport, and how tall
  // what is on screen is: the visual viewport, which is what the reader sees.
  function edge() { return seen ? seen.offsetTop : 0; }
  function shown() { return seen ? seen.height : window.innerHeight; }
  function room() { return Math.max(0, page.scrollHeight - shown()); }
  function go(line) {
    var most = Math.max(0, page.scrollHeight - window.innerHeight);
    var to = Math.max(0, Math.min(line - edge(), most));
    if (Math.abs(to - window.scrollY) < 1) return;
    placedAt = Date.now();
    window.scrollTo({ top: to, behavior: 'instant' });
  }
  function place() {
    if (!anchor || moved) return;
    if (anchor.block === undefined) { go(anchor.at * room()); return; }
    var block = document.querySelector('[' + mark + '="' + anchor.block + '"]');
    if (!block) return;
    var box = block.getBoundingClientRect();
    go(window.scrollY + box.top + anchor.at * box.height);
  }
  function here() {
    var line = edge();
    if (window.scrollY + line <= 0) return { at: 0 };
    var blocks = document.querySelectorAll('[' + mark + ']');
    var held = null, heldBox = null, next = null;
    for (var i = 0; i < blocks.length; i++) {
      var box = blocks[i].getBoundingClientRect();
      if (box.height <= 0 || !isFinite(Number(blocks[i].getAttribute(mark)))) continue;
      if (box.top <= line && box.bottom > line) { held = blocks[i]; heldBox = box; }
      else if (box.top > line && next === null) next = blocks[i];
    }
    if (held) {
      return { block: Number(held.getAttribute(mark)), at: (line - heldBox.top) / heldBox.height };
    }
    if (next) return { block: Number(next.getAttribute(mark)), at: 0 };
    var r = room();
    return { at: r > 0 ? (window.scrollY + line) / r : 0 };
  }
  place();
  if (document.fonts) document.fonts.ready.then(place);
  var settling = null;
  function scrolled() {
    // A scroll this script made is not the reader reading: the place it
    // lands on is the place already held, and is not told back.
    if (Date.now() - placedAt < 300) return;
    moved = true;
    clearTimeout(settling);
    settling = setTimeout(function () {
      $bookBridge.postMessage(JSON.stringify(here()));
    }, 150);
  }
  window.addEventListener('scroll', scrolled, { passive: true });
  // The screen can move inside the layout viewport without the layout
  // viewport moving, and then only the visual viewport says so.
  if (seen) seen.addEventListener('scroll', scrolled, { passive: true });
})();''';
}

/// Where the reader has come to rest, as [bookBridgeScript] tells it, or null
/// for a message that is not a place.
@visibleForTesting
BookAnchor? bookAnchorHeard(String message) {
  try {
    return BookAnchor.fromJson(jsonDecode(message));
  } on FormatException {
    return null;
  }
}
