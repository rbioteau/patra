import 'dart:io';
import 'dart:math';
import 'dart:ui' show PlatformDispatcher;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The platforms Kavita can tell apart, and the token its user-agent parser
/// looks for to do it.
///
/// Kavita greps the raw User-Agent (`BrowserHelper.DetectPlatform`) — it never
/// reads the word "iOS", so an iPhone must say `iPhone` (or `iPad`, `iPod`,
/// `Mac OS`) and an Android device must say `Android`.
enum ClientPlatform {
  android('Android', 'Android'),
  iphone('iPhone', 'iOS'),
  ipad('iPad', 'iOS'),
  macos('Mac OS', 'macOS'),
  windows('Windows', 'Windows'),
  linux('Linux', 'Linux'),
  other('', '');

  const ClientPlatform(this.marker, this.osName);

  /// The token Kavita's parser matches on.
  final String marker;

  /// How the OS is named for humans in the User-Agent — and, not by accident,
  /// the spelling Kavita's `X-Kavita-Client` parser accepts for a platform:
  /// `Enum.TryParse` on the name, then a case-insensitive match on the
  /// enum's Description, which is where `iOS` and `macOS` land.
  final String osName;

  bool get isDesktop =>
      this == ClientPlatform.windows ||
      this == ClientPlatform.macos ||
      this == ClientPlatform.linux;
}

/// The screen, as the device sees it right now.
class ScreenMetrics {
  const ScreenMetrics(this.width, this.height);

  /// Logical pixels, the unit Kavita's own web client reports (CSS pixels),
  /// so one device list does not mix two units.
  final int width;
  final int height;

  bool get isKnown => width > 0 && height > 0;

  String get orientation => width > height ? 'landscape' : 'portrait';

  /// The Material breakpoint, which is also what Kavita's card icons expect
  /// ("Mobile" / "Tablet" / "Desktop").
  bool get isTablet => (width < height ? width : height) >= 600;
}

ScreenMetrics liveScreenMetrics() {
  final view = PlatformDispatcher.instance.implicitView;
  if (view == null) return const ScreenMetrics(0, 0);
  final ratio = view.devicePixelRatio;
  if (ratio <= 0) return const ScreenMetrics(0, 0);
  final size = view.physicalSize / ratio;
  return ScreenMetrics(size.width.round(), size.height.round());
}

/// How this installation introduces itself to a Kavita server.
///
/// Kavita 0.9.1+ registers a `ClientDevice` per user from three request
/// headers, and the device card in its settings is only as full as they are:
///
/// - `X-Device-Id`, an opaque per-install id, is what pins the record to *this*
///   installation.
/// - the User-Agent is where Kavita reads the platform from, and it is the
///   only place the device model survives.
/// - `X-Kavita-Client` is the one that fills the card — app version, screen,
///   device type — and the name Kavita generates, since that name is built
///   from its `browser` field. Nothing else populates any of it.
///
/// The last one is a deliberate compromise: its parser is a regex hard-wired
/// to the web UI's `web-app/…` syntax and stamps *every* client that sends it
/// as a Web App, so Patra wears a "Web App" badge it does not deserve. Kavita
/// has no client type for a third-party app at all, so the alternative is not
/// a truer badge, only an emptier card. A value that fails the regex is worse
/// than none: the fallback still says Web App and drops everything else.
class ClientIdentity {
  const ClientIdentity({
    required this.deviceId,
    this.platform = ClientPlatform.other,
    this.osVersion = '',
    this.deviceModel = '',
    this.deviceName = '',
    this.appVersion = fallbackAppVersion,
    this.screen = liveScreenMetrics,
  });

  /// Used before the real identity has been resolved, and by tests.
  const ClientIdentity.unknown() : this(deviceId: '');

  static const appName = 'Patra';

  /// What to say when the platform will not name the build — which happens in
  /// a unit test, where there is no plugin to answer, and essentially nowhere
  /// else. Deliberately not a copy of the current version: a hardcoded one
  /// drifts silently, and a stale number is a worse answer than an obviously
  /// absent one.
  static const fallbackAppVersion = '0.0.0';

  static const _deviceIdKey = 'clientDeviceId';

  /// Random per-installation UUID. Not a hardware id and not a secret: it
  /// exists so Kavita can tell two of the user's phones apart, since its
  /// fallback fingerprint (client type + platform + device type) hashes every
  /// Patra install on Android to the same value.
  final String deviceId;
  final ClientPlatform platform;
  final String osVersion;

