import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../auth/session.dart';
import '../theme.dart';

/// Being offline, told in the app bar rather than in a banner over the
/// content.
///
/// A banner is a paragraph: it pushed the shelves down the screen, repeated
/// the same sentence on three screens at once, and was as loud on the
/// twentieth glance as on the first. Offline is a *status*, so it sits where
/// a status goes — the trailing edge of the bar, opposite the app's own name
/// — and costs the content nothing.
///
/// The sentence is not lost. A struck-through cloud means nothing to someone
/// who has not met it before and nothing at all to a screen reader, so the
/// old banner text is the tooltip *and* what a tap says in full.
class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offline = ref.watch(offlineProvider);

    return AnimatedSwitcher(
      // Long enough not to pop, short enough not to be a thing that animates
      // in a bar; the same 150ms a cover fades in with.
      duration: const Duration(milliseconds: 150),
      child: offline
          ? IconButton(
              // `tooltip` is the semantics label too, which is the whole
              // reason the explanation lives here rather than in a comment.
              tooltip: l10n.offlineBanner,
              icon: const Icon(Icons.cloud_off_outlined, color: patraDanger),
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                // Tapping twice should re-state it, not queue a second one.
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.offlineBanner)),
                );
              },
            )
          : const SizedBox.shrink(),
    );
  }
}
