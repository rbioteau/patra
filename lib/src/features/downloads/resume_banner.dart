import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../downloads/downloads_provider.dart';
import '../../theme.dart';

/// The one question a cold start asks, as a strip under the app bar of
/// whatever screen the app opened on.
///
/// A launch is the only moment the app has work of its own waiting and no
/// screen behind it yet: what the previous run was closed in the middle of is
/// still stopped, and going on with it would fire a batch at the server — and
/// at a data plan — before the reader has seen anything. So it is asked once,
/// in words that name how many copies are involved, and not a page is fetched
/// until the answer.
///
/// A **banner and not a dialog**, because nothing here has to be settled
/// before the app can be used: the reader may ignore it, switch tab, open a
/// chapter — the copies stay where they are, listed as paused with the control
/// that sends each one on. It is answered once and gone, which is the whole
/// difference between it and the offline banner this app deliberately does not
/// have: that one was a status, as loud on the twentieth glance as on the
/// first, and this is a question with two worded answers.
///
/// It is **not drawn here**. It is shown through a `ScaffoldMessenger` of its
/// own, wrapped around the shell, and that is what puts it inside the screen's
/// Scaffold rather than the shell's: a nested messenger's root Scaffold is the
/// one the screen built for itself, so the strip lands under the bar naming
/// the screen — an app's own line, not a system notice over the status bar. It
/// is also the whole of the inset handling: that Scaffold has already paid for
/// the notch, and a strip asking for the inset a second time would sit twice
/// as low.
///
/// Every other way a queue stops is silent on purpose: coming back to the
/// foreground, or to a profile, resumes it without asking, because both are
/// the reader returning to work they asked for.
class DownloadsResumeBanner extends ConsumerStatefulWidget {
  const DownloadsResumeBanner({super.key, required this.child});

  /// The shell, which is not where the strip is drawn: see the class comment.
  final Widget child;

  @override
  ConsumerState<DownloadsResumeBanner> createState() =>
      _DownloadsResumeBannerState();
}

class _DownloadsResumeBannerState extends ConsumerState<DownloadsResumeBanner> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  /// Whether the strip is up, which is the state's to say rather than this
  /// widget's memory: the question is already waiting on the first build.
  var _shown = false;

  @override
  Widget build(BuildContext context) {
    final waiting = ref.watch(
      downloadsProvider.select(
        (state) => state.value?.awaitingResume.length ?? 0,
      ),
    );
    // Asked for after the frame: a messenger cannot be handed a banner while
    // the tree that holds it is being built.
    if (waiting > 0 && !_shown) {
      _shown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(waiting));
    } else if (waiting == 0 && _shown) {
      _shown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hide());
    }
    return ScaffoldMessenger(key: _messenger, child: widget.child);
  }

  void _show(int count) {
    final messenger = _messenger.currentState;
    if (!mounted || messenger == null) return;
    final l10n = AppLocalizations.of(context);
    final downloads = ref.read(downloadsProvider.notifier);
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: patraSurface,
        dividerColor: patraBorder,
        leading: const Icon(Icons.download_outlined, color: patraOffline),
        content: Text(l10n.resumeDownloadsBody(count), style: PatraText.body()),
        actions: [
          TextButton(
            onPressed: downloads.leaveStopped,
            child: Text(
              l10n.resumeDownloadsLater,
              style: PatraText.body(color: patraTextMuted),
            ),
          ),
          TextButton(
            onPressed: downloads.resumeStopped,
            child: Text(
              l10n.resumeDownload,
              style: PatraText.body(color: patraOffline),
            ),
          ),
        ],
      ),
    );
  }

  void _hide() => _messenger.currentState?.hideCurrentMaterialBanner();
}
