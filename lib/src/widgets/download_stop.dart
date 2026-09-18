import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../downloads/downloads_service.dart';
import '../theme.dart';

/// What a copy that stopped short is: the word for the state it is in, the
/// word for the tap that starts it again, and the one colour and glyph both
/// wear.
///
/// One place, because these copies are drawn on two surfaces — the row's pill
/// on a series screen and the Downloads tab's own row — and two mappings of
/// one fact drift apart. The three states are deliberately not one: a **pause**
/// is the app's own doing and wears the blue every download wears, where a
/// failure and a process that died are named in danger and offered a retry.
class DownloadStop {
  const DownloadStop({
    required this.state,
    required this.action,
    required this.icon,
    required this.color,
  });

  /// What the copy is: Paused, Stopped, or one that could not finish.
  final String state;

  /// What the control beside it does: Resume or Retry.
  final String action;

  final IconData icon;
  final Color color;

  /// Null where nothing stopped: a copy that is on its way, one that is here,
  /// or one nobody asked for.
  static DownloadStop? of(DownloadQueueStatus? status, AppLocalizations l10n) =>
      switch (status) {
        DownloadQueueStatus.paused => DownloadStop(
          state: l10n.downloadsPaused,
          action: l10n.resumeDownload,
          icon: Icons.play_arrow,
          color: patraOffline,
        ),
        DownloadQueueStatus.failed => DownloadStop(
          state: l10n.downloadsFailed,
          action: l10n.retry,
          icon: Icons.refresh,
          color: patraDanger,
        ),
        DownloadQueueStatus.interrupted => DownloadStop(
          state: l10n.downloadsStoppedShort,
          action: l10n.retry,
          icon: Icons.refresh,
          color: patraDanger,
        ),
        _ => null,
      };
}
