import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/models.dart';

/// Checks the hand-written client against Kavita's own OpenAPI description.
///
/// We deliberately do **not** generate a client from that description (see
/// CLAUDE.md for the numbers). What the spec is good for is the one class of
/// mistake nothing else here can catch: a key we read that the server does not
/// send. Every `fromJson` in `models.dart` defends itself with `?? default`,
/// because Kavita omits null fields — so a mistyped key is swallowed into a
/// plausible value rather than throwing. `json['format']` mistyped makes every
/// EPUB row tappable; `json['type']` mistyped makes a comic library say
/// "chapitre"; `json['isSpecial']` mistyped files a special under the numbered
/// run. None of those throws, and none fails another test in this suite.
///
/// Three things are deliberately **not** asserted, because the spec is not
/// good enough at them to assert anything:
///
/// - **`required` / `nullable`.** Only 60 of 319 schemas declare `required`,
///   and not one of the six response DTOs this app reads. It is Swashbuckle
///   output: `nullable: true` marks reference types only, so every `int`,
///   `bool` and `DateTime` is emitted non-nullable *and* not required. The
///   `?? 0` defences in `models.dart` are right and the spec is wrong.
/// - **Response content types.** `/api/Reader/image` declares no `content` at
///   all, and `image/*` and `application/octet-stream` appear nowhere.
/// - **Status codes.** All 485 operations declare exactly one response, `200`.
///   There are no error responses to check `ConnectionFailure` against.
void main() {
  /// Where the spec lives, found rather than pinned: it is refreshed by hand
  /// and its name carries the version, so a pinned path would break on every
  /// refresh. Absent, this **fails** — an oracle that skips itself rots.
  late final Map<String, dynamic> spec;
  late final String specName;

  setUpAll(() {
    final directory = Directory('docs/openapi');
    expect(
      directory.existsSync(),
      isTrue,
      reason:
          'docs/openapi is missing; the client has nothing to check against',
    );
    final candidates =
        directory
            .listSync()
            .whereType<File>()
            .where((f) => RegExp(r'kavita-openapi-.+\.json$').hasMatch(f.path))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(
      candidates,
      hasLength(1),
      reason:
          'expected exactly one docs/openapi/kavita-openapi-*.json, found '
          '${candidates.map((f) => f.uri.pathSegments.last).toList()}',
    );
    specName = candidates.single.uri.pathSegments.last;
    spec = jsonDecode(
      candidates.single.readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  Map<String, dynamic> schemas() =>
      (spec['components'] as Map<String, dynamic>)['schemas']
          as Map<String, dynamic>;

  Map<String, dynamic> schema(String name) {
    final found = schemas()[name];
    expect(found, isNotNull, reason: 'no schema named $name in $specName');
    return found as Map<String, dynamic>;
  }

  /// Follows a `$ref` to the schema it names. Enum-valued properties are
  /// `$ref`s, and the app reads them as the ints they are.
  Map<String, dynamic> resolve(Map<String, dynamic> node) {
    final ref = node[r'$ref'];
    if (ref is! String) return node;
    return resolve(schema(ref.split('/').last));
  }

  test('the spec is named after the version it describes', () {
    // The file that arrived here was called `kavita-openapi-9.0.2.json` while
    // describing 0.9.0.0. A hand-refreshed file invites exactly that, and a
    // spec whose name lies about its version is worse than none.
    final version = (spec['info'] as Map<String, dynamic>)['version'];
    expect(specName, 'kavita-openapi-$version.json');
  });

  group('every endpoint the client calls exists', () {
    // Hand-listed rather than derived: there are only 22, they change rarely,
    // and several are built by interpolation (`'/api/Series/$seriesId'`, the
    // cover URLs) in a shape no regex should be trusted to template.
    const called = {
      '/api/Account/login': 'post',
      '/api/Account/refresh-token': 'post',
      '/api/Health': 'get',
      '/api/Plugin/version': 'get',
      '/api/Library/libraries': 'get',
      '/api/Library/scan': 'post',
      '/api/Series/all-v2': 'post',
      '/api/Series/currently-reading': 'get',
      '/api/Series/on-deck': 'post',
      '/api/Series/{seriesId}': 'get',
      '/api/Series/metadata': 'get',
      '/api/Series/volumes': 'get',
      '/api/Reader/chapter-info': 'get',
      '/api/Reader/mark-multiple-read': 'post',
      '/api/Reader/mark-multiple-unread': 'post',
      '/api/Reader/progress': 'post',
      '/api/Reader/image': 'get',
      '/api/Reader/thumbnail': 'get',
      '/api/Image/series-cover': 'get',
      '/api/Image/volume-cover': 'get',
      '/api/Image/chapter-cover': 'get',
      '/api/Device/client/devices': 'get',
      '/api/Device/client/update-name': 'post',
    };

    for (final entry in called.entries) {
      test('${entry.value.toUpperCase()} ${entry.key}', () {
        final paths = spec['paths'] as Map<String, dynamic>;
        expect(
          paths,
          contains(entry.key),
          reason: '${entry.key} is not a path in $specName',
        );
        expect(paths[entry.key] as Map<String, dynamic>, contains(entry.value));
      });
    }
  });

  group('every field the DTOs read', () {
    /// Which schema each class in `models.dart` parses. Explicit because the
    /// names deliberately no longer correspond: our classes are the domain's
    /// nouns, and only `ClientDeviceDto` keeps the suffix, being the one type
    /// that mirrors Kavita's wire and nothing else.
    const schemaFor = {
      'LoginResult': 'UserDto',
      'Library': 'LibraryDto',
      'Series': 'SeriesDto',
      'SeriesMetadata': 'SeriesMetadataDto',
      'Volume': 'VolumeDto',
      'Chapter': 'ChapterDto',
      'ChapterInfo': 'ChapterInfoDto',
      'PageDimension': 'FileDimensionDto',
      'ClientDeviceDto': 'ClientDeviceDto',
    };

    /// The nested reads the regex below cannot see: `SeriesMetadata._names`
    /// takes the key as a parameter, so `writers[].name` and `genres[].title`
    /// are invisible in the source and listed by hand.
    const nested = {
      'PersonDto': {'name': 'String'},
      'GenreTagDto': {'title': 'String'},
    };

    /// What a declared JSON type may be cast to in Dart. An `integer` may be
    /// read as `num`; a `number` may **not** be read as `int` — a float that
    /// arrives as `1.5` throws on `as int`, which is the bug this catches.
    const castsFor = {
      'integer': {'int', 'num'},
      'number': {'num'},
      'string': {'String'},
      'boolean': {'bool'},
      'array': {'List<dynamic>'},
    };

    /// Every `json['key']` in `models.dart`, attributed to the class whose
    /// body it sits in, with the Dart type it is cast to where there is one.
    ///
    /// Derived from the source instead of listed here on purpose: a list is
    /// where this rots — someone reads a new field, forgets the entry, and the
    /// check passes while covering less than it did.
    Map<String, Map<String, String?>> readsByClass(String source) {
      final declaration = RegExp(r'^class (\w+)');
      final read = RegExp(
        r"json\['(\w+)'\](?:\s*as\s+(int|String|num|bool|List<dynamic>)\??)?",
      );
      final reads = <String, Map<String, String?>>{};
      var current = '';
      for (final line in source.split('\n')) {
        final match = declaration.firstMatch(line);
        if (match != null) current = match.group(1)!;
        for (final found in read.allMatches(line)) {
          final casts = reads[current] ??= {};
          // Keep a cast already seen: the same key may also be read without
          // one (`PageDimension` tests `pageNumber` with `is!` instead).
          casts[found.group(1)!] = found.group(2) ?? casts[found.group(1)!];
        }
      }
      return reads;
    }

    late final Map<String, Map<String, String?>> reads;

    setUpAll(() {
      reads = readsByClass(File('lib/src/api/models.dart').readAsStringSync());
    });

    test('is read by a class this test knows the schema for', () {
      // The guard on the derivation above: a new DTO must be mapped to a
      // schema or it is silently unchecked.
      expect(reads.keys, everyElement(isIn(schemaFor.keys)));
      expect(reads.keys, containsAll(schemaFor.keys));
    });

    test(
      'exists on that schema, is typed compatibly, and is not deprecated',
      () {
        final problems = <String>[];
        final checks = {
          for (final entry in reads.entries) schemaFor[entry.key]!: entry.value,
          ...nested,
        };

        for (final entry in checks.entries) {
          final properties =
              schema(entry.key)['properties'] as Map<String, dynamic>?;
          if (properties == null) {
            problems.add('${entry.key} declares no properties at all');
            continue;
          }
          for (final read in entry.value.entries) {
            final property = properties[read.key];
            if (property == null) {
              problems.add('${entry.key}.${read.key} is not in the spec');
              continue;
            }
            final declared = resolve(property as Map<String, dynamic>);
            if (declared['deprecated'] == true) {
              problems.add('${entry.key}.${read.key} is deprecated');
            }
            final cast = read.value;
            if (cast == null) continue;
            final allowed = castsFor[declared['type']];
            if (allowed == null) {
              problems.add(
                '${entry.key}.${read.key} declares type '
                '${declared['type']}, which this test has no rule for',
              );
            } else if (!allowed.contains(cast)) {
              problems.add(
                '${entry.key}.${read.key} is ${declared['type']} in the spec '
                'but read as $cast',
              );
            }
          }
        }

        expect(problems, isEmpty, reason: problems.join('\n'));
      },
    );
  });

  group('every enum value the client hardcodes', () {
    /// Looked up **by value, never by position**: `SeriesSortField`'s enum is
    /// one-based (`[1..11]`) where the other three are zero-based, so indexing
    /// `x-enum-varnames` would assert the wrong name and pass while doing it.
    String nameOf(String enumSchema, int value) {
      final node = schema(enumSchema);
      final values = (node['enum'] as List<dynamic>).cast<int>();
      final names = (node['x-enum-varnames'] as List<dynamic>).cast<String>();
      expect(
        names,
        hasLength(values.length),
        reason: '$enumSchema names do not line up with its values',
      );
      final index = values.indexOf(value);
      expect(index, isNot(-1), reason: '$enumSchema has no value $value');
      return names[index];
    }

    test('the /api/Series/all-v2 filter body', () {
      expect(nameOf('FilterComparison', FilterComparison.contains), 'Contains');
      expect(
        nameOf('SeriesFilterField', SeriesFilterField.libraries),
        'Libraries',
      );
      expect(nameOf('FilterCombination', FilterCombination.and), 'And');
      expect(nameOf('SeriesSortField', SeriesSortField.sortName), 'SortName');
    });

    /// The two enums the app models in full, because their *meaning* drives
    /// the UI: the library type names every part of a series, and the format
    /// decides whether our reader can open it at all.
    String varname(Enum value) =>
        value.name[0].toUpperCase() + value.name.substring(1);

    test('LibraryType, in full', () {
      for (final type in LibraryType.values) {
        expect(nameOf('LibraryType', type.id), varname(type));
      }
    });

    test('MangaFormat, in full', () {
      for (final format in MangaFormat.values) {
        expect(nameOf('MangaFormat', format.id), varname(format));
      }
    });
  });
}
