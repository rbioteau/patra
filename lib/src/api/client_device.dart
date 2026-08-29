import 'package:dio/dio.dart';

import 'client_identity.dart';
import 'kavita_client.dart';
import 'models.dart';

/// Gives this installation a readable name in Kavita's device list.
///
/// Kavita generates the name from the client info it parsed: "Unknown Client
/// on Android" with the User-Agent alone, or "Patra on IOs" once
/// `X-Kavita-Client` puts our name in its browser slot — that one spells the
/// platform from its own enum's description. Renaming is the only part of the
/// record the API lets a client set, so this is where the entry gets the name
/// it should have had.
///
/// Best-effort by design: every failure is swallowed. A server older than
/// 0.9.1 has no such endpoint (404), a read-only account may not rename (403),
/// and a device with no id cannot be found at all — none of which should reach
/// the user, since nothing about reading depends on it.
Future<void> announceDevice(KavitaClient client) async {
  final identity = client.identity;
  if (identity.deviceId.isEmpty) return;
  try {
    final devices = await client.clientDevices();
    final device = renameTarget(devices, identity);
    if (device == null) return;
    await client.renameClientDevice(
      deviceId: device.id,
      name: identity.friendlyName,
    );
  } on DioException {
    // Older server, read-only role, or simply offline.
  }
}

/// The device to rename, or null when there is nothing to do.
///
/// Matching is by `X-Device-Id`: Kavita's own fallback fingerprint hashes
/// client type, platform and device type, so every Patra install on Android
/// would otherwise collide into one entry. A name the user typed in Kavita is
/// left alone — this only replaces a generated one.
ClientDeviceDto? renameTarget(
  List<ClientDeviceDto> devices,
  ClientIdentity identity,
) {
  for (final device in devices) {
    if (device.uiFingerprint != identity.deviceId) continue;
    if (device.friendlyName == identity.friendlyName) return null;
    return ClientIdentity.isGeneratedName(device.friendlyName) ? device : null;
  }
  return null;
}
