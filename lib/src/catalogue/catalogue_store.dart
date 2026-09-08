import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../api/models.dart';
import '../profile_files.dart';

/// What the device remembers of one profile's shelves: the libraries, the
/// series in them, and the parts of the series that profile has looked inside.
///
/// A third store beside the saved chapters and the image cache, and the line
/// between them is what it holds: this **names what exists and never holds a
/// page**. Every byte of it is refetchable, which is what makes it
/// discardable by design — the worst a wrong catalogue costs is one refresh
/// (ADR-0005).
///
/// `<documents>/catalogue/<profile>/`, split by level rather than one file
/// per profile because the sizes make it matter: a 2000-series library is
/// ~500KB and a series' volumes ~50KB, so one file would rewrite megabytes
/// every time a series is opened.
///
/// - `spine.json` — the libraries and every library's series list, read whole.
/// - `series/<id>.json` — one series' volumes, its own row and its
///   description.
/// - `ondeck.json` — the On deck answer, which is Home's whole shelf.
///
/// Under **documents** rather than the system cache directory: a store the OS
/// may silently empty cannot be the thing that makes navigation consistent —
/// that is what the image cache already is.
class CatalogueStore {
  CatalogueStore({Directory? root, required this.profileId})
    : _rootOverride = root;

  /// Whose catalogue this is — [Profile.id], the only thing anything keys a
  /// profile on. What a person may see is the server's answer to them alone,
  /// so two people at one address cannot share a file here any more than they
  /// can share a saved chapter.
  final String profileId;

  /// The shape of what is written. A mismatch **discards rather than
  /// migrates**, on the same argument that deletes the old auth layouts
  /// instead of reading them: a catalogue is recoverable by one refresh, so a
  /// migration path is code that can only ever be wrong.
  static const version = 1;

  static const _versionKey = 'version';
  static const _spineFile = 'spine.json';
  static const _onDeckFile = 'ondeck.json';

  final Directory? _rootOverride;
  Directory? _root;

  /// The spine as it stands, in memory: what was read off the device plus
  /// every fetch written since.
  ///
  /// Held because the spine is the part read **whole**, and reading it is
  /// what `main()` awaits before the first frame. Nothing would be gained by
  /// awaiting a read whose answer the next reader has to fetch again.
  Spine? _spine;

  /// The catalogue root, which the **device** owns: every profile's
  /// catalogue is a directory inside it.
  Future<Directory> _catalogueRoot() async {
    final existing = _root ?? _rootOverride;
    if (existing != null) {
      _root = existing;
      return existing;
    }
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory('${documents.path}/catalogue');
    _root = root;
    return root;
  }

  /// Where this profile's catalogue lives.
  ///
  /// The profile segment is percent-encoded, as `downloads/` does it: an id
  /// is an address with an account id on the end of it, it is reversible by
  /// eye on a device, and — unlike a hash — two profiles cannot possibly land
  /// in one directory.
  Future<Directory> profileRoot() async =>
      Directory('${(await _catalogueRoot()).path}/${dirNameFor(profileId)}');

  /// See [profileRoot] and [profileDirName], which the saved chapters file by
  /// too — one definition, because both layouts argue from the encoding.
  static String dirNameFor(String profileId) => profileDirName(profileId);

  Future<File> _file(String name) async =>
      File('${(await profileRoot()).path}/$name');

  // ---------------------------------------------------------------- spine

  /// The libraries and their series lists, read off the device once and kept.
  ///
  /// Answers from memory after the first call: every write below keeps
  /// [_spine] in step, so the file is only ever the way this starts.
  Future<Spine> loadSpine() async {
    final held = _spine;
    if (held != null) return held;
    // Through the same queue the writes go through, and `??=` on top of it:
    // two callers arriving before the file has been read must not both read
    // it, or the second would hand back the device's answer over the first
    // fetch already written on top of it.
    await _oneAtATime(_spineFile, () async {
      _spine ??= await _readAs(_spineFile, Spine.fromJson) ?? const Spine();
    });
    return _spine!;
  }

  /// The spine as it stands, without touching the device — null until
  /// [loadSpine] has been awaited.
  Spine? get spine => _spine;

  /// Replaces the library list.
  ///
  /// A fetch **replaces**: a library this profile has lost access to has to
  /// disappear, and so do the series filed under it, which nothing would ever
  /// list again.
  Future<void> putLibraries(List<Library> libraries) async {
    await loadSpine();
    final dropped = <int>[];
    await _oneAtATime(_spineFile, () async {
      // Read **inside** the queue, so it is the spine as the write before
      // this one left it: two fetches that had each read it up front would
      // both build on the older one, and the second would drop the first.
      final current = _spine!;
      final kept = {for (final library in libraries) library.id};
      for (final entry in current.series.entries) {
        if (!kept.contains(entry.key)) {
          dropped.addAll(entry.value.map((series) => series.id));
        }
      }
      await _writeSpine(
        Spine(
          libraries: libraries,
          series: {
            for (final entry in current.series.entries)
              if (kept.contains(entry.key)) entry.key: entry.value,
          },
        ),
      );
    });
    // The volumes and descriptions of what was under a library nothing lists
    // any more. Left behind they would be files no screen could reach or
    // explain, and only removing the profile would ever collect them.
    for (final seriesId in dropped) {
      await _deleteSeries(seriesId);
    }
  }

