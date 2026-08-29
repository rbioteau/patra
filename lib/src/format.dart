import '../l10n/generated/app_localizations.dart';

/// Formats a byte count with the locale's own unit wording.
String formatBytes(AppLocalizations l10n, int bytes) {
  const mb = 1024 * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return l10n.sizeGigabytes((bytes / gb).toStringAsFixed(1));
  if (bytes >= mb) return l10n.sizeMegabytes((bytes / mb).toStringAsFixed(0));
  return l10n.sizeBytes(bytes);
}
