import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';
import 'package:patra/src/catalogue/catalogue_store.dart';

/// A root of its own per test, so nothing here can read what another wrote.
Directory _root() {
  final root = Directory.systemTemp.createTempSync('patra-catalogue');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  return root;
}

CatalogueStore _store(Directory root, [String profileId = 'https://a#1']) =>
    CatalogueStore(root: root, profileId: profileId);

Library _library(int id, {String name = 'Mangas', LibraryType? type}) =>
    Library(id: id, name: name, type: type ?? LibraryType.manga);

Series _series(int id, {String name = 'Blame!', int libraryId = 1}) => Series(
  id: id,
  name: name,
  libraryId: libraryId,
  libraryName: 'Mangas',
  pages: 200,
  pagesRead: 40,
  format: MangaFormat.archive,
  latestReadDate: DateTime.parse('2026-09-05T10:00:00'),
);

Chapter _chapter(int id) => Chapter(
  id: id,
  title: '$id',
  titleName: 'Le duel',
  range: '$id',
  minNumber: id,
  pages: 20,
  pagesRead: 3,
  isSpecial: false,
  sortOrder: id,
  format: MangaFormat.archive,
);

Volume _volume(int id, {List<Chapter>? chapters}) => Volume(
  id: id,
  name: 'Tome $id',
  minNumber: id,
  pages: 200,
  pagesRead: 40,
  chapters: chapters ?? [_chapter(id * 10)],
);

