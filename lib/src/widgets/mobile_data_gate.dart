import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../downloads/network_kind.dart';
import '../settings/mobile_data.dart';
import '../theme.dart';

/// Whether a download a tap asked for may start: yes off mobile data, yes
/// where this device has said not to ask, and otherwise whatever the reader
/// answers. Every control that starts a fetch goes through it — save, retry,
/// resume, refresh and the batches — so none of them can spend a plan
/// without the question having been put.
Future<bool> mayDownload(BuildContext context, WidgetRef ref) async {
  if (!await ref.read(onMobileDataProvider)()) return true;
  final bool allowed;
  try {
    allowed = await ref.read(mobileDataDownloadsProvider.future);
  } on Object {
    return true;
  }
  if (allowed) return true;
  if (!context.mounted) return false;
  final answer = await showDialog<_Answer>(
    context: context,
    builder: (_) => const _MobileDataDialog(),
  );
  if (answer == null) return false;
  if (answer.dontAskAgain) {
    await ref.read(mobileDataDownloadsProvider.notifier).set(true);
  }
  return true;
}

/// A download the reader agreed to, and whether to ask again next time.
typedef _Answer = ({bool dontAskAgain});

class _MobileDataDialog extends StatefulWidget {
  const _MobileDataDialog();

  @override
  State<_MobileDataDialog> createState() => _MobileDataDialogState();
}

class _MobileDataDialogState extends State<_MobileDataDialog> {
  var _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: patraSurface,
      title: Text(l10n.mobileDataTitle, style: PatraText.body()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.mobileDataBody, style: PatraText.metadata()),
          const SizedBox(height: 8),
          // The whole line is the control, as a settings row is.
          InkWell(
            onTap: () => setState(() => _dontAskAgain = !_dontAskAgain),
            child: Row(
              children: [
                Checkbox(
                  value: _dontAskAgain,
                  activeColor: patraOffline,
                  onChanged: (value) =>
                      setState(() => _dontAskAgain = value ?? false),
                ),
                Expanded(
                  child: Text(l10n.mobileDataDontAsk, style: PatraText.body()),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop<_Answer>((dontAskAgain: _dontAskAgain)),
          child: Text(
            l10n.mobileDataDownload,
            style: PatraText.body(color: patraOffline),
          ),
        ),
      ],
    );
  }
}
