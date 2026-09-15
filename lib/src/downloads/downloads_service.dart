import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../api/kavita_client.dart';
import '../api/models.dart';
import '../features/reader/book_page.dart';
import '../profile_files.dart';

/// A chapter whose pages are stored on the device.
class SavedChapter {
  const SavedChapter({
    required this.chapterId,
    required this.seriesId,
    required this.volumeId,
    required this.libraryId,
    required this.seriesName,
    required this.title,
    required this.pages,
    required this.bytes,
    this.pagesRead = 0,
    this.format = MangaFormat.unknown,
  });

  final int chapterId;
  final int seriesId;
  final int volumeId;
  final int libraryId;
  final String seriesName;
  final String title;
  final int pages;
  final int bytes;

  /// What the files behind this chapter are, which is what the copy itself is
  /// made of: a stored book is the pages the server rendered, and an offline
  /// reader can only open it as the book it is if the copy says so. See
  /// [MangaFormat.content].
  ///
  /// Unknown for every copy stored before a book could be saved, which reads
  /// as [[ChapterContent.fixedPages]] — the only thing a copy could ever hold
  /// until now.
  final MangaFormat format;

  /// Mirrored locally so the Downloads tab can show progress with no server.
  final int pagesRead;

  /// What the copy is made of, which is what decides how it is read back.
  ChapterContent get content => format.content;

  double get progress => pages == 0 ? 0 : (pagesRead / pages).clamp(0.0, 1.0);
  bool get isRead => pages > 0 && pagesRead >= pages;

  SavedChapter copyWith({int? pagesRead, int? bytes}) => SavedChapter(
    chapterId: chapterId,
    seriesId: seriesId,
    volumeId: volumeId,
    libraryId: libraryId,
    seriesName: seriesName,
    title: title,
    pages: pages,
    bytes: bytes ?? this.bytes,
    pagesRead: pagesRead ?? this.pagesRead,
    format: format,
  );

  /// "Series — Volume 1": what a confirmation dialog needs to say which copy
  /// is about to go. Falls back to whichever half exists.
  String get label =>
      [seriesName, title].where((part) => part.isNotEmpty).join(' — ');

  Map<String, dynamic> toJson() => {
    'chapterId': chapterId,
    'seriesId': seriesId,
    'volumeId': volumeId,
    'libraryId': libraryId,
    'seriesName': seriesName,
    'title': title,
    'pages': pages,
    'bytes': bytes,
    'pagesRead': pagesRead,
    'format': format.id,
  };

  static SavedChapter? fromJson(Object? json) {
    if (json is! Map) return null;
    final chapterId = json['chapterId'];
    final pages = json['pages'];
    if (chapterId is! int || pages is! int) return null;
    return SavedChapter(
      chapterId: chapterId,
      seriesId: json['seriesId'] as int? ?? 0,
      volumeId: json['volumeId'] as int? ?? 0,
      libraryId: json['libraryId'] as int? ?? 0,
      seriesName: json['seriesName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      pages: pages,
      bytes: json['bytes'] as int? ?? 0,
      pagesRead: json['pagesRead'] as int? ?? 0,
      format: MangaFormat.fromId(json['format'] as int?),
    );
  }
}

/// Stores reader pages under the app's documents directory, filed by the
/// profile that saved them.
///
/// `<documents>/downloads/<profile>/<chapterId>/`, and the profile segment is
/// what makes a family tablet work: two people on one server share every
/// chapter id there is, so a store keyed by chapter alone put one person's
/// saved reading in the other's Downloads tab — listed, readable, and writing
/// its progress back over theirs.
///
/// `meta.json` is written last, so a chapter directory without one is a
/// partial download and gets cleaned up on the next scan.
class DownloadsService {
  DownloadsService({Directory? root, required this.profileId})
    : _rootOverride = root;

  /// Whose store this is — [Profile.id], the only thing anything keys a
  /// profile on. Fixed for the life of the service, because the container it
  /// is built in lasts exactly as long as the profile it serves.
  final String profileId;

  final Directory? _rootOverride;
  Directory? _root;

  /// The downloads root, which the **device** owns: every profile's store is
  /// a directory inside it, and so is whatever the flat layout left behind.
  Future<Directory> _downloadsRoot() async {
    final existing = _root ?? _rootOverride;
    if (existing != null) {
      _root = existing;
      return existing;
    }
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory('${documents.path}/downloads');
    _root = root;
    return root;
  }