  /// Replaces one library's series list — see [putLibraries] for why
  /// replacing rather than merging.
  Future<void> putSeriesList(int libraryId, List<Series> series) async {
    await loadSpine();
    // See [putLibraries]: read inside the queue, never before it.
    await _oneAtATime(_spineFile, () async {
      final current = _spine!;
      await _writeSpine(
        Spine(
          libraries: current.libraries,
          series: {...current.series, libraryId: series},
        ),
      );
    });
  }

  /// Raw, and only ever called from inside [_oneAtATime]: queueing here as
  /// well would be a write waiting on the write it is part of.
  Future<void> _writeSpine(Spine next) async {
    _spine = next;
    await _write(_spineFile, next.toJson());
  }

  // --------------------------------------------------------------- on deck

  /// The On deck answer as it stands, in memory: what was read off the device
  /// plus every fetch written since.
  ///
  /// Held for the reason [_spine] is, and it is what keeps the overlay's
  /// fallback the freshest ranking the device has rather than the one the
  /// session opened with — see `onDeckOverlay`.
  List<Series>? _onDeck;

  /// The On deck answer without touching the device — null until
  /// [loadOnDeck] has been awaited or a fetch has written one.
  List<Series>? get onDeck => _onDeck;

  Future<List<Series>> loadOnDeck() async {
    final held = _onDeck;
    if (held != null) return held;
    // Through the queue, and `??=` on top of it, for the reason [loadSpine]
    // is: two readers arriving before the file has been read must not both
    // read it, or the second would hand back the device's answer over the
    // fetch already written on top of it.
    await _oneAtATime(_onDeckFile, () async {
      _onDeck ??=
          await _readAs(_onDeckFile, (json) => _seriesList(json['series'])) ??
          const [];
    });
    return _onDeck!;
  }

  Future<void> putOnDeck(List<Series> series) {
    _onDeck = series;
    return _oneAtATime(
      _onDeckFile,
      () => _write(_onDeckFile, {
        'series': [for (final one in series) one.toJson()],
      }),
    );
  }

  // ---------------------------------------------------------------- series

  /// Everything stored about one series, or null where nothing is.
  ///
  /// Read per series rather than with the spine: this is the trace of what
  /// has actually been opened, and a device that has browsed a 2000-series
  /// library would otherwise load all of it to draw one screen.
  Future<StoredSeries?> loadSeries(int seriesId) =>
      _readAs('series/$seriesId.json', StoredSeries.fromJson);

  Future<void> putSeries(Series series) =>
      _mergeSeries(series.id, {'series': series.toJson()});

  Future<void> putVolumes(int seriesId, List<Volume> volumes) =>
      _mergeSeries(seriesId, {
        'volumes': [for (final volume in volumes) volume.toJson()],
      });

  Future<void> putSeriesMetadata(int seriesId, SeriesMetadata metadata) =>
      _mergeSeries(seriesId, {'metadata': metadata.toJson()});

  /// The three parts of a series file are written by three different fetches,
  /// so each one merges rather than replaces: a screen that has drawn the
  /// volumes and not the description must not lose the description.
  ///
  /// **One at a time per file**, because the series screen fires all three of
  /// those fetches at once: read-modify-write left to interleave would have
  /// each of them merge into the file as it was before the others, and the
  /// last to land would be the only part kept.
  Future<void> _mergeSeries(int seriesId, Map<String, dynamic> part) {
    final name = 'series/$seriesId.json';
    return _oneAtATime(name, () async {
      final current = await _read(name) ?? {};
      await _write(name, {...current, ...part});
    });
  }

  Future<void> _deleteSeries(int seriesId) {
    final name = 'series/$seriesId.json';
    return _oneAtATime(name, () async {
      try {
        final file = await _file(name);
        if (file.existsSync()) file.deleteSync();
      } on Object {
        // See [_write]: nothing about this store is worth failing over.
      }
    });
  }

  /// Work in flight per file name, so the next caller queues behind it rather
  /// than reading what the last one has not written yet.
  final _pending = <String, Future<void>>{};

  Future<void> _oneAtATime(String name, Future<void> Function() work) {
    final next = (_pending[name] ?? Future<void>.value()).then((_) => work());
    _pending[name] = next;
    // Dropped once it is the tail again, or the map would grow by one entry
    // per series a long session opens.
    return next.whenComplete(() {
      if (identical(_pending[name], next)) _pending.remove(name);
    });
  }

  // ------------------------------------------------------------------ life

