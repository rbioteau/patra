import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../api/kavita_client.dart';
import '../api/models.dart';
import '../features/reader/book_face.dart';
import '../features/reader/book_markup.dart';
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
    this.place,
    this.serverPages,
    this.language,
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

  /// The language the book was written in when the copy was made — see
  /// [Chapter.language] — or null where the server gave none.
  ///
  /// A copy keeps the pagination it was made with (ADR-0009), and it keeps
  /// this with it for the same reason: with no server to ask, the copy is
  /// the only thing that can say, and a book read on a train would otherwise
  /// be hyphenated in nothing (ADR-0013). Null too for every copy made before
  /// it was recorded, which opens exactly as it always did.
  final String? language;

  /// Mirrored locally so the Downloads tab can show progress with no server.
  final int pagesRead;

  /// What the server has not been told: the page the reader is on — and, for
  /// a book, the place within it — recorded while the server could not be
  /// reached. Null where the two are in step.
  final PendingProgress? pending;

  /// Where the reader last was in this copy — the page, and for a book the
  /// place within it — whether or not the server has been told (#128).
  ///
  /// [pending] is cleared the moment the server takes it, which is right for
  /// what is left to send and wrong for where to open: a book read online and
  /// then opened on a train has no server to ask, and a copy that forgot its
  /// place with the post would open it at words already read. So the copy
  /// keeps its own record, written with every [pending] and never cleared,
  /// and that is what a book opened with no server opens at — the same place
  /// a streamed page would be opened at by the server. Null for a copy nobody
  /// has read yet, and for every copy made before it was recorded.
  final PendingProgress? place;

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

  /// Whether [title] is a copy named after Kavita's bookkeeping rather than
  /// after the work: the sentinel a placeholder chapter carries, which is a
  /// number to nobody. Copies made before the label was fixed were stored
  /// with it, so a copy read back off the disk is asked rather than trusted —
  /// what is drawn then falls back to the series, which is what every row
  /// leads with and what a reader recognises a copy by.
  static bool isSentinelTitle(String title) =>
      num.tryParse(title)?.abs() == Chapter.defaultNumber.abs();

  /// What this copy is called, with Kavita's bookkeeping taken out: a title
  /// that is only the sentinel number names nothing, so it is left empty and
  /// the row leads with the series instead.
  String get resolvedTitle => isSentinelTitle(title) ? '' : title;

  /// Whether the copy is out of step with the server: it was made with a
  /// count of pages the server no longer gives.
  bool get outOfDate => serverPages != null;

  SavedChapter copyWith({
    int? pages,
    int? pagesRead,
    int? bytes,
    PendingProgress? pending,
    bool clearPending = false,
    PendingProgress? place,
    bool clearPlace = false,
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
    language: language,
    // Three fields that are *cleared* rather than set, which is why they do
    // not follow the keep-what-is-there rule: what the server has taken, and
    // what it has come back into step about, are off the copy rather than
    // overwritten with another value.
    pending: clearPending ? null : pending ?? this.pending,
    place: clearPlace ? null : place ?? this.place,
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
    'language': ?language,
    'pending': pending?.toJson(),
    'place': ?place?.toJson(),
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
      language: Chapter.languageFrom(json['language'] as String?),
      pending: PendingProgress.fromJson(json['pending']),
      place: PendingProgress.fromJson(json['place']),
      serverPages: json['serverPages'] as int?,
    );
  }
}

enum DownloadQueueStatus {
  queued,
  downloading,
  paused,
  pausedByUser,
  interrupted,
  failed,
  saved,
}

/// One chapter's durable download state. The request is enough to retry it;
/// [saved] is the finished copy, where one exists independently of the current
/// attempt (a refresh can fail without spending the copy it was replacing).
///
/// **Three ways to stop are deliberately three states**, though all of them
/// keep every page they have and all are resumed from the last one written.
/// What separates them is who stopped the copy, because that is what decides
/// who starts it again:
///
/// - [DownloadQueueStatus.paused] is the app's own doing — it left the
///   foreground, or the reader left their profile — and it goes on **without
///   being asked**.
/// - [DownloadQueueStatus.pausedByUser] is the reader's word. Nothing resumes
///   it but a tap: an app that came back to the foreground must not undo a
///   pause somebody made on purpose.
/// - [DownloadQueueStatus.interrupted] is a process that stopped without
///   saying so, and it waits for the reader's word too, because the app that
///   comes up next cannot know what was happening when the last one died.
///
/// The two pauses are written down as one word to the reader ("Paused", with
/// the same blue and the same play glyph) and as two values here, because the
/// word is the same fact and the resumption is not.
class DownloadQueueRecord {
  const DownloadQueueRecord({
    required this.request,
    required this.status,
    required this.priority,
    this.completedPages = 0,
    this.totalPages = 0,
    this.saved,
    this.batchId,
  });

