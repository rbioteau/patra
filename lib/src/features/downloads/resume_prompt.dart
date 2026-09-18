import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../downloads/downloads_provider.dart';
import '../../theme.dart';

/// The one question a cold start asks.
///
/// A launch is the only moment the app has work of its own waiting and no
/// screen behind it yet: what the previous run was closed in the middle of is
/// still stopped, and going on with it would fire a batch at the server —
/// and at a data plan — before the reader has seen anything. So it is asked
/// once, in words that name how many copies are involved, and not a page is
/// fetched until the answer. A "not now" is an answer too: what was paused
/// stops being resumable and waits for a retry like anything else that
/// stopped with the app.
///
/// It draws nothing of its own — it is mounted around the shell and asks over
/// it — which is why it takes a child rather than being a route of its own.
/// Every other way a queue stops is silent on purpose: coming back to the
/// foreground, or to a profile, resumes it without asking, because both are
/// the reader returning to work they asked for.
class DownloadsResumePrompt extends ConsumerStatefulWidget {
  const DownloadsResumePrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DownloadsResumePrompt> createState() =>
      _DownloadsResumePromptState();
}

class _DownloadsResumePromptState extends ConsumerState<DownloadsResumePrompt> {
  /// Asked once per container. The answer clears the state that raised it, so
  /// this only guards the frame in between — and a handover builds a fresh
  /// state, which is what lets the next profile be asked about its own queue.
  var _asked = false;

  @override
  Widget build(BuildContext context) {
    final waiting = ref.watch(
      downloadsProvider.select(
        (state) => state.value?.awaitingResume.length ?? 0,
      ),
    );
    if (waiting > 0 && !_asked) {
      _asked = true;
      // After the frame: `showDialog` pushes a route, and this build runs
      // inside the router's own.
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask(waiting));
    }
    return widget.child;
  }

  Future<void> _ask(int count) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final downloads = ref.read(downloadsProvider.notifier);
    final resume = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: patraSurface,
        title: Text(l10n.resumeDownloadsTitle, style: PatraText.body()),
        content: Text(
          l10n.resumeDownloadsBody(count),
          style: PatraText.body(color: patraTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.resumeDownloadsLater,
              style: PatraText.body(color: patraTextMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.resumeDownload,
              style: PatraText.body(color: patraOffline),
            ),
          ),
        ],
      ),
    );
    // Dismissed by the barrier is the same answer as "not now": the question
    // was seen, and nothing is fetched without a tap on Resume.
    if (resume ?? false) {
      await downloads.resumeStopped();
    } else {
      await downloads.leaveStopped();
    }
  }
}
