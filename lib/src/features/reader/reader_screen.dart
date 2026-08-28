import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/models.dart';
import '../../auth/session.dart';

final chapterInfoProvider = FutureProvider.autoDispose
    .family<ChapterInfoDto, int>((ref, chapterId) {
      return ref.watch(kavitaClientProvider).chapterInfo(chapterId);
    });

/// Reader v0 : pagination horizontale simple avec zoom, pré-chargement de la
/// page suivante et sauvegarde de progression. Le mode webtoon (scroll
/// vertical continu) et le sens de lecture manga viendront ensuite.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.chapterId,
    this.initialPage = 0,
  });

  final int chapterId;
  final int initialPage;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late final PageController _pageController;
  bool _showBars = false;
  int _currentPage = 0;
  bool _initialProgressSaved = false;

  /// Serializes progress posts so a slow request for an earlier page can't
  /// overwrite a later one, and swallows failures (a lost save is resent on
  /// the next page turn).
  Future<void> _progressQueue = Future.value();

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _saveProgress(int page, ChapterInfoDto info) {
    // Kavita counts pagesRead from the saved pageNum, so reaching the last
    // page must report the total for the chapter to be marked read — the
    // official web reader does the same.
    final pageNum = page >= info.pages - 1 ? info.pages : page;
    final client = ref.read(kavitaClientProvider);
    _progressQueue = _progressQueue
        .then(
          (_) => client.saveProgress(
            libraryId: info.libraryId,
            seriesId: info.seriesId,
            volumeId: info.volumeId,
            chapterId: widget.chapterId,
            pageNum: pageNum,
          ),
        )
        .catchError((Object _) {});
  }

  void _onPageChanged(int page, ChapterInfoDto info) {
    setState(() => _currentPage = page);
    _saveProgress(page, info);
    // Pré-charge la page suivante pendant que l'utilisateur lit.
    if (page + 1 < info.pages) {
      final client = ref.read(kavitaClientProvider);
      precacheImage(
        CachedNetworkImageProvider(
          client.readerImageUrl(widget.chapterId, page + 1),
          headers: client.imageHeaders,
        ),
        context,
      );
    }
  }

  /// onPageChanged never fires for the initial page; without this a 1-page
  /// chapter would record no progress at all.
  void _saveInitialProgress(ChapterInfoDto info) {
    if (_initialProgressSaved) return;
    _initialProgressSaved = true;
    _saveProgress(_currentPage, info);
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(kavitaClientProvider);
    final info = ref.watch(chapterInfoProvider(widget.chapterId));
    return Scaffold(
      backgroundColor: Colors.black,
      body: info.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: Colors.white)),
        ),
        data: (chapter) {
          _saveInitialProgress(chapter);
          return Stack(
            children: [
              GestureDetector(
                onTap: () => setState(() => _showBars = !_showBars),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: chapter.pages,
                  onPageChanged: (page) => _onPageChanged(page, chapter),
                  itemBuilder: (context, page) => InteractiveViewer(
                    maxScale: 5,
                    child: CachedNetworkImage(
                      imageUrl: client.readerImageUrl(widget.chapterId, page),
                      httpHeaders: client.imageHeaders,
                      fit: BoxFit.contain,
                      placeholder: (_, _) =>
                          const Center(child: CircularProgressIndicator()),
                      errorWidget: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              ),
              if (_showBars) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AppBar(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                    title: Text(
                      chapter.title.isNotEmpty
                          ? chapter.title
                          : chapter.seriesName,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      AppLocalizations.of(context)
                          .pageProgress(_currentPage + 1, chapter.pages),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
