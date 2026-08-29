import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../auth/session.dart';
import '../../downloads/downloads_provider.dart';
import '../../downloads/image_cache_store.dart';
import '../../format.dart';
import '../../settings/cache_settings.dart';
import '../../settings/reading_settings.dart';
import '../../theme.dart';
import '../../widgets/direction_icon.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final direction = ref.watch(defaultReadingDirectionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        top: false,
        // A settings list is a column, not a canvas: past `contentMaxWidth`
        // the row's label and its value would sit an arm's length apart.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: contentMaxWidth),
            child: ListView(
              padding: const EdgeInsets.only(bottom: sectionGap),
              children: [
                _Section(label: l10n.serverSectionLabel),
                if (session != null)
                  _ServerCard(
                    host: session.host,
                    username: session.username,
                    actionLabel: l10n.switchServer,
                    onTap: () => ref.read(authProvider.notifier).switchServer(),
                  ),

                _Section(label: l10n.readingSectionLabel),
                _SettingRow(
                  icon: DirectionIcon(direction, color: patraAccent),
                  title: l10n.defaultReadingDirection,
                  value: direction.label(l10n),
                  onTap: () => _pickDirection(context, ref, direction),
                ),

                _Section(label: l10n.storageSectionLabel),
                const _StorageRows(),

                _Section(label: l10n.aboutSectionLabel),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: gutter,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Text.rich(
                        TextSpan(
                          text: 'patra',
                          style: PatraText.serifTitle(size: 18),
                          children: [
                            TextSpan(
                              text: '.',
                              style: PatraText.serifTitle(
                                size: 18,
                                color: patraAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // The tagline is a sentence: it wraps here rather than
                      // running off the row.
                      Expanded(
                        child: Text(
                          l10n.appTagline,
                          style: PatraText.metadata(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: sectionGap),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: gutter),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      // Signing out is one short phrase; a button as wide as the
                      // screen reads as a banner rather than as something to press.
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              ref.read(authProvider.notifier).signOut(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: patraDanger,
                            side: BorderSide(
                              color: patraDanger.withValues(alpha: .45),
                            ),
                          ),
                          child: Text(l10n.signOut),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDirection(
    BuildContext context,
    WidgetRef ref,
    ReadingDirection current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<ReadingDirection>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: _SheetColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 6),
              child: SectionLabel(l10n.readingDirection),
            ),
            for (final option in ReadingDirection.values)
              ListTile(
                leading: DirectionIcon(
                  option,
                  color: option == current ? patraAccent : patraText,
                ),
                title: Text(
                  option.label(l10n),
                  style: PatraText.body(
                    color: option == current ? patraAccent : patraText,
                  ),
                ),
                trailing: option == current
                    ? const Icon(Icons.check, color: patraAccent, size: 18)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await ref.read(defaultReadingDirectionProvider.notifier).set(picked);
    }
  }
}

/// What the app is keeping on the device, and the one thing worth clearing.
class _StorageRows extends ConsumerWidget {
  const _StorageRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final downloads = ref.watch(downloadsProvider).value;
    final cacheSize = ref.watch(imageCacheSizeProvider);
    final cacheLimit = ref.watch(imageCacheLimitProvider);

    return Column(
      children: [
        // Saved chapters: shown for context, managed in the Downloads tab.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
          child: Row(
            children: [
              const SizedBox(
                width: 22,
                child: Icon(Icons.download_done, size: 18, color: patraOffline),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.downloadedChapters(downloads?.saved.length ?? 0),
                  style: PatraText.body(),
                ),
              ),
              Text(
                formatBytes(l10n, downloads?.totalBytes ?? 0),
                style: PatraText.metadata(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 22,
                child: Icon(Icons.image_outlined, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.imageCacheLabel,
                            style: PatraText.body(),
                          ),
                        ),
                        Text(
                          formatBytes(l10n, cacheSize.value ?? 0),
                          style: PatraText.metadata(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(l10n.imageCacheCaption, style: PatraText.metadata()),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _pickLimit(context, ref, cacheLimit),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.imageCacheLimit,
                                style: PatraText.body(),
                              ),
                            ),
                            Text(
                              formatBytes(l10n, cacheLimit.bytes),
                              style: PatraText.metadata(color: patraAccent),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      l10n.imageCacheLimitCaption,
                      style: PatraText.metadata(),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () async {
                        await ref.read(imageCacheStoreProvider).clear();
                        ref.invalidate(imageCacheSizeProvider);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(l10n.clearCache),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Picking a smaller budget has to bite right away, not on the next launch.
  Future<void> _pickLimit(
    BuildContext context,
    WidgetRef ref,
    ImageCacheLimit current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<ImageCacheLimit>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: _SheetColumn(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 6),
              child: SectionLabel(l10n.imageCacheLimit),
            ),
            for (final option in ImageCacheLimit.values)
              ListTile(
                title: Text(
                  formatBytes(l10n, option.bytes),
                  style: PatraText.body(
                    color: option == current ? patraAccent : patraText,
                  ),
                ),
                trailing: option == current
                    ? const Icon(Icons.check, color: patraAccent, size: 18)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await ref.read(imageCacheLimitProvider.notifier).set(picked);
    await ref.read(imageCacheStoreProvider).trim(picked.bytes);
    ref.invalidate(imageCacheSizeProvider);
  }
}

/// The rows of a bottom sheet, held to the same column as the screen behind
/// it: a full-width tablet sheet puts its ticks against the far edge.
class _SheetColumn extends StatelessWidget {
  const _SheetColumn({required this.mainAxisSize, required this.children});

  final MainAxisSize mainAxisSize;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: contentMaxWidth),
      child: Column(mainAxisSize: mainAxisSize, children: children),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(gutter, sectionGap, gutter, 8),
      child: SectionLabel(label),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.host,
    required this.username,
    required this.actionLabel,
    required this.onTap,
  });

  final String host;
  final String username;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: gutter),
      child: Material(
        color: patraSurface,
        borderRadius: BorderRadius.circular(radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radiusCard),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radiusCard),
              border: Border.all(color: patraBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: patraOnline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PatraText.rowTitle(),
                      ),
                      const SizedBox(height: 3),
                      Text(username, style: PatraText.metadata()),
                    ],
                  ),
                ),
                Text(
                  actionLabel,
                  style: PatraText.metadata(color: patraAccent),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: minHitTarget),
        padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 22, child: Center(child: icon)),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: PatraText.body())),
            Text(value, style: PatraText.metadata()),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}