  factory DownloadQueueRecord.completed(
    SavedChapter saved, {
    required int priority,
    int? batchId,
  }) => DownloadQueueRecord(
    request: saved,
    saved: saved,
    status: DownloadQueueStatus.saved,
    priority: priority,
    completedPages: saved.pages,
    totalPages: saved.pages,
    batchId: batchId,
  );

  final SavedChapter request;
  final DownloadQueueStatus status;
  final int priority;
  final int completedPages;
  final int totalPages;
  final SavedChapter? saved;

  /// The batch action this record belongs to, if it was enqueued as a batch.
  /// Kept on completed records so the Downloads tab can report how much of
  /// that request is done while its remaining chapters are still running.
  final int? batchId;

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
    int? batchId,
    bool clearSaved = false,
  }) => DownloadQueueRecord(
    request: request ?? this.request,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    completedPages: completedPages ?? this.completedPages,
    totalPages: totalPages ?? this.totalPages,
    saved: clearSaved ? null : saved ?? this.saved,
    batchId: batchId ?? this.batchId,
  );

  Map<String, dynamic> toJson() => {
    'request': request.toJson(),
    'status': status.name,
    'priority': priority,
    'completedPages': completedPages,
    'totalPages': totalPages,
    'saved': saved?.toJson(),
    'batchId': batchId,
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
      batchId: json['batchId'] as int?,
    );
  }
}

typedef DownloadProgressCallback = FutureOr<void> Function(
  int completedPages,
  int totalPages,
);

/// Page requests one chapter may keep in flight. Bounded separately from the
/// chapter queue so one long chapter cannot flood a Kavita server.
const maxConcurrentPageDownloads = 4;