  /// What the maker calls it: `Build.MODEL`, which is a sales code on most
  /// phones ("CPH2663").
  final String deviceModel;

  /// What the *user* calls it — Android's Settings > About > Device name,
  /// iOS's device name, a desktop's computer name. Empty when the platform
  /// will not say (iOS 16+ without the entitlement answers "iPhone", which is
  /// still better than a sales code).
  final String deviceName;

  /// The version of the binary, read from the platform's own record of it at
  /// startup (`versionName` on Android, `CFBundleShortVersionString` on iOS)
  /// rather than compiled in. That record is what `flutter build
  /// --build-name` writes, and CI takes that from the release tag — so the
  /// version the server is told is the version that was shipped, with nothing
  /// in the repository to keep in step with it.
  final String appVersion;

  /// Read per request, not once at startup: the device rotates, and at the
  /// time main() resolves the identity there is no view to measure yet.
  final ScreenMetrics Function() screen;

  /// e.g. `Patra/0.1.0 (Android 15; Pixel 8; Flutter)`,
  /// `Patra/0.1.0 (iPhone; iOS 18.6; iPhone 15 Pro; Flutter)`.
  String get userAgent {
    final environment = <String>[
      // iOS puts its marker first because "iPhone" is not part of the OS name;
      // "Android 15" already carries both.
      if (platform.marker.isNotEmpty && platform.marker != platform.osName)
        platform.marker,
      if (platform.osName.isNotEmpty)
        [platform.osName, osVersion].where((p) => p.isNotEmpty).join(' ')
      else if (osVersion.isNotEmpty)
        osVersion,
      if (deviceModel.isNotEmpty) deviceModel,
      'Flutter',
    ];
    return '$appName/$appVersion (${environment.join('; ')})';
  }

  /// Mobile, Tablet or Desktop — Kavita stores it as free text and picks the
  /// card's icon from it.
  String get deviceType {
    if (platform.isDesktop) return 'Desktop';
    if (platform == ClientPlatform.ipad) return 'Tablet';
    final metrics = screen();
    if (!metrics.isKnown) {
      return platform == ClientPlatform.other ? '' : 'Mobile';
    }
    return metrics.isTablet ? 'Tablet' : 'Mobile';
  }

  /// The header that fills Kavita's device card. Its syntax is not ours to
  /// choose: `ClientInfoMiddleware` matches it with
  /// `web-app/<v> (<browser>/<v>; <platform>; <deviceType>; <w>x<h>; <o>)`
  /// and keeps nothing when the match fails. Patra goes in the browser slot,
  /// which is also the slot Kavita builds the device name from.
  ///
  /// Null until there is a screen to report: a header the regex rejects costs
  /// more than the one we did not send.
  String? get kavitaClientHeader {
    final metrics = screen();
    if (!metrics.isKnown || platform.osName.isEmpty) return null;
    return 'web-app/$appVersion ($appName/$appVersion; ${platform.osName}; '
        '$deviceType; ${metrics.width}x${metrics.height}; '
        '${metrics.orientation})';
  }

  /// The name to give this device in Kavita's device list — the one thing in
  /// the record a client may set.
  ///
  /// The device's own name first, since the card already carries the platform
  /// in its own field and two phones should not read alike. The sales code is
  /// the last resort before naming the platform, because it identifies the
  /// device without naming it.
  String get friendlyName {
    final what = [
      deviceName,
      deviceModel,
      platform.osName,
    ].firstWhere((part) => part.isNotEmpty, orElse: () => 'this device');
    return '$appName on $what';
  }

  /// True while [name] is still a name a machine chose — one of ours, or
  /// Kavita's `<client> on <platform>`, which reads "Patra on IOs" once it
  /// knows our name and spells the platform from its own enum. A name the
  /// user typed in Kavita's UI is theirs and must not be overwritten.
  static bool isGeneratedName(String name) =>
      name.isEmpty ||
      name.startsWith('Unknown Client on ') ||
      name.toLowerCase().startsWith('${appName.toLowerCase()} on ');

  /// Headers to send on every request, authenticated or not. Rebuilt each
  /// time, because the screen part of them moves.
  Map<String, String> get headers => {
    HttpHeaders.userAgentHeader: userAgent,
    if (deviceId.isNotEmpty) 'X-Device-Id': deviceId,
    'X-Kavita-Client': ?kavitaClientHeader,
  };

