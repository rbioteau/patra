import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../downloads/downloads_provider.dart';
import '../../theme.dart';

/// The one question a cold start asks, as a strip under the app bar of the
/// screen the reader is on — and the screen, under it.
///
/// A launch is the only moment the app has work of its own waiting and no
/// screen behind it yet: what the previous run was closed in the middle of is
/// still stopped, and going on with it would fire a batch at the server — and
/// at a data plan — before the reader has seen anything. So it is asked once,
/// in words that name how many copies are involved, and not a page is fetched
/// until the answer.
///
/// A **strip and not a dialog**, because nothing here has to be settled before
/// the app can be used: the reader may ignore it, switch tab, open a chapter —
/// the copies stay where they are, listed as paused with the control that
/// sends each one on. It is answered once and gone, which is the whole
/// difference between it and the offline banner this app deliberately does not
/// have: that one was a status, as loud on the twentieth glance as on the
/// first, and this is a question with two worded answers.
///
/// It is **placed by each screen** rather than drawn over them by the shell,
/// because only a screen's own Scaffold knows where its app bar ends: the
/// shell's Scaffold has no bar of its own, so a strip drawn there sat above the
/// one naming the screen and under whatever the device keeps in its top inset.
/// Wrapping a screen's body in this is the whole of the wiring; it draws
/// nothing at all while no copy is waiting. A pushed screen — a series, the
/// reader — has neither, and does not need one: the shell is what the reader
/// comes back to.
///
/// Every other way a queue stops is silent on purpose: coming back to the
/// foreground, or to a profile, resumes it without asking, because both are
/// the reader returning to work they asked for.
class DownloadsResumeStrip extends StatelessWidget {
  const DownloadsResumeStrip({super.key, required this.child});

  /// What the strip stands above: the screen's own body, inside the `SafeArea`
  /// its Scaffold already asked for. The strip takes no inset of its own — the
  /// app bar above it has paid for the notch, and a strip padding itself for
  /// the same notch would sit twice as low.
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [_Strip(), Expanded(child: child)],
  );
}

class _Strip extends ConsumerWidget {
  const _Strip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(
      downloadsProvider.select(
        (state) => state.value?.awaitingResume.length ?? 0,
      ),
    );
    if (waiting == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final downloads = ref.read(downloadsProvider.notifier);
    return Container(
      decoration: const BoxDecoration(
        color: patraSurface,
        border: Border(bottom: BorderSide(color: patraBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.download_outlined,
                size: 18,
                color: patraOffline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.resumeDownloadsBody(waiting),
                  style: PatraText.body(),
                ),
              ),
            ],
          ),
          Row(
            // The two answers, at the trailing edge, where every control that
            // belongs to a row in this app sits.
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
        ],
      ),
    );
  }
}