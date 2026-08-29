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
