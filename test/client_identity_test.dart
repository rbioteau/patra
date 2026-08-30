import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patra/src/api/client_device.dart';
import 'package:patra/src/api/client_identity.dart';
import 'package:patra/src/api/kavita_client.dart';
import 'package:patra/src/api/models.dart';

ScreenMetrics _phone() => const ScreenMetrics(412, 915);
ScreenMetrics _landscape() => const ScreenMetrics(915, 412);
ScreenMetrics _tablet() => const ScreenMetrics(834, 1194);
ScreenMetrics _noScreen() => const ScreenMetrics(0, 0);

// A version no release will ever carry, because it is a fixture: what the app
// reports is read off the binary at startup, so nothing in this repository —
// these expectations included — should look like the real one.
const _android = ClientIdentity(
  deviceId: 'device-uuid',
  appVersion: '1.2.3',
  platform: ClientPlatform.android,
  osVersion: '15',
  deviceModel: 'CPH2663',
  deviceName: 'Nord 4',
  screen: _phone,
);

ClientDeviceDto _device({
  int id = 42,
  String name = 'Unknown Client on Android',
  String fingerprint = 'device-uuid',
}) => ClientDeviceDto(id: id, friendlyName: name, uiFingerprint: fingerprint);

void main() {
  group('user agent', () {
    test('names the app, then the platform token Kavita greps for', () {
      expect(_android.userAgent, 'Patra/1.2.3 (Android 15; CPH2663; Flutter)');
    });

    test('says iPhone on iOS, because Kavita does not look for "iOS"', () {
      const identity = ClientIdentity(
        deviceId: 'device-uuid',
        appVersion: '1.2.3',
        platform: ClientPlatform.iphone,
        osVersion: '18.6',
        deviceModel: 'iPhone 15 Pro',
      );
      expect(
        identity.userAgent,
        'Patra/1.2.3 (iPhone; iOS 18.6; iPhone 15 Pro; Flutter)',
      );
      expect(identity.userAgent.toLowerCase(), contains('iphone'));
    });

    test('drops the parts it could not resolve', () {
      const identity = ClientIdentity(
        deviceId: 'device-uuid',
        appVersion: '1.2.3',
        platform: ClientPlatform.android,
        screen: _phone,
      );
      expect(identity.userAgent, 'Patra/1.2.3 (Android; Flutter)');
    });

    test('says 0.0.0 rather than a stale number when the build is unnamed', () {
      // PackageInfo answers on a device and not in a test, so the fallback is
      // what an unconfigured identity carries. It must not be a copy of the
      // current version: a hardcoded number is the thing that drifts, and
      // moving it off the const is the whole point of reading the binary.
      expect(ClientIdentity.fallbackAppVersion, '0.0.0');
      expect(
        const ClientIdentity.unknown().userAgent,
        'Patra/0.0.0 (Flutter)',
      );
    });

    test('a device model cannot break the header or its syntax', () {
      // Header values travel as latin-1, and ; ( ) are the User-Agent's own
      // punctuation.
      expect(ClientIdentity.sanitize('Xiaomi (Redmi); 手機'), 'Xiaomi Redmi');
    });
  });

  group('headers', () {
    test('carry the user agent and the device id', () {
      expect(_android.headers[HttpHeaders.userAgentHeader], _android.userAgent);
      expect(_android.headers['X-Device-Id'], 'device-uuid');
    });

    test('omit an empty device id rather than send a blank one', () {
      expect(
        const ClientIdentity.unknown().headers.containsKey('X-Device-Id'),
        isFalse,
      );
    });
  });

  group('the header that fills the device card', () {
    test('follows the only syntax Kavita parses', () {
      // web-app/<v> (<browser>/<v>; <platform>; <deviceType>; <w>x<h>; <o>)
      expect(
        _android.kavitaClientHeader,
        'web-app/1.2.3 (Patra/1.2.3; Android; Mobile; 412x915; portrait)',
      );
    });

    test('spells the platform the way Kavita parses it back', () {
      // "iOS" and "macOS" only match the enum's Description, not its name.
      const identity = ClientIdentity(
        deviceId: 'device-uuid',
        platform: ClientPlatform.iphone,
        screen: _phone,
      );
      expect(identity.kavitaClientHeader, contains('; iOS; '));
    });

    test('calls a big screen a tablet, which picks the card icon', () {
      const identity = ClientIdentity(
        deviceId: 'device-uuid',
        platform: ClientPlatform.android,
        screen: _tablet,
      );
      expect(identity.kavitaClientHeader, contains('; Tablet; 834x1194; '));
      expect(identity.kavitaClientHeader, contains('portrait'));
    });

    test('turns with the device', () {
      const identity = ClientIdentity(
        deviceId: 'device-uuid',
        platform: ClientPlatform.android,
        screen: _landscape,
      );
      expect(identity.kavitaClientHeader, contains('915x412; landscape'));
    });

    test('is left out entirely while there is no screen to report', () {
      // A header the regex rejects is worse than none: Kavita's fallback
      // still stamps Web App and drops everything else.
      const identity = ClientIdentity(
        deviceId: 'device-uuid',
        platform: ClientPlatform.android,
        screen: _noScreen,
      );
      expect(identity.kavitaClientHeader, isNull);
      expect(identity.headers.containsKey('X-Kavita-Client'), isFalse);
    });
  });

  group('friendly name', () {
    test('is the name the device carries, not its sales code', () {
      // Build.MODEL is "CPH2663" on this phone; the name its owner sees in
      // Settings is "Nord 4". The card names the platform in its own field,
      // so the name is free to identify the device itself.
      expect(_android.friendlyName, 'Patra on Nord 4');
      expect(_android.userAgent, contains('CPH2663'));
    });

    test('falls back to the model, then to the platform', () {
      const unnamed = ClientIdentity(
        deviceId: 'device-uuid',
        platform: ClientPlatform.android,
        deviceModel: 'CPH2663',
        screen: _phone,
      );
      expect(unnamed.friendlyName, 'Patra on CPH2663');
      expect(
        const ClientIdentity(
          deviceId: 'device-uuid',
          platform: ClientPlatform.android,
          screen: _phone,
        ).friendlyName,
        'Patra on Android',
      );
    });

    test('spells iOS properly, unlike the name Kavita would generate', () {
      const identity = ClientIdentity(
        deviceId: 'device-uuid',
        platform: ClientPlatform.iphone,
        screen: _phone,
      );
      expect(identity.friendlyName, 'Patra on iOS');
    });
  });

  group('rename target', () {
    test('is the device matching our own device id', () {
      final devices = [
        _device(id: 1, fingerprint: 'someone-else'),
        _device(id: 2),
      ];
      expect(renameTarget(devices, _android)?.id, 2);
    });

    test('is nothing when the server does not know this device id', () {
      expect(renameTarget([_device(fingerprint: 'other')], _android), isNull);
    });

    test('is nothing when the name is already right', () {
      expect(
        renameTarget([_device(name: 'Patra on Nord 4')], _android),
        isNull,
      );
    });

    test('replaces the name Kavita generates from our own browser slot', () {
      // With X-Kavita-Client set, Kavita names the device itself — spelling
      // the platform from its enum description: "Patra on IOs".
      const identity = ClientIdentity(
        deviceId: 'device-uuid',
        platform: ClientPlatform.iphone,
        screen: _phone,
      );
      expect(renameTarget([_device(name: 'Patra on IOs')], identity)?.id, 42);
    });

    test('leaves a name the user typed alone', () {
      expect(renameTarget([_device(name: 'Mon telephone')], _android), isNull);
    });

    test('replaces a stale name this app generated', () {
      // The entry follows the device id, so it survives a change of platform
      // name or of app naming scheme.
      expect(
        renameTarget([_device(name: 'Patra on Pixel 6')], _android)?.id,
        42,
      );
    });
  });

  group('announcing the device', () {
    test('renames the entry Kavita generated for this install', () async {
      final adapter = _DeviceAdapter(name: 'Unknown Client on Android');
      await announceDevice(_clientWith(_android, adapter));

      expect(adapter.renamed, {'deviceId': 42, 'name': 'Patra on Nord 4'});
    });

    test('says nothing when the name is already ours', () async {
      final adapter = _DeviceAdapter(name: 'Patra on Nord 4');
      await announceDevice(_clientWith(_android, adapter));

      expect(adapter.renamed, isNull);
    });

    test('a server too old to know the endpoint is not an error', () async {
      // Client devices only exist since Kavita 0.9.1; naming one is cosmetic.
      final adapter = _DeviceAdapter(status: 404);
      await announceDevice(_clientWith(_android, adapter));

      expect(adapter.renamed, isNull);
    });

    test('a client with no device id does not even ask', () async {
      final adapter = _DeviceAdapter(name: 'Unknown Client on Android');
      await announceDevice(
        _clientWith(const ClientIdentity.unknown(), adapter),
      );

      expect(adapter.listed, isFalse);
    });
  });
}

KavitaClient _clientWith(ClientIdentity identity, _DeviceAdapter adapter) {
  final client = KavitaClient(
    baseUrl: 'http://kavita.test',
    token: 'token',
    refreshToken: 'refresh',
    apiKey: 'key',
    identity: identity,
  );
  client.httpClient.httpClientAdapter = adapter;
  client.refreshHttpClient.httpClientAdapter = adapter;
  return client;
}

/// A Kavita that knows one device, ours, and records any rename.
class _DeviceAdapter implements HttpClientAdapter {
  _DeviceAdapter({this.name = '', this.status = 200});

  final String name;
  final int status;

  bool listed = false;
  Map<String, dynamic>? renamed;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/api/Device/client/devices') {
      listed = true;
      if (status != 200) return ResponseBody.fromString('', status);
      return ResponseBody.fromString(
        jsonEncode([
          {'id': 42, 'friendlyName': name, 'uiFingerprint': 'device-uuid'},
        ]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.path == '/api/Device/client/update-name') {
      renamed = options.data as Map<String, dynamic>;
      return ResponseBody.fromString('', 200);
    }
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}
