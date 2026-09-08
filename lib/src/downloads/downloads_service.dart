import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../api/kavita_client.dart';
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
