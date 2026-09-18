import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../downloads/downloads_provider.dart';
import '../../theme.dart';

/// The one question a cold start asks, as a strip across the app rather than a
/// wall in the middle of it.
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
/// Every other way a queue stops is silent on purpose: coming back to the
/// foreground, or to a profile, resumes it without asking, because both are
/// the reader returning to work they asked for.
class DownloadsResumeBanner extends ConsumerWidget {
  const DownloadsResumeBanner({super.key, required this.child});

  /// The app the strip sits above — the shell, so the question is asked over
  /// whatever the app opened on rather than inside one tab.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(
      downloadsProvider.select(
        (state) => state.value?.awaitingResume.length ?? 0,
      ),
    );
    // Two children in either case, and the app in the second of them: a strip
    // that comes and goes must not hand the shell below it a new position in
    // the tree, or answering the question would rebuild the screen the reader
    // is on.
    return Column(
      children: [
        waiting == 0 ? const SizedBox.shrink() : _ResumeStrip(count: waiting),
        Expanded(child: child),
      ],
    );
  }
}

class _ResumeStrip extends ConsumerWidget {
  const _ResumeStrip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final downloads = ref.read(downloadsProvider.notifier);
    return MaterialBanner(
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
    );
  }
}