typedef _QueueSnapshot = ({
  Map<int, DownloadQueueRecord> records,
  bool authoritative,
});

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

  Future<void>? _queueWrites;
  var _protectAllPartials = false;

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
  /// before the queue existed. Queue state is read before the filesystem is
  /// swept: queued, downloading, interrupted and failed records all keep their
  /// partial bytes alive. A process can disappear without running disposal,
  /// so anything left queued or downloading becomes interrupted and waits for
  /// an explicit retry.
  Future<Map<int, DownloadQueueRecord>> loadQueue() async {
    if (_queueWrites case final pending?) await pending;
    final queue = await _readQueue();
    final records = queue.records;
    final livePartials = _livePartialChapterIds(queue);
    final copies = await _scan(livePartials);
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
    // An unreadable queue cannot prove a partial is garbage. Do not replace
    // that evidence with a new queue that would delete it on the next scan.
    if (changed && queue.authoritative) await writeQueue(records);
    return records;
  }

  static Set<int>? _livePartialChapterIds(_QueueSnapshot queue) =>
      queue.authoritative
      ? {
          for (final record in queue.records.values)
            if (record.status != DownloadQueueStatus.saved)
              record.request.chapterId,
        }
      : null;

  /// Atomically replaces this profile's queue. Writes are serialized so two
  /// taps that arrive together cannot let the older snapshot land last.
  Future<void> writeQueue(Map<int, DownloadQueueRecord> records) =>
      _scheduleQueueWrite(records, _writeQueue);

  /// The same atomic queue replacement, using non-blocking filesystem calls.
  /// Page completions use this path so their durability does not stall UI.
  Future<void> writeQueueAsynchronously(
    Map<int, DownloadQueueRecord> records,
  ) => _scheduleQueueWrite(records, _writeQueueAsynchronously);

  Future<void> _scheduleQueueWrite(
    Map<int, DownloadQueueRecord> records,
    Future<void> Function(Map<int, DownloadQueueRecord>) writer,
  ) {
    final snapshot = Map<int, DownloadQueueRecord>.of(records);
    final previous = _queueWrites;
    final write = previous == null
        ? writer(snapshot)
        : previous.then((_) => writer(snapshot));
    _queueWrites = write.then<void>((_) {}, onError: (_, _) {});
    return write;
  }

  Future<_QueueSnapshot> _readQueue() async {
    try {
      final file = File('${(await profileRoot()).path}/$_queueFileName');
      if (!file.existsSync()) {
        _protectAllPartials = false;
        return (records: <int, DownloadQueueRecord>{}, authoritative: true);
      }
      final json = jsonDecode(file.readAsStringSync());
      if (json is! Map || json['version'] != _queueVersion) {
        return _ambiguousQueue();
      }
      final values = json['records'];
      final protection = json['protectPartials'];
      if (values is! List || (protection != null && protection is! bool)) {
        return _ambiguousQueue();
      }
      final records = <int, DownloadQueueRecord>{};
      var authoritative = protection != true;
      for (final value in values) {
        final record = DownloadQueueRecord.fromJson(value);
        if (record == null) {
          authoritative = false;
        } else {
          records[record.request.chapterId] = record;
        }
      }
      _protectAllPartials = !authoritative;
      return (records: records, authoritative: authoritative);
    } on Object {
      return _ambiguousQueue();
    }
  }

  _QueueSnapshot _ambiguousQueue() {
    _protectAllPartials = true;
    return (records: <int, DownloadQueueRecord>{}, authoritative: false);
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
        if (_protectAllPartials) 'protectPartials': true,
      }),
    );
    temp.renameSync(file.path);
  }

  Future<void> _writeQueueAsynchronously(
    Map<int, DownloadQueueRecord> records,
  ) async {
    final root = await profileRoot();
    await root.create(recursive: true);
    final file = File('${root.path}/$_queueFileName');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      jsonEncode({
        'version': _queueVersion,
        'records': [for (final record in records.values) record.toJson()],
        if (_protectAllPartials) 'protectPartials': true,
      }),
    );
    await temp.rename(file.path);
  }

  /// Where pages are written before they are a copy, inside the chapter's own
  /// directory. [scan] sees the directory, but the queue decides whether the
  /// partial is alive; a failed refresh leaves its finished copy untouched.
  static const stagingDirName = 'staging';

  Future<File> pageFile(int chapterId, int page) async =>
      File('${(await chapterDir(chapterId)).path}/${pageFileName(page)}');

  /// Saved chapters, keyed by chapter id. A partial is garbage only when a
  /// readable queue has no live entry for it. If the queue cannot be read,
  /// ambiguity resolves toward keeping the bytes.
  Future<Map<int, SavedChapter>> scan() async {
    if (_queueWrites case final pending?) await pending;
    final queue = await _readQueue();
    final livePartials = _livePartialChapterIds(queue);
    return _scan(livePartials);
  }

  Future<Map<int, SavedChapter>> _scan(Set<int>? livePartials) async {
    await _sweepFlatLayout();
    final root = await profileRoot();
    if (!root.existsSync()) return {};
    final result = <int, SavedChapter>{};
    for (final entity in root.listSync()) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      final chapterId = int.tryParse(name);
      final saved = _readSavedChapter(entity);
      if (saved != null) {
        if (livePartials != null && !livePartials.contains(saved.chapterId)) {
          await _deleteQuietly(Directory('${entity.path}/$stagingDirName'));
        }
        result[saved.chapterId] = saved;
        continue;
      }
      if (livePartials == null ||
          (chapterId != null && livePartials.contains(chapterId))) {
        continue;
      }
      await _deleteQuietly(entity);
    }
    return result;
  }

  /// Downloads every page of [chapter]. [onProgress] receives completed and
  /// total pages; a book reports zero first so its pagination is durable
  /// before its first rendered page is written.
  ///
  /// What a page is differs by what the chapter is made of, and so does where
  /// the pages come from: a chapter of pictures is one image per page, and a
  /// book is the pages the server laid its words out into (ADR-0008), stored
  /// as it rendered them and made to carry their own pictures (ADR-0009).
  ///
  /// Pages land beside the copy they replace and move into place only after
  /// every page is present. A failed attempt keeps that staging directory: a
  /// retry reuses each complete page and fetches only what is missing. The
  /// durable queue decides whether that partial remains live when [scan]
  /// next reconciles the profile.
  Future<SavedChapter> download({
    required KavitaClient client,
    required SavedChapter chapter,
    required DownloadProgressCallback onProgress,
    int? knownTotalPages,
    CancelToken? cancelToken,
  }) async {
    final dir = await chapterDir(chapter.chapterId);
    dir.createSync(recursive: true);
    final staging = Directory('${dir.path}/$stagingDirName');
    // A failed attempt leaves complete pages here. The queue is the authority
    // that decides whether this staging directory is still a live download.
    staging.createSync(recursive: true);
    _adoptUncommittedPages(dir, staging);

    final int pages;
    var bytes = 0;
    var completed = 0;
    try {
      switch (chapter.content) {
        case ChapterContent.fixedPages:
          pages = chapter.pages;
          final stored = <File>[];
          for (var page = 0; page < pages; page++) {
            final file = File('${staging.path}/${pageFileName(page)}');
            stored.add(file);
            if (_isCompletePage(file)) {
              completed++;
              bytes += file.lengthSync();
            }
          }
          if (completed > 0) await onProgress(completed, pages);
          await _runPageWorkers(pages, (page) async {
            final file = stored[page];
            if (_isCompletePage(file)) return;
            final data = await client.readerImageBytes(
              chapter.chapterId,
              page,
              cancelToken: cancelToken,
            );
            await _writePage(file, data);
            bytes += data.length;
            completed++;
            await onProgress(completed, pages);
          });
        case ChapterContent.reflowable:
          // Once a rendered page exists, its page count is part of the copy:
          // Kavita may repaginate the book between attempts (ADR-0009).
          pages =
              knownTotalPages ??
              (await client.bookInfo(
                chapter.chapterId,
                cancelToken: cancelToken,
              )).pages;
          if (knownTotalPages == null) await onProgress(0, pages);
          final stored = <File>[];
          for (var page = 0; page < pages; page++) {
            final file = File('${staging.path}/${pageFileName(page)}');
            stored.add(file);
            if (_isCompletePage(file)) {
              completed++;
              bytes += file.lengthSync();
            }
          }
          if (completed > 0) await onProgress(completed, pages);
          // A picture named on several newly fetched pages is fetched once,
          // including while those pages are being fetched concurrently.
          final carried = <String, Future<String?>>{};
          await _runPageWorkers(pages, (page) async {
            if (_isCompletePage(stored[page])) return;
            bytes += await _storeBookPage(
              staging,
              client: client,
              chapterId: chapter.chapterId,
              page: page,
              cancelToken: cancelToken,
              carried: carried,
            );
            completed++;
            await onProgress(completed, pages);
          });
      }
    } on Object {
      // The queue record already describes whether this partial failed,
      // stopped with the process, or was cancelled by the reader. Leave the
      // bytes in place until that authority either retries or discards them.
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
      // Where the reader was survives too, but only in the pagination it was
      // written in: a copy stored again at another count of pages has other
      // pages, and a place on one of the old ones is a place on nothing.
      place: pages == chapter.pages ? chapter.place : null,
      format: chapter.format,
      language: chapter.language,
    );
    File('${dir.path}/meta.json').writeAsStringSync(jsonEncode(saved.toJson()));
    return saved;
  }

  static SavedChapter? _readSavedChapter(Directory dir) {
    try {
      final meta = File('${dir.path}/meta.json');
      if (!meta.existsSync()) return null;
      return SavedChapter.fromJson(jsonDecode(meta.readAsStringSync()));
    } on Object {
      return null;
    }
  }

  static void _adoptUncommittedPages(Directory dir, Directory staging) {
    if (_readSavedChapter(dir) != null) return;
    for (final entity in dir.listSync()) {
      if (entity is! File || !_isCompletePage(entity)) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (pageOfFileName(name) == null) continue;
      final staged = File('${staging.path}/$name');
      if (_isCompletePage(staged)) continue;
      if (staged.existsSync()) staged.deleteSync();
      entity.renameSync(staged.path);
    }
  }

  static bool _isCompletePage(File file) =>
      file.existsSync() && file.lengthSync() > 0;

  static Future<void> _writePage(File file, List<int> bytes) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes);
    await temp.rename(file.path);
  }

  static Future<void> _runPageWorkers(
    int pages,
    Future<void> Function(int page) work,
  ) async {
    var nextPage = 0;
    var stopped = false;
    Object? firstError;
    StackTrace? firstStack;

    Future<void> worker() async {
      while (!stopped) {
        final page = nextPage++;
        if (page >= pages) return;
        try {
          await work(page);
        } on Object catch (error, stack) {
          firstError ??= error;
          firstStack ??= stack;
          stopped = true;
        }
      }
    }

    final workers = pages < maxConcurrentPageDownloads
        ? pages
        : maxConcurrentPageDownloads;
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
    if (firstError case final error?) {
      Error.throwWithStackTrace(error, firstStack!);
    }
  }

  /// Puts [staging]'s pages in [dir]'s place, and drops what the copy used to
  /// hold that is no longer a page of it.
  ///
  /// The leftovers are the whole reason this is a swap rather than a copy over
  /// the top: a server that has recounted a book leaves pages behind that are
  /// not pages of it any more, and a reader that found them would call the
  /// copy longer than it is.
  ///
  /// The one exception is the book's own face, which a copy carries under the
  /// frozen names [BookFontFile.roman] and [BookFontFile.italic]. That name
  /// lives in the reader's module so the two cannot disagree about it — the
  /// download code does not know what a font file is, only that these two
  /// names are not pages and must survive promotion.
  Future<void> _promote(Directory dir, Directory staging, int pages) async {
    for (var page = 0; page < pages; page++) {
      File('${staging.path}/${pageFileName(page)}')
          .renameSync('${dir.path}/${pageFileName(page)}');
    }
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      final page = pageOfFileName(name);
      if (page == null || page >= pages) {
        if (!BookFontFile.isCarried(name)) entity.deleteSync();
      }
    }
    await _deleteQuietly(staging);
  }

  /// Stores one page of a book: the HTML the server laid out, with every
  /// picture it named carried inside it, and the book's own face carried once
  /// per copy.
  ///
  /// Returns what the page cost, which is what the Downloads tab reports.
  Future<int> _storeBookPage(
    Directory dir, {
    required KavitaClient client,
    required int chapterId,
    required int page,
    required Map<String, Future<String?>> carried,
    CancelToken? cancelToken,
  }) async {
    final html = await client.bookPage(
      chapterId,
      page,
      cancelToken: cancelToken,
    );

    // The book's face is the same on every page; parse it on the first page
    // we see and memoize the font fetches in [carried] so a 300-page book
    // fetches its font once. A font the server refuses costs the copy its
    // font and not the reader the book — same shape as a refused picture.
    final face = parseBookFace(html);
    if (face != null && !face.isEmpty) {
      final chapterDir = dir.parent;
      if (face.roman != null) {
        await carried.putIfAbsent(
          'font:roman:${face.roman}',
          () => _carryFont(
            client,
            chapterId,
            face.roman!,
            BookFontFile.roman,
            chapterDir,
            cancelToken,
          ),
        );
      }
      if (face.italic != null) {
        await carried.putIfAbsent(
          'font:italic:${face.italic}',
          () => _carryFont(
            client,
            chapterId,
            face.italic!,
            BookFontFile.italic,
            chapterDir,
            cancelToken,
          ),
        );
      }
    }

    final resolved = <String, String?>{};
    for (final src in BookPage.fromHtml(html).pictureSources) {
      // Asked for once however many pages name it — including a picture the
      // server refuses, which is why the in-flight future itself is memoized.
      resolved[src] = await carried.putIfAbsent(
        src,
        () => _carryPicture(client, chapterId, src, cancelToken),
      );
    }
    final stored = utf8.encode(
      renameBookPictures(html, (src) => resolved[src]),
    );
    await _writePage(File('${dir.path}/${pageFileName(page)}'), stored);
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

  /// Fetches a font file from the book-resources endpoint and writes it to the
  /// chapter directory under the frozen name ([fontName] — either
  /// [BookFontFile.roman] or [BookFontFile.italic]).
  ///
  /// A font the server refuses costs the copy its font and not the reader the
  /// book — the same shape as a refused picture in [_carryPicture]. The future
  /// completes with null on failure so the memoization in [carried] remembers
  /// the refusal and does not retry on subsequent pages.
  Future<String?> _carryFont(
    KavitaClient client,
    int chapterId,
    String src,
    String fontName,
    Directory chapterDir,
    CancelToken? cancelToken,
  ) async {
    try {
      final bytes = await client.bookPictureBytes(
        chapterId,
        src,
        cancelToken: cancelToken,
      );
      final file = File('${chapterDir.path}/$fontName');
      await _writePage(file, bytes);
      return fontName;
    } on DioException catch (error) {
      // A cancelled download is not a font that could not be fetched.
      if (error.type == DioExceptionType.cancel) rethrow;
      return null;
    }
  }

  /// Drops only the resumable bytes of an attempt. A refresh may have a saved
  /// copy beside its staging directory; cancellation never spends that copy.
  Future<void> discardPartial(int chapterId) async {
    final dir = await chapterDir(chapterId);
    if (!dir.existsSync()) return;
    final saved = _readSavedChapter(dir);
    if (saved != null) {
      await _deleteQuietly(Directory('${dir.path}/$stagingDirName'));
      return;
    }
    await _deleteQuietly(dir);
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
