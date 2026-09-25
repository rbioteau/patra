/// One page of a book, drawn by the platform's web engine (ADR-0013, #127).
///
/// What the engine is given has already been made inert and self-contained by
/// the rewrite pass (`book_rewrite.dart`), so nothing here decides what a book
/// may do: this is the host, and nothing more. JavaScript is enabled for the
/// app's own bridge and for nothing else — the page's own scripts are gone
/// before it gets here, and its policy runs none — because the room there is
/// to scroll is wrapped by no API at any layer, and a place in a page is a
/// fraction of it (`BookAnchor`).
///
/// The engine is the platform's, reached through the official plugin: there
/// is none on Linux, and none under a test binding, which is why the reader
/// asks [bookWebEngineProvider] before it draws one and draws the page itself
/// where the answer is no.
library;

import 'dart:async';
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
    final fraction = (_here ?? BookAnchor.top).fraction;
    try {
      await _controller.runJavaScript('''
(function () {
  var page = document.scrollingElement || document.documentElement;
  function room() { return Math.max(0, page.scrollHeight - window.innerHeight); }
  if ($fraction > 0) window.scrollTo(0, $fraction * room());
  var settling = null;
  window.addEventListener('scroll', function () {
    clearTimeout(settling);
    settling = setTimeout(function () {
      var r = room();
      $bookBridge.postMessage(String(r > 0 ? window.scrollY / r : 0));
    }, 150);
  }, { passive: true });
})();''');
    } on Object {
      // A page gone before its script ran is a page nobody is reading.
    }
  }

  void _heard(JavaScriptMessage message) {
    final fraction = double.tryParse(message.message);
    if (fraction == null || !fraction.isFinite) return;
    final here = BookAnchor(fraction.clamp(0.0, 1.0));
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