  /// Deletes this profile's whole catalogue. Called when the profile is
  /// removed from the device, in the confirmation that already takes its
  /// lock, its preferences and its saved chapters — and deliberately not
  /// named in that copy, which lists what a person chose to keep and what it
  /// costs them.
  Future<void> removeAll() async {
    _spine = null;
    _onDeck = null;
    final root = await profileRoot();
    try {
      if (root.existsSync()) root.deleteSync(recursive: true);
    } on Object {
      // Nothing useful to do, and nothing to fail: the catalogue is the one
      // store here whose contents are worthless.
    }
  }

  // ------------------------------------------------------------------- io

  /// What one file holds, put through [parse], or null where there is
  /// nothing readable in it.
  ///
  /// The parse is inside the guard as well as the decode: a file that is
  /// valid JSON of the wrong shape is as worthless as a torn one, and neither
  /// is worth a crash on a store whose every byte is refetchable.
  Future<T?> _readAs<T>(
    String name,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final stored = await _read(name);
      return stored == null ? null : parse(stored);
    } on Object {
      return null;
    }
  }

  /// The payload of one file, or null where there is nothing readable in it.
  ///
  /// A **version mismatch discards the whole catalogue** rather than the file
  /// it was found in: the stamp is on the shape, and a bump changes every
  /// file. In practice it only ever fires on the spine, which is the first
  /// thing read on every path into a session.
  Future<Map<String, dynamic>?> _read(String name) async {
    try {
      final file = await _file(name);
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        await removeAll();
        return null;
      }
      if (decoded[_versionKey] != version) {
        await removeAll();
        return null;
      }
      return decoded;
    } on Object {
      // A torn or unreadable file — or no filesystem to read it off at all —
      // is one refresh away from being right again.
      return null;
    }
  }

  /// Writes [payload] under the version stamp, and **never throws**: this is
  /// called from the body of a fetch every screen is waiting on, and a device
  /// with no room left must show its shelves rather than an error about a
  /// cache.
  Future<void> _write(String name, Map<String, dynamic> payload) async {
    try {
      final file = await _file(name);
      file.parent.createSync(recursive: true);
      // Through a temp file and a rename, which is atomic on one filesystem:
      // a spine half-written when the app was killed would otherwise be read
      // back as a catalogue this profile does not have.
      final temp = File('${file.path}.tmp');
      temp.writeAsStringSync(jsonEncode({_versionKey: version, ...payload}));
      temp.renameSync(file.path);
    } on Object {
      // See above. Broad on purpose: this is reached from a fetch a screen is
      // waiting on, and there is no failure of a worthless store worth
      // turning into one of that fetch.
    }
  }
}

/// The part of the catalogue loaded whole: the libraries, and the series in
/// each of them. Everything under it — a series' volumes, its chapters, its
/// description — is loaded per series, when that series is opened.
class Spine {
  const Spine({this.libraries = const [], this.series = const {}});

  final List<Library> libraries;

  /// Library id → the series in it, as the last complete fetch listed them.
  final Map<int, List<Series>> series;

  bool get isEmpty => libraries.isEmpty && series.isEmpty;

  Map<String, dynamic> toJson() => {
    'libraries': [for (final library in libraries) library.toJson()],
    // Keyed by the id as a string, because JSON has no other kind of key.
    'series': {
      for (final entry in series.entries)
        '${entry.key}': [for (final one in entry.value) one.toJson()],
    },
  };

  factory Spine.fromJson(Map<String, dynamic> json) => Spine(
    libraries: [
      for (final library in json['libraries'] as List<dynamic>? ?? const [])
        if (library is Map<String, dynamic>) Library.fromJson(library),
    ],
    series: {
      for (final entry
          in (json['series'] as Map<String, dynamic>? ?? const {}).entries)
        ?int.tryParse(entry.key): _seriesList(entry.value),
    },
  );
}

/// What the device holds about one series: its own row, its volumes with
/// their chapters, and its description. Any of the three may be missing —
/// they arrive from three different fetches.
class StoredSeries {
  const StoredSeries({this.series, this.volumes, this.metadata});

  final Series? series;
  final List<Volume>? volumes;
  final SeriesMetadata? metadata;

  factory StoredSeries.fromJson(Map<String, dynamic> json) {
    final series = json['series'];
    final volumes = json['volumes'];
    final metadata = json['metadata'];
    return StoredSeries(
      series: series is Map<String, dynamic> ? Series.fromJson(series) : null,
      volumes: volumes is List<dynamic>
          ? [
              for (final volume in volumes)
                if (volume is Map<String, dynamic>) Volume.fromJson(volume),
            ]
          : null,
      metadata: metadata is Map<String, dynamic>
          ? SeriesMetadata.fromJson(metadata)
          : null,
    );
  }
}

List<Series> _seriesList(Object? json) => [
  for (final one in json as List<dynamic>? ?? const [])
    if (one is Map<String, dynamic>) Series.fromJson(one),
];