  /// Where this profile's saved chapters live.
  Future<Directory> profileRoot() async =>
      Directory('${(await _downloadsRoot()).path}/${dirNameFor(profileId)}');

  /// A directory name for [profileId]. See [profileDirName], which the
  /// catalogue files by too.
  static String dirNameFor(String profileId) => profileDirName(profileId);

  Future<Directory> chapterDir(int chapterId) async =>
      Directory('${(await profileRoot()).path}/$chapterId');

  /// Page files are extension-less: Kavita serves jpg, png or webp and the
  /// decoder sniffs the content anyway.
  static String pageFileName(int page) =>
      'page_${page.toString().padLeft(5, '0')}';

  /// The page [pageFileName] wrote, or null for anything else in the directory
  /// — `meta.json`, most of all.
  static int? pageOfFileName(String name) =>
      name.startsWith('page_') ? int.tryParse(name.substring(5)) : null;

  Future<File> pageFile(int chapterId, int page) async =>
      File('${(await chapterDir(chapterId)).path}/${pageFileName(page)}');

  /// Saved chapters, keyed by chapter id. Partial downloads are deleted, and
  /// so is anything the flat layout left in the downloads root.
  Future<Map<int, SavedChapter>> scan() async {
    await _sweepFlatLayout();
    final root = await profileRoot();
    if (!root.existsSync()) return {};
    final result = <int, SavedChapter>{};
    for (final entity in root.listSync()) {
      if (entity is! Directory) continue;
      final meta = File('${entity.path}/meta.json');
      if (!meta.existsSync()) {
        await _deleteQuietly(entity);
        continue;
      }
      try {
        final saved = SavedChapter.fromJson(
          jsonDecode(meta.readAsStringSync()),
        );
        if (saved == null) {
          await _deleteQuietly(entity);
          continue;
        }
        result[saved.chapterId] = saved;
      } on Exception {
        await _deleteQuietly(entity);
      }
    }
    return result;
  }

