import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../api/kavita_client.dart';

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
  });

  final int chapterId;
  final int seriesId;
  final int volumeId;
  final int libraryId;
  final String seriesName;
  final String title;
  final int pages;
  final int bytes;

  /// Mirrored locally so the Downloads tab can show progress with no server.
  final int pagesRead;

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
    );
  }
}

/// Stores reader pages under the app's documents directory.
///
/// `meta.json` is written last, so a chapter directory without one is a
/// partial download and gets cleaned up on the next scan.
class DownloadsService {
  DownloadsService({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;
  Directory? _root;

  Future<Directory> _rootDir() async {
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

  Future<Directory> chapterDir(int chapterId) async =>
      Directory('${(await _rootDir()).path}/$chapterId');

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

  /// Saved chapters, keyed by chapter id. Partial downloads are deleted.
  Future<Map<int, SavedChapter>> scan() async {
    final root = await _rootDir();
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

    var bytes = 0;
    try {
      for (var page = 0; page < chapter.pages; page++) {
        final data = await client.readerImageBytes(
          chapter.chapterId,
          page,
          cancelToken: cancelToken,
        );
        final file = File('${dir.path}/${pageFileName(page)}');
        file.writeAsBytesSync(data);
        bytes += data.length;
        onProgress((page + 1) / chapter.pages);
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
      pages: chapter.pages,
      bytes: bytes,
      pagesRead: chapter.pagesRead,
    );
    File('${dir.path}/meta.json').writeAsStringSync(jsonEncode(saved.toJson()));
    return saved;
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

  Future<void> _deleteQuietly(Directory dir) async {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Nothing useful to do: the next scan will try again.
    }
  }
}
