/// What a page of a book is loaded into the web engine from: a document on
/// the device, and the files it names beside it (ADR-0013, #127).
///
/// A page cannot name its pictures at the server. `book-resources` is
/// header-authenticated in this client, and a header travels with the
/// top-level request alone — an engine's own `<img>` carries none of ours. So
/// every picture and font a page names is fetched **here**, with the client's
/// headers, written beside the page, and named to the rewrite pass as the file
/// it now is: online and offline alike, one mechanism.
///
/// The document is loaded **from a file**, and that is not a detail: the
/// rewrite accepts a name as local only where it has no scheme but `file:`, so
/// a page loaded from anything else would be left with its backstop policy
/// and nothing to draw. And on iOS an engine reads only inside the directory
/// it was handed, which is why a page is written at the root of the directory
/// its pictures and fonts are under rather than beside them.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../downloads/downloads_provider.dart';

import '../../settings/reading_settings.dart';
import 'book_rewrite.dart';

/// The directory every page of a book is written into, with what each page
/// names under it: the one directory an engine is handed to read.
///
/// In the temporary directory, because none of it is kept: a page is written
/// again the next time it is drawn, and the OS may reclaim the lot. A saved
/// copy is the documents directory's, and never this one. And one directory
/// **per profile**, like a copy: a chapter id is a server's, so two profiles
/// on two servers can both be reading a chapter 7.
final bookDocumentRootProvider = FutureProvider<Directory>((ref) async {
  final profile = ref.watch(downloadsServiceProvider).profileId;
  final name = sha1.convert(profile.codeUnits).toString().substring(0, 16);
  return Directory('${(await getTemporaryDirectory()).path}/book-pages/$name');
});

/// Where the app's face [ReadingFace] names is set from, for the engine — see
/// [appFaceFiles]. Kept, since the files it writes are.
final appFaceFilesProvider = FutureProvider.family<FaceFiles?, ReadingFace>(
  (ref, face) async => appFaceFiles(
    face,
    into: Directory(
      '${(await ref.watch(bookDocumentRootProvider.future)).path}/fonts',
    ),
  ),
);

/// Where the files a page names are on the device, as the `file:` address
/// the page is given, by the name the page gave each.
typedef BookPageFiles = Map<String, String>;

/// Fetches every one of [sources] a page names into [into], once each, and
/// answers where each landed.
///
/// A name the page carries the bytes of itself (`data:`) is not fetched — the
/// rewrite keeps it as it is — and a name [onDevice] already holds a file for
/// is copied rather than fetched, which is how a saved copy's font is found
/// with no server to ask. A file that cannot be had is not there, and the rest
/// still are: a page with one broken picture is a page with a hole in it, not
/// a page that fails.
Future<BookPageFiles> fetchBookPageFiles(
  Iterable<String> sources, {
  required Directory into,
  required Future<List<int>> Function(String src) fetch,
  Map<String, File> onDevice = const {},
}) async {
  final wanted = {
    for (final src in sources)
      if (src.trim().isNotEmpty && !src.trim().startsWith('data:')) src,
  };
  if (wanted.isEmpty) return {};
  await into.create(recursive: true);
  final landed = await Future.wait(
    wanted.map((src) async {
      final file = File('${into.path}/${_fileName(src)}');
      try {
        final copy = onDevice[src];
        if (copy != null) {
          await copy.copy(file.path);
        } else {
          await file.writeAsBytes(await fetch(src), flush: true);
        }
        return MapEntry(src, file.uri.toString());
      } on Object {
        return null;
      }
    }),
  );
  return Map.fromEntries(landed.nonNulls);
}

/// A file's name for [src]: the same for the same name, and keeping the
/// extension of what it names — an engine reading a file names its type by
/// it. A whole address's own `file` is what it names, never its query, so a
/// key in the address never reaches a file name.
String _fileName(String src) {
  final named = Uri.tryParse(src.trim());
  final path = named?.queryParameters['file'] ?? named?.path ?? src;
  final extension = RegExp(r'\.([A-Za-z0-9]{1,5})$')
      .firstMatch(path)
      ?.group(1)
      ?.toLowerCase();
  final name = sha1.convert(src.codeUnits).toString().substring(0, 16);
  return extension == null ? name : '$name.$extension';
}

/// Writes the document an engine is given for one page into [file], and
/// answers it: the page through the rewrite pass, with every name it gives a
/// file in [files] pointed at that file and every other one gone.
Future<File> writeBookDocument(
  File file,
  String html, {
  required String? language,
  required BookSetting setting,
  required BookPageFiles files,
  FaceFiles? faceFiles,
}) async {
  await file.parent.create(recursive: true);
  return file.writeAsString(
    rewriteBookPage(
      html,
      language: language,
      setting: setting,
      localFile: (src) => files[src],
      faceFiles: faceFiles,
    ),
    flush: true,
  );
}

/// The assets the app's faces ship in, as `pubspec.yaml` bundles them.
const Map<ReadingFace, FaceFiles> _appFaceAssets = {
  ReadingFace.serif: (
    roman: 'assets/fonts/Literata-Variable.ttf',
    italic: 'assets/fonts/Literata-Italic-Variable.ttf',
  ),
  ReadingFace.sans: (
    roman: 'assets/fonts/AtkinsonHyperlegibleNext-Variable.ttf',
    italic: 'assets/fonts/AtkinsonHyperlegibleNext-Italic-Variable.ttf',
  ),
};

/// Where the face [face] names is set from, written out of the app's own
/// bundle into [into] the first time it is asked for — or null for the book's
/// own face, which is the book's to name.
///
/// The faces are bundled and never fetched (a reader is opened on a train),
/// but an engine has none of them: it reads files, and a bundle is not one.
Future<FaceFiles?> appFaceFiles(
  ReadingFace face, {
  required Directory into,
  AssetBundle? bundle,
}) async {
  final assets = _appFaceAssets[face];
  if (assets == null) return null;
  await into.create(recursive: true);
  Future<String> written(String asset) async {
    final file = File('${into.path}/${asset.split('/').last}');
    if (!file.existsSync()) {
      final bytes = await (bundle ?? rootBundle).load(asset);
      // Written aside and moved into place, so an engine never reads a face
      // half written by a page being set beside it.
      final part = File('${file.path}.part');
      await part.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await part.rename(file.path);
    }
    return file.uri.toString();
  }

  return (
    roman: await written(assets.roman),
    italic: await written(assets.italic),
  );
}
