/// **A development tool, not what ships** (#131): one page of a book drawn by
/// the app itself, in Flutter, out of the blocks the parser takes it apart
/// into.
///
/// What a reader sees on Android and iOS is the platform's web engine
/// (`book_web_page.dart`, ADR-0013). This renderer is kept for one reason: it
/// is the only way to look at a page of a book without a phone, the web view
/// plugin having no implementation on Linux. It honours the book's face and
/// no other rule of its CSS (ADR-0010, ADR-0012), sets prose ragged right —
/// Flutter draws no hyphen at a break — has no blocks to name, and writes a
/// place as a bare fraction of the page. **It is allowed to drift**: nothing
/// about it is a claim about what a reader sees, and a fix made here is not a
/// fix to the book reader.
///
/// The reader reaches it only where there is no engine **and** the build is
/// not a release (`kReleaseMode` is a constant, so a release compiles the
/// branch and this file away), and nothing else in `lib/` imports it —
/// pinned by `test/development_book_page_test.dart`, which is also where
/// every test of what it draws lives, named as describing it.
///
/// The parser is not here and is not optional: `BookPage` and
/// `BookPage.pictureSources` stay in `book_page.dart`, because the downloader
/// and the web engine both read them.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/kavita_client.dart';
import '../../../auth/session.dart';
import '../../../downloads/downloads_provider.dart';
import '../../../settings/reading_settings.dart';
import '../../../theme.dart';
import '../book_markup.dart';
import '../book_page.dart';

extension on BookSpan {
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

/// One page of a book, read top to bottom and set at the size whoever is
/// reading chose.
class DevelopmentBookPage extends StatefulWidget {
  const DevelopmentBookPage({
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
  State<DevelopmentBookPage> createState() => _DevelopmentBookPageState();
}

class _DevelopmentBookPageState extends State<DevelopmentBookPage> {
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
  void didUpdateWidget(DevelopmentBookPage old) {
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
    // that opens at its top has nowhere to be put. Nor has a place in a
    // block: this renderer draws no block the rewrite named, and is kept for
    // development alone (#128), so a place the engine wrote opens at the top.
    if (anchor == null || anchor.isTop || anchor.block != null) {
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
      // In this renderer a page is set **ragged right**, and deliberately:
      // Flutter honours a soft hyphen as a break but does not draw the hyphen
      // at the break, so justification here has no hyphenation to open a
      // narrow column with and opens gaps instead — which reads as a
      // rendering fault rather than as typography. The web engine, which
      // draws the hyphen, justifies where the book is silent (#130); this one
      // still cannot. See the reader's rules; the measurement is recorded
      // there so this is not "fixed" back.
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
      // The rule down the side of a quotation, and the room it leaves, are
      // **directional**: in a book that reads from the right they belong on
      // the right, like the bullet of a list item the `Row` above already
      // mirrors.
      BookBlockStyle.quotation => Container(
        decoration: const BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: patraBorder, width: 2),
          ),
        ),
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: words,
      ),
      _ => words,
    };
  }
}

/// A picture a page of a book refers to, as the development renderer draws
/// it: what the reader hands [DevelopmentBookPage.picture].
///
/// A page names its pictures the way the file does — a path inside the book —
/// and the server is what turns that name into bytes. Where the page carries
/// a whole address instead, Kavita wrote it (`//host/api/book/…
/// ?apiKey=…&file=cover.jpg`) out of its own idea of where it lives, so only
/// the file in it is kept and the request is made on the address this session
/// was built with (`KavitaClient.bookPictureUrl`). A saved copy keeps its
/// pictures beside its pages (#129), and a copy written before that carries
/// them inside the page (`carriedPictureBytes`); either is drawn with no
/// server. A page whose only block is a picture that cannot be had is drawn
/// as nothing at all.
class DevelopmentBookPicture extends ConsumerStatefulWidget {
  const DevelopmentBookPicture({
    super.key,
    required this.chapterId,
    required this.src,
  });

  final int chapterId;

  /// The picture's name, as the page gave it.
  final String src;

  @override
  ConsumerState<DevelopmentBookPicture> createState() =>
      _DevelopmentBookPictureState();
}

class _DevelopmentBookPictureState
    extends ConsumerState<DevelopmentBookPicture> {
  /// The bytes the name carries, decoded once and kept, because
  /// `Image.memory` is its own cache key: a new list on every build is a new
  /// picture for the decoder, and reading a saved book rebuilds its page
  /// often.
  late final Uint8List? _carried = carriedPictureBytes(widget.src);

  /// The file beside a saved copy's pages the picture is kept in, looked for
  /// once per copy directory.
  (Directory, File?)? _copied;

  File? _copy(Directory dir) {
    if (_copied case (final from, final file) when from.path == dir.path) {
      return file;
    }
    final file = bookPictureFile(dir, widget.src);
    return (_copied = (dir, file.existsSync() ? file : null)).$2;
  }

  @override
  Widget build(BuildContext context) {
    // Watched in a build a lazy pager runs during layout, as the page around
    // it already watches its own: this renderer is a development tool, and
    // the rule the reader keeps for its layout path is kept by what ships.
    final saved = ref.watch(
      savedChapterProvider(widget.chapterId).select((copy) => copy != null),
    );
    final dir = saved
        ? ref.watch(chapterDirProvider(widget.chapterId)).value
        : null;
    // The width of the column of words it sits in, and its own height from
    // that: a picture in a page of a book is as wide as the page's text.
    final copied = dir == null ? null : _copy(dir);
    if (copied != null) {
      return Image.file(copied, width: double.infinity, fit: BoxFit.fitWidth);
    }
    final carried = _carried;
    if (carried != null) {
      return Image.memory(
        carried,
        width: double.infinity,
        fit: BoxFit.fitWidth,
      );
    }
    final KavitaClient client;
    try {
      client = ref.read(kavitaClientProvider);
    } on StateError {
      // Signed out, where there is nothing to fetch anything with.
      return const SizedBox.shrink();
    }
    final url = client.bookPictureUrl(widget.chapterId, widget.src);
    return Image(
      image: CachedNetworkImageProvider(
        url,
        // Without a key of its own the URL files this picture under the
        // profile that fetched it (`imageCacheKey`).
        cacheKey: imageCacheKey(url),
        headers: client.imageHeaders,
      ),
      width: double.infinity,
      fit: BoxFit.fitWidth,
    );
  }
}