void main() {
  group('what it remembers', () {
    test('a spine written comes back whole', () async {
      final root = _root();
      // Through the store, never by hand: a file written straight into the
      // layout is what the test would then read back, which makes it a test
      // of nothing but `jsonDecode`.
      final writing = _store(root);
      await writing.putLibraries([_library(1), _library(2, name: 'Comics')]);
      await writing.putSeriesList(1, [_series(5), _series(6)]);

      final spine = await _store(root).loadSpine();

      expect(spine.libraries.map((l) => l.name), ['Mangas', 'Comics']);
      expect(spine.series[1]!.map((s) => s.id), [5, 6]);
      expect(spine.series[1]!.first.latestReadDate, isNotNull);
    });

    test('a series never opened is nothing at all, not an empty one', () async {
      expect(await _store(_root()).loadSeries(5), isNull);
    });

    test('the three parts of a series are written by three fetches', () async {
      final root = _root();
      final writing = _store(root);
      await writing.putVolumes(5, [_volume(1)]);
      await writing.putSeries(_series(5));
      await writing.putSeriesMetadata(
        5,
        const SeriesMetadata(
          summary: 'A city',
          writers: ['Nihei'],
          genres: ['Cyberpunk'],
          releaseYear: 1997,
        ),
      );

      final stored = (await _store(root).loadSeries(5))!;

      // Merged rather than replaced: the description must survive the volumes
      // being fetched again, and the other way round.
      expect(stored.volumes!.single.chapters.single.titleName, 'Le duel');
      expect(stored.series!.name, 'Blame!');
      expect(stored.metadata!.writers, ['Nihei']);
      expect(stored.metadata!.genres, ['Cyberpunk']);
      expect(stored.metadata!.releaseYear, 1997);
    });

    test('on deck comes back in the order it was stored', () async {
      final root = _root();
      await _store(root).putOnDeck([_series(6), _series(5)]);
      expect((await _store(root).loadOnDeck()).map((s) => s.id), [6, 5]);
    });
  });

  group('what it forgets', () {
    test('a fetch replaces a list rather than merging into it', () async {
      final root = _root();
      final store = _store(root);
      await store.putSeriesList(1, [_series(5), _series(6)]);
      // What a server that has lost a series answers with. Merging would keep
      // the one that is gone for good.
      await store.putSeriesList(1, [_series(5)]);

      expect((await _store(root).loadSpine()).series[1]!.map((s) => s.id), [5]);
    });

    test('a library gone takes its series and their files with it', () async {
      final root = _root();
      final store = _store(root);
      await store.putLibraries([_library(1), _library(2)]);
      await store.putSeriesList(2, [_series(9, libraryId: 2)]);
      await store.putVolumes(9, [_volume(1)]);
      // Access revoked in Kavita: nothing would ever list library 2 again,
      // so what was filed under it could not be reached or explained.
      await store.putLibraries([_library(1)]);

      final reading = _store(root);
      final spine = await reading.loadSpine();
      expect(spine.libraries.map((l) => l.id), [1]);
      expect(spine.series, isNot(contains(2)));
      // Down to the volumes of what was in it: left behind they would be
      // files no screen could reach, collected only by removing the profile.
      expect(await reading.loadSeries(9), isNull);
    });

    test('a version bump discards rather than migrates', () async {
      final root = _root();
      final store = _store(root);
      await store.putLibraries([_library(1)]);
      await store.putSeriesList(1, [_series(5)]);
      await store.putVolumes(5, [_volume(1)]);

      // The one thing a fixture cannot go through the store for: what an
      // *older build* wrote. Only the stamp is touched — the payload beside
      // it is this build's own, so what the read refuses is the version and
      // nothing else.
      final spine = File('${(await store.profileRoot()).path}/spine.json');
      final aged = jsonDecode(spine.readAsStringSync()) as Map<String, dynamic>;
      spine.writeAsStringSync(
        jsonEncode({...aged, 'version': CatalogueStore.version - 1}),
      );

      final reading = _store(root);
      expect((await reading.loadSpine()).isEmpty, isTrue);
      // The whole catalogue, not the one file the stamp was found on: a bump
      // changes every file, and half a discarded catalogue is a shape nothing
      // here knows how to read.
      expect((await reading.profileRoot()).existsSync(), isFalse);
      expect(await reading.loadSeries(5), isNull);
    });

    test('removing a profile leaves nothing of its catalogue', () async {
      final root = _root();
      final store = _store(root);
      await store.putLibraries([_library(1)]);
      await store.removeAll();

      expect((await store.profileRoot()).existsSync(), isFalse);
      expect((await _store(root).loadSpine()).isEmpty, isTrue);
    });
  });

  group('two fetches landing at once', () {
    test('do not drop one another\'s series list', () async {
      final root = _root();
      final store = _store(root);
      // What the eager fill and the Library tab's own fetch really do: both
      // start before either has written. Read-modify-write across the await
      // would have the second build on the spine as it was before the first.
      await Future.wait([
        store.putSeriesList(1, [_series(5)]),
        store.putSeriesList(2, [_series(9, libraryId: 2)]),
      ]);

      final spine = await _store(root).loadSpine();
      expect(spine.series[1]!.single.id, 5);
      expect(spine.series[2]!.single.id, 9);
    });

    test('do not drop one another\'s part of a series', () async {
      final root = _root();
      final store = _store(root);
      // Exactly what the series screen does: three fetches for one series,
      // all in flight together, each merging into the same file.
      await Future.wait([
        store.putVolumes(5, [_volume(1)]),
        store.putSeries(_series(5)),
        store.putSeriesMetadata(5, const SeriesMetadata(summary: 'A city')),
      ]);

      final stored = (await _store(root).loadSeries(5))!;
      expect(stored.volumes, isNotNull);
      expect(stored.series, isNotNull);
      expect(stored.metadata!.summary, 'A city');
    });
  });

  group('whose catalogue it is', () {
    test('two profiles at one address do not share a shelf', () async {
      final root = _root();
      await _store(root, 'https://a#1').putSeriesList(1, [_series(5)]);
      await _store(root, 'https://a#2').putSeriesList(1, [_series(6)]);

      expect(
        (await _store(root, 'https://a#1').loadSpine()).series[1]!.single.id,
        5,
      );
      expect(
        (await _store(root, 'https://a#2').loadSpine()).series[1]!.single.id,
        6,
      );
    });

    test('the directory is the id, readable and reversible', () async {
      final root = _root();
      final store = _store(root, 'https://kavita.example#3');
      await store.putLibraries([_library(1)]);

      final name = (await store.profileRoot()).uri.pathSegments
          .where((s) => s.isNotEmpty)
          .last;
      expect(Uri.decodeComponent(name), 'https://kavita.example#3');
    });
  });

  group('a store nothing can write to', () {
    test('swallows the failure rather than failing the fetch', () async {
      // A file where the profile directory has to go: every write below is
      // reached from the body of a fetch a screen is waiting on, and a device
      // with no room left has to show its shelves rather than an error about
      // a cache.
      final root = _root();
      root.createSync(recursive: true);
      File('${root.path}/${CatalogueStore.dirNameFor('https://a#1')}')
          .writeAsStringSync('not a directory');

      final store = _store(root);
      await expectLater(store.putLibraries([_library(1)]), completes);
      await expectLater(store.putVolumes(5, [_volume(1)]), completes);
      // The session goes on holding what it fetched: losing the spine in
      // memory as well would cost this session's shelves over a disk the
      // catalogue is not what fills. It is the next launch that finds
      // nothing, which is what a store nobody could write to means.
      expect(store.spine!.libraries, hasLength(1));
      expect((await _store(root).loadSpine()).isEmpty, isTrue);
    });
  });
}
