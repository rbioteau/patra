import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/widgets/cover.dart';

import 'test_support.dart';

/// The same server, from two of the profiles this device holds.
KavitaClient _client(String apiKey) => KavitaClient(
  baseUrl: 'https://kavita.example',
  token: 'jwt-$apiKey',
  username: 'someone',
  apiKey: apiKey,
);

void main() {
  final his = _client('key-romain');
  final hers = _client('key-lea');

  test('two profiles browsing one series fetch its cover once', () {
    // The auth key sits in every image URL and the cache keys on the URL, so
    // without a key of its own a household of four downloads the same artwork
    // four times and stores it four times under the one budget they share.
    expect(
      imageCacheKey(hers.seriesCoverUrl(5)),
      imageCacheKey(his.seriesCoverUrl(5)),
    );
    expect(his.seriesCoverUrl(5), isNot(hers.seriesCoverUrl(5)));
  });

  test(
    'the key is the URL with the credential taken out, and nothing else',
    () {
      expect(
        imageCacheKey(his.seriesCoverUrl(5)),
        'https://kavita.example/api/Image/series-cover?seriesId=5',
      );
    },
  );

  test('what the key still tells apart is what is drawn', () {
    // Every part of the request that chooses an *image* has to stay in it —
    // the server, the endpoint, and everything identifying the page.
    final keys = {
      imageCacheKey(his.seriesCoverUrl(5)),
      imageCacheKey(his.seriesCoverUrl(6)),
      imageCacheKey(his.volumeCoverUrl(5)),
      imageCacheKey(his.chapterCoverUrl(5)),
      imageCacheKey(his.readerImageUrl(7, 0)),
      imageCacheKey(his.readerImageUrl(7, 1)),
      imageCacheKey(his.readerImageUrl(8, 0)),
      imageCacheKey(his.readerThumbnailUrl(7, 0)),
      imageCacheKey(_client('key-romain').seriesCoverUrl(5)),
    };
    expect(keys.length, 8, reason: 'only the two identical URLs may collide');

    expect(
      imageCacheKey(
        KavitaClient(
          baseUrl: 'https://other.example',
          token: 't',
          username: 'someone',
          apiKey: 'key-romain',
        ).seriesCoverUrl(5),
      ),
      isNot(imageCacheKey(his.seriesCoverUrl(5))),
      reason: 'a series id is only unique on the server that issued it',
    );
  });

  test('an avatar stays one per account', () {
    // A face is per person by construction — the account id is in the URL —
    // so sharing the key costs nothing and keeps one rule for every image.
    final mine = KavitaClient.userCoverUrl(
      baseUrl: 'https://kavita.example',
      userId: 1,
      apiKey: 'key-romain',
    );
    final theirs = KavitaClient.userCoverUrl(
      baseUrl: 'https://kavita.example',
      userId: 2,
      apiKey: 'key-lea',
    );
    expect(imageCacheKey(mine), isNot(imageCacheKey(theirs)));
  });

  test('a URL it cannot read is its own key', () {
    // Nothing builds one, but a key that threw would take a cover down with
    // it — and an unparseable URL was never going to be fetched anyway.
    expect(imageCacheKey('::not a url::'), '::not a url::');
  });

  testWidgets('a cover asks the cache for the shared key', (tester) async {
    mockPathProvider();
    String? keyOf(KavitaClient client) => tester
        .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .cacheKey;

    Future<String?> pumpCover(KavitaClient client) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 100,
            height: 150,
            child: CoverImage(
              url: client.seriesCoverUrl(5),
              headers: client.imageHeaders,
            ),
          ),
        ),
      );
      return keyOf(client);
    }

    expect(await pumpCover(his), await pumpCover(hers));
  });

  test('nothing draws an image on a key of its own', () {
    // The one rule this rests on, and the one a new screen would forget:
    // every cached image in the app is filed under `imageCacheKey`. Left to
    // the default, the auth key in the URL files it under the profile that
    // fetched it — which is the bug this exists to prevent, and it shows up
    // as a slow app rather than as a broken one.
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in RegExp(
        r'CachedNetworkImage(Provider)?\(',
      ).allMatches(source)) {
        if (!_arguments(source, match.end).contains('cacheKey:')) {
          offenders.add(file.path);
        }
      }
    }
    expect(offenders, isEmpty, reason: 'add cacheKey: imageCacheKey(url)');
  });
}

/// The text of the call whose opening parenthesis ends at [from].
String _arguments(String source, int from) {
  var depth = 1;
  for (var i = from; i < source.length; i++) {
    if (source[i] == '(') depth++;
    if (source[i] == ')') depth--;
    if (depth == 0) return source.substring(from, i);
  }
  return source.substring(from);
}
