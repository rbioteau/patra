import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../api/kavita_client.dart';
import '../api/models.dart';
import '../features/reader/book_page.dart';
import '../profile_files.dart';

/// Progress the device has recorded and the server has not been told: the
/// page the reader is on, and — for a book — the place within it.
///
/// A saved copy is the only place progress made with no server can wait: it
/// is what the reader mirrors its place into as it reads, and the one thing
/// on the device that outlives the app being closed on a train. So what is
/// posted travels through the copy — written down before the post is
/// attempted, cleared once the server has taken it — and the anchor comes
/// along with the number, because a book's page is longer than the screen
/// and a page number on its own opens it again at words already read.
class PendingProgress {
  const PendingProgress({required this.pageNum, this.bookScrollId});

  final int pageNum;

  /// Where in the page the reader is, as the progress call has always carried
  /// it. Null for a chapter of pictures, which has no place within a page to
  /// be in.
  final String? bookScrollId;

  Map<String, dynamic> toJson() => {
    'pageNum': pageNum,
    'bookScrollId': bookScrollId,
  };

  static PendingProgress? fromJson(Object? json) {
    if (json is! Map) return null;
    final pageNum = json['pageNum'];
    if (pageNum is! int) return null;
    return PendingProgress(
      pageNum: pageNum,
      bookScrollId: json['bookScrollId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PendingProgress &&
      other.pageNum == pageNum &&
      other.bookScrollId == bookScrollId;

  @override
  int get hashCode => Object.hash(pageNum, bookScrollId);

  @override
  String toString() => 'PendingProgress($pageNum, $bookScrollId)';
}

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
    this.pending,
    this.serverPages,
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

  /// What the server has not been told: the page the reader is on — and, for
  /// a book, the place within it — recorded while the server could not be
  /// reached. Null where the two are in step.
  final PendingProgress? pending;

  /// What the server last said this chapter is made of, where that is not
  /// what the copy holds. Null where the two agree.
  ///
  /// A copy keeps the pagination it was made with (ADR-0009), which is the
  /// whole reason the two can disagree: the server can recount a book, and
  /// nothing asks it not to. Kept rather than acted on — the copy is named as
  /// out of date and offered for a refresh, and is read either way — and it
  /// is the number a refresh refetches, so a copy is never made twice with
  /// the count that left it out of step.
  final int? serverPages;

  /// What the copy is made of, which is what decides how it is read back.
  ChapterContent get content => format.content;

  double get progress => pages == 0 ? 0 : (pagesRead / pages).clamp(0.0, 1.0);
  bool get isRead => pages > 0 && pagesRead >= pages;

  /// Whether the copy is out of step with the server: it was made with a
  /// count of pages the server no longer gives.
  bool get outOfDate => serverPages != null;

  SavedChapter copyWith({
    int? pages,
    int? pagesRead,
    int? bytes,
    PendingProgress? pending,
    bool clearPending = false,
    int? serverPages,
    bool clearServerPages = false,
  }) => SavedChapter(
    chapterId: chapterId,
    seriesId: seriesId,
    volumeId: volumeId,
    libraryId: libraryId,
    seriesName: seriesName,
    title: title,
    pages: pages ?? this.pages,
    bytes: bytes ?? this.bytes,
    pagesRead: pagesRead ?? this.pagesRead,
    format: format,
    // Two fields that are *cleared* rather than set, which is why they do
    // not follow the keep-what-is-there rule: what the server has taken, and
    // what it has come back into step about, are off the copy rather than
    // overwritten with another value.
    pending: clearPending ? null : pending ?? this.pending,
    serverPages: clearServerPages ? null : serverPages ?? this.serverPages,
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
    'pending': pending?.toJson(),
    'serverPages': serverPages,
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
      pending: PendingProgress.fromJson(json['pending']),
      serverPages: json['serverPages'] as int?,
    );
  }
}

enum DownloadQueueStatus { queued, downloading, interrupted, failed, saved }

/// One chapter's durable download state. The request is enough to retry it;
/// [saved] is the finished copy, where one exists independently of the current
/// attempt (a refresh can fail without spending the copy it was replacing).
class DownloadQueueRecord {
  const DownloadQueueRecord({
    required this.request,
    required this.status,
    required this.priority,
    this.completedPages = 0,
    this.totalPages = 0,
    this.saved,
  });

