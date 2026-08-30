import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Points path_provider at a temp directory for the duration of a test.
///
/// Widget tests that render covers pull in cached_network_image, whose cache
/// manager asks for the temporary directory; without a handler the channel
/// throws MissingPluginException asynchronously and fails the test at a
/// random moment.
Directory mockPathProvider() {
  final dir = Directory.systemTemp.createTempSync('patra-test');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => dir.path);
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}

/// Backs flutter_secure_storage with a plain map for the duration of a test.
///
/// On a test binding the plugin has no platform behind it: on Linux it reaches
/// for libsecret through the desktop implementation and simply never answers,
/// so a `write` or a `delete` hangs the test rather than failing it. Any test
/// that *sets* a stored preference — rather than only reading one back through
/// a provider override — needs this.
Map<String, String> mockSecureStorage([Map<String, String>? initial]) {
  final values = {...?initial};
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        final key = call.arguments['key'] as String?;
        return switch (call.method) {
          'read' => values[key],
          'readAll' => values,
          'write' => values[key!] = call.arguments['value'] as String,
          'delete' => values.remove(key),
          'deleteAll' => values.clear(),
          'containsKey' => values.containsKey(key),
          _ => null,
        };
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  return values;
}