  /// Downloads every page of [chapter]. [onProgress] receives 0..1.
  ///
  /// What a page is differs by what the chapter is made of, and so does where
  /// the pages come from: a chapter of pictures is one image per page, and a
  /// book is the pages the server laid its words out into (ADR-0008), stored
  /// as it rendered them and made to carry their own pictures (ADR-0009).
  Future<SavedChapter> download({
    required KavitaClient client,
    required SavedChapter chapter,
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await chapterDir(chapter.chapterId);
    // Start clean: a leftover partial download must not be mistaken for a
    // page of this one.
    await _deleteQuietly(dir);
    dir.createSync(recursive: true);

    final int pages;
    var bytes = 0;
    try {
      switch (chapter.content) {
        case ChapterContent.fixedPages:
          pages = chapter.pages;
          for (var page = 0; page < pages; page++) {
            final data = await client.readerImageBytes(
              chapter.chapterId,
              page,
              cancelToken: cancelToken,
            );
            File('${dir.path}/${pageFileName(page)}').writeAsBytesSync(data);
            bytes += data.length;
            onProgress((page + 1) / pages);
          }
        case ChapterContent.reflowable:
          // How long a book is is the server's to say, and `book-info` is the
          // only place it says it: the chapter's own page count is of image
          // pages, and a book has none. The copy keeps the total it was made
          // with, which is what tells a later reader whether the two still
          // agree (#78).
          final book = await client.bookInfo(
            chapter.chapterId,
            cancelToken: cancelToken,
          );
          pages = book.pages;
          // A picture named on several pages is fetched once.
          final carried = <String, String?>{};
          for (var page = 0; page < pages; page++) {
            bytes += await _storeBookPage(
              dir,
              client: client,
              chapterId: chapter.chapterId,
              page: page,
              pages: pages,
              onProgress: onProgress,
              cancelToken: cancelToken,
              carried: carried,
            );
          }
      }
    } on Object {
      await _deleteQuietly(dir);
      rethrow;
    }

    final saved = SavedChapter(
      chapterId: chapter.chapterId,
      seriesId: chapter.seriesId,
      volumeId: chapter.volumeId,
      libraryId: chapter.libraryId,
      seriesName: chapter.seriesName,
      title: chapter.title,
      pages: pages,
      bytes: bytes,
      pagesRead: chapter.pagesRead,
      format: chapter.format,
    );
    File('${dir.path}/meta.json').writeAsStringSync(jsonEncode(saved.toJson()));
    return saved;
  }

  /// Stores one page of a book: the HTML the server laid out, with every
  /// picture it named carried inside it.
  ///
  /// Returns what the page cost, which is what the Downloads tab reports.
  Future<int> _storeBookPage(
    Directory dir, {
    required KavitaClient client,
    required int chapterId,
    required int page,
    required int pages,
    required void Function(double progress) onProgress,
    required Map<String, String?> carried,
    CancelToken? cancelToken,
  }) async {
    final html = await client.bookPage(
      chapterId,
      page,
      cancelToken: cancelToken,
    );
    for (final src in BookPage.fromHtml(html).pictureSources) {
      // Asked for once however many pages name it — including a picture the
      // server refuses, which is why the memo is keyed and not the value.
      if (!carried.containsKey(src)) {
        carried[src] = await _carryPicture(client, chapterId, src, cancelToken);
      }
    }
    final stored = utf8.encode(renameBookPictures(html, (src) => carried[src]));
    File('${dir.path}/${pageFileName(page)}').writeAsBytesSync(stored);
    onProgress((page + 1) / pages);
    return stored.length;
  }

  /// What a page names a picture by once the copy carries the picture itself.
  ///
  /// A picture the server will not hand over is left as the page named it: it
  /// costs the page its picture and not the reader the book, which is a
  /// better answer than a copy that failed over one illustration.
  Future<String?> _carryPicture(
    KavitaClient client,
    int chapterId,
    String src,
    CancelToken? cancelToken,
  ) async {
    try {
      return carriedPictureName(
        await client.bookPictureBytes(chapterId, src, cancelToken: cancelToken),
      );
    } on DioException catch (error) {
      // A cancelled download is not a picture that could not be fetched.
      if (error.type == DioExceptionType.cancel) rethrow;
      return null;
    }
  }

  /// Rewrites `meta.json` in place, for progress recorded while reading.
  Future<void> writeMeta(SavedChapter chapter) async {
    try {
      final dir = await chapterDir(chapter.chapterId);
      if (!dir.existsSync()) return;
      File('${dir.path}/meta.json')
          .writeAsStringSync(jsonEncode(chapter.toJson()));
    } on FileSystemException {
      // Progress is not worth failing a page turn over.
    }
  }

  Future<void> remove(int chapterId) async =>
      _deleteQuietly(await chapterDir(chapterId));

  /// How much saved reading this profile holds, for the confirmation that
  /// stands in front of removing it: what is about to go has to be said
  /// before it goes, since nothing can reach these files afterwards.
  ///
  /// Added up from each `meta.json` rather than by measuring every page file,
  /// which is one read per chapter instead of one per page — and is the same
  /// number the Downloads tab totals, so the two cannot disagree. Unlike
  /// [scan] it deletes nothing: this is asked of a profile nobody is reading
  /// as, and a partial download of theirs is not ours to sweep.
  Future<({int chapters, int bytes})> savedTotals() async {
    final root = await profileRoot();
    if (!root.existsSync()) return (chapters: 0, bytes: 0);
    var chapters = 0;
    var bytes = 0;
    for (final entity in root.listSync()) {
      if (entity is! Directory) continue;
      final meta = File('${entity.path}/meta.json');
      if (!meta.existsSync()) continue;
      try {
        final saved = SavedChapter.fromJson(
          jsonDecode(meta.readAsStringSync()),
        );
        if (saved == null) continue;
        chapters++;
        bytes += saved.bytes;
      } on Exception {
        continue;
      }
    }
    return (chapters: chapters, bytes: bytes);
  }

  /// Deletes everything this profile saved. Called when the profile is
  /// removed from the device: nothing could reach these files again, so
  /// leaving them would be disk no screen could ever explain.
  Future<void> removeAll() async => _deleteQuietly(await profileRoot());

  /// Deletes the chapter directories the previous, profile-less layout wrote
  /// straight into the downloads root.
  ///
  /// There is no migration — a saved chapter cannot be attributed to an
  /// account after the fact (#8) — so this is the same sweep that already
  /// removes a download it considers incomplete, reaching one level up. A
  /// chapter directory is named for a chapter id and so is all digits, which
  /// no encoded profile id ever is.
  Future<void> _sweepFlatLayout() async {
    final root = await _downloadsRoot();
    if (!root.existsSync()) return;
    for (final entity in root.listSync()) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (int.tryParse(name) == null) continue;
      await _deleteQuietly(entity);
    }
  }

  Future<void> _deleteQuietly(Directory dir) async {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Nothing useful to do: the next scan will try again.
    }
  }
}