  factory DownloadQueueRecord.completed(
    SavedChapter saved, {
    required int priority,
  }) => DownloadQueueRecord(
    request: saved,
    saved: saved,
    status: DownloadQueueStatus.saved,
    priority: priority,
    completedPages: saved.pages,
    totalPages: saved.pages,
  );

  final SavedChapter request;
  final DownloadQueueStatus status;
  final int priority;
  final int completedPages;
  final int totalPages;
  final SavedChapter? saved;

  double get progress =>
      totalPages == 0 ? 0 : (completedPages / totalPages).clamp(0.0, 1.0);

  bool get isInFlight =>
      status == DownloadQueueStatus.queued ||
      status == DownloadQueueStatus.downloading;

  DownloadQueueRecord copyWith({
    SavedChapter? request,
    DownloadQueueStatus? status,
    int? priority,
    int? completedPages,
    int? totalPages,
    SavedChapter? saved,
    bool clearSaved = false,
  }) => DownloadQueueRecord(
    request: request ?? this.request,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    completedPages: completedPages ?? this.completedPages,
    totalPages: totalPages ?? this.totalPages,
    saved: clearSaved ? null : saved ?? this.saved,
  );

  Map<String, dynamic> toJson() => {
    'request': request.toJson(),
    'status': status.name,
    'priority': priority,
    'completedPages': completedPages,
    'totalPages': totalPages,
    'saved': saved?.toJson(),
  };

  static DownloadQueueRecord? fromJson(Object? json) {
    if (json is! Map) return null;
    final request = SavedChapter.fromJson(json['request']);
    final statusName = json['status'];
    final priority = json['priority'];
    if (request == null || statusName is! String || priority is! int) {
      return null;
    }
    final status = DownloadQueueStatus.values
        .where((one) => one.name == statusName)
        .firstOrNull;
    if (status == null) return null;
    return DownloadQueueRecord(
      request: request,
      status: status,
      priority: priority,
      completedPages: json['completedPages'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      saved: SavedChapter.fromJson(json['saved']),
    );
  }
}

typedef DownloadProgressCallback = FutureOr<void> Function(
  int completedPages,
  int totalPages,
);

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

  Future<void> _queueWrites = Future<void>.value();

  static const _queueVersion = 1;
  static const _queueFileName = 'queue.json';

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

  /// Reads this profile's queue and reconciles it with finished copies made
  /// before the queue existed. A process can disappear without running
  /// disposal, so anything left queued or downloading becomes interrupted on
  /// the next read and waits for an explicit retry.
  Future<Map<int, DownloadQueueRecord>> loadQueue() async {
    await _queueWrites;
    final copies = await scan();
    final records = await _readQueue();
    var changed = false;
    var nextPriority = records.values.fold<int>(
      0,
      (next, record) => record.priority >= next ? record.priority + 1 : next,
    );

    for (final entry in records.entries.toList()) {
      var record = entry.value;
      final hadSavedCopy = record.saved != null;
      if (record.isInFlight) {
        record = record.copyWith(status: DownloadQueueStatus.interrupted);
        changed = true;
      }
      final copy = copies.remove(entry.key);
      if (copy != null) {
        record = hadSavedCopy
            ? record.copyWith(
                saved: copy,
                request: record.status == DownloadQueueStatus.saved
                    ? copy
                    : record.request,
              )
            : DownloadQueueRecord.completed(copy, priority: record.priority);
        changed = true;
      } else if (record.saved != null) {
        record = record.copyWith(
          status: DownloadQueueStatus.interrupted,
          clearSaved: true,
        );
        changed = true;
      }
      records[entry.key] = record;
    }

    // Existing saved copies are not abandoned by the cutover. They become
    // completed queue records the first time their profile is opened.
    for (final copy in copies.values) {
      records[copy.chapterId] = DownloadQueueRecord.completed(
        copy,
        priority: nextPriority++,
      );
      changed = true;
    }
    if (changed) await writeQueue(records);
    return records;
  }

