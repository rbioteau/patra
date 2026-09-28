import '../l10n/generated/app_localizations.dart';

/// Formats a byte count with the locale's own unit wording.
String formatBytes(AppLocalizations l10n, int bytes) {
  const mb = 1024 * 1024;
  const gb = mb * 1024;
  // From 1000 MB on, never "1010 MB": four digits of megabytes read as a
  // number to count rather than a size to glance at.
  if (bytes >= 1000 * mb) {
    return l10n.sizeGigabytes((bytes / gb).toStringAsFixed(1));
  }
  if (bytes >= mb) return l10n.sizeMegabytes((bytes / mb).toStringAsFixed(0));
  return l10n.sizeBytes(bytes);
}
