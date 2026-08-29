import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/downloads/image_cache_store.dart';

void main() {
  late Directory dir;
  late ImageCacheStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('patra-cache-test');
    store = ImageCacheStore(root: dir);
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// One cached image of [bytes], written [ageInDays] ago.
  File write(String name, int bytes, {required int ageInDays}) {
    final file = File('${dir.path}/$name')
      ..writeAsBytesSync(List.filled(bytes, 0));
    file.setLastModifiedSync(
      DateTime.now().subtract(Duration(days: ageInDays)),
    );
    return file;
  }

  test('a cache under its budget is left alone', () async {
    write('a', 100, ageInDays: 9);
    write('b', 100, ageInDays: 1);

    expect(await store.trim(500), 200);
    expect(dir.listSync().length, 2);
  });

  test('rolls the oldest files out until the cache fits', () async {
    final oldest = write('oldest', 100, ageInDays: 30);
    final older = write('older', 100, ageInDays: 20);
    final recent = write('recent', 100, ageInDays: 1);

    expect(await store.trim(150), 100);
    expect(oldest.existsSync(), isFalse);
    expect(older.existsSync(), isFalse);
    expect(recent.existsSync(), isTrue);
    expect(await store.size(), 100);
  });

  test('stops as soon as the budget is met', () async {
    final oldest = write('oldest', 100, ageInDays: 30);
    final middle = write('middle', 100, ageInDays: 20);
    final recent = write('recent', 100, ageInDays: 1);

    expect(await store.trim(200), 200);
    expect(oldest.existsSync(), isFalse);
    expect(middle.existsSync(), isTrue);
    expect(recent.existsSync(), isTrue);
  });

  test('the sweep is recursive, and directories are not sized', () async {
    Directory('${dir.path}/sub').createSync();
    final nested = write('sub/old', 100, ageInDays: 30);
    final flat = write('recent', 100, ageInDays: 1);

    expect(await store.size(), 200);
    expect(await store.trim(100), 100);
    expect(nested.existsSync(), isFalse);
    expect(flat.existsSync(), isTrue);
  });

  test('a missing cache directory is not an error', () async {
    dir.deleteSync(recursive: true);
    expect(await store.trim(100), 0);
    expect(await store.size(), 0);
  });

  test('trimIfDue sweeps once, then throttles', () async {
    write('oldest', 100, ageInDays: 30);
    write('recent', 100, ageInDays: 1);
    await store.trimIfDue(100);
    expect(await store.size(), 100);

    // The reader asks on every page turn; a second sweep so soon does nothing.
    write('newer', 100, ageInDays: 0);
    await store.trimIfDue(100);
    expect(await store.size(), 200);
  });
}