  /// Atomically replaces this profile's queue. Writes are serialized so two
  /// taps that arrive together cannot let the older snapshot land last.
  Future<void> writeQueue(Map<int, DownloadQueueRecord> records) {
    final snapshot = Map<int, DownloadQueueRecord>.of(records);
    final write = _queueWrites.then((_) => _writeQueue(snapshot));
    _queueWrites = write.then<void>((_) {}, onError: (_, _) {});
    return write;
  }

  Future<Map<int, DownloadQueueRecord>> _readQueue() async {
    try {
      final file = File('${(await profileRoot()).path}/$_queueFileName');
      if (!file.existsSync()) return {};
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map || json['version'] != _queueVersion) return {};
      final records = <int, DownloadQueueRecord>{};
      for (final value in json['records'] as List<dynamic>? ?? const []) {
        final record = DownloadQueueRecord.fromJson(value);
        if (record != null) records[record.request.chapterId] = record;
      }
      return records;
    } on Object {
      return {};
    }
  }

  Future<void> _writeQueue(Map<int, DownloadQueueRecord> records) async {
    final root = await profileRoot();
    root.createSync(recursive: true);
    final file = File('${root.path}/$_queueFileName');
    final temp = File('${file.path}.tmp');
    temp.writeAsStringSync(
      jsonEncode({
        'version': _queueVersion,
        'records': [for (final record in records.values) record.toJson()],
      }),
    );
    temp.renameSync(file.path);
  }

  /// Where pages are written before they are a copy, inside the chapter's own
  /// directory: `scan` only reads the profile root, so a download in progress
  /// is invisible to it — and a failed one costs the copy nothing.
  static const stagingDirName = 'staging';

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
  ///
  /// The pages land **beside the copy they are replacing and are moved into
  /// place once every one of them is on disk**, so a download that fails — or
  /// that is cancelled, which leaving the screen does — costs nothing the
  /// reader chose to keep. That is the whole difference between storing a
  /// chapter and storing it *again*: a fresh one leaves a directory with no
  /// `meta.json`, which the next `scan` sweeps, while a copy already there is
  /// still exactly the copy it was.
  Future<SavedChapter> download({
    required KavitaClient client,
    required SavedChapter chapter,
    required DownloadProgressCallback onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await chapterDir(chapter.chapterId);
    dir.createSync(recursive: true);
    final staging = Directory('${dir.path}/$stagingDirName');
    // Start clean: a leftover partial download must not be mistaken for a
    // page of this one.
    await _deleteQuietly(staging);
    staging.createSync(recursive: true);

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
            File('${staging.path}/${pageFileName(page)}')
                .writeAsBytesSync(data);
            bytes += data.length;
            await onProgress(page + 1, pages);
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
              staging,
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
      await _deleteQuietly(staging);
      // Storing a chapter *again* is the only way this finds a copy already
      // there, and that copy is the reader's to keep: only a directory with
      // no `meta.json` — one that never finished, and so was never a copy at
      // all — is ours to take away.
      final meta = File('${dir.path}/meta.json');
      if (!meta.existsSync()) await _deleteQuietly(dir);
      rethrow;
    }

    await _promote(dir, staging, pages);
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
      // What the server has not been told survives being stored again: the
      // copy is the outbox, and a refresh that emptied it would throw away a
      // page — and a place within it — that were never posted.
      pending: chapter.pending,
      format: chapter.format,
    );
    File('${dir.path}/meta.json').writeAsStringSync(jsonEncode(saved.toJson()));
    return saved;
  }

  /// Puts [staging]'s pages in [dir]'s place, and drops what the copy used to
  /// hold that is no longer a page of it.
  ///
  /// The leftovers are the whole reason this is a swap rather than a copy over
  /// the top: a server that has recounted a book leaves pages behind that are
  /// not pages of it any more, and a reader that found them would call the
  /// copy longer than it is.
  Future<void> _promote(Directory dir, Directory staging, int pages) async {
    for (var page = 0; page < pages; page++) {
      File('${staging.path}/${pageFileName(page)}')
          .renameSync('${dir.path}/${pageFileName(page)}');
    }
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      final page = pageOfFileName(name);
      if (page == null || page >= pages) entity.deleteSync();
    }
    await _deleteQuietly(staging);
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
    required DownloadProgressCallback onProgress,
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
    await onProgress(page + 1, pages);
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