  /// Reads the device id (creating it on first run) and the device
  /// description. Never throws: an unidentified client still works, it just
  /// shows up in Kavita as one more anonymous device.
  static Future<ClientIdentity> resolve() async {
    final deviceId = await _loadOrCreateDeviceId();
    final appVersion = await _loadAppVersion();
    try {
      return await _describeDevice(deviceId, appVersion);
    } on Exception {
      return ClientIdentity(deviceId: deviceId, appVersion: appVersion);
    } on Error {
      // MissingPluginException aside, device_info_plus can throw on odd
      // platforms; a device description is never worth a crash at startup.
      return ClientIdentity(deviceId: deviceId, appVersion: appVersion);
    }
  }

  /// Never throws, for the same reason [resolve] does not: an unnamed version
  /// is a cosmetic loss in a device card, not a reason to fail at startup.
  static Future<String> _loadAppVersion() async {
    try {
      final version = sanitize((await PackageInfo.fromPlatform()).version);
      if (version.isNotEmpty) return version;
    } on Exception {
      // No plugin (a unit test), or a platform that will not answer.
    } on Error {
      // ignore
    }
    return fallbackAppVersion;
  }

  static Future<ClientIdentity> _describeDevice(
    String deviceId,
    String appVersion,
  ) async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return ClientIdentity(
        deviceId: deviceId,
        appVersion: appVersion,
        platform: ClientPlatform.android,
        osVersion: sanitize(android.version.release),
        deviceModel: sanitize(android.model),
        // Settings > About phone > Device name. Unset below API 25, and the
        // OEM's marketing name until the user edits it.
        deviceName: sanitize(android.name),
      );
    }
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return ClientIdentity(
        deviceId: deviceId,
        appVersion: appVersion,
        platform: ios.model.toLowerCase().contains('ipad')
            ? ClientPlatform.ipad
            : ClientPlatform.iphone,
        osVersion: sanitize(ios.systemVersion),
        // modelName is the marketing name ("iPhone 15 Pro"); utsname.machine
        // ("iPhone16,1") would be right but unreadable in a device list.
        deviceModel: sanitize(ios.modelName),
        deviceName: sanitize(ios.name),
      );
    }
    if (Platform.isMacOS) {
      final mac = await info.macOsInfo;
      return ClientIdentity(
        deviceId: deviceId,
        appVersion: appVersion,
        platform: ClientPlatform.macos,
        osVersion: sanitize(mac.osRelease),
        deviceModel: sanitize(mac.modelName),
        deviceName: sanitize(mac.computerName),
      );
    }
    if (Platform.isLinux) {
      final linux = await info.linuxInfo;
      return ClientIdentity(
        deviceId: deviceId,
        appVersion: appVersion,
        platform: ClientPlatform.linux,
        osVersion: sanitize(linux.versionId ?? ''),
        deviceModel: sanitize(linux.name),
        deviceName: sanitize(Platform.localHostname),
      );
    }
    if (Platform.isWindows) {
      final windows = await info.windowsInfo;
      return ClientIdentity(
        deviceId: deviceId,
        appVersion: appVersion,
        platform: ClientPlatform.windows,
        osVersion: sanitize(windows.displayVersion),
        deviceModel: sanitize(windows.productName),
        deviceName: sanitize(windows.computerName),
      );
    }
    return ClientIdentity(deviceId: deviceId, appVersion: appVersion);
  }

  /// Header values travel as latin-1 and cannot carry the parentheses and
  /// semicolons the User-Agent uses as syntax; a device model is whatever the
  /// manufacturer typed, so it is stripped down to plain ASCII words.
  static String sanitize(String value) => value
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
      .replaceAll(RegExp(r'[();]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static Future<String> _loadOrCreateDeviceId() async {
    const storage = FlutterSecureStorage();
    try {
      final stored = await storage.read(key: _deviceIdKey);
      if (stored != null && stored.isNotEmpty) return stored;
      final created = _uuidV4();
      await storage.write(key: _deviceIdKey, value: created);
      return created;
    } on Exception {
      // An unreadable keystore only costs the server its stable device
      // matching, not the session.
      return '';
    }
  }

  /// A random UUID v4. Hand-rolled: one identifier is not worth a dependency.
  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
