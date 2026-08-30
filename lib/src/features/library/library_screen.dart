import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../theme.dart';
import '../../widgets/cover.dart';
import '../../widgets/offline_indicator.dart';

final librariesProvider = FutureProvider.autoDispose<List<LibraryDto>>(
  retry: serverRetry,
  (ref) => ref.watch(kavitaClientProvider).libraries(),
);

/// The type of one library, which decides what its series are made of and what
/// those parts are called. Falls back to manga while the list is in flight —
/// the wording settles as soon as it lands, and no screen has to wait on it.
final libraryTypeProvider = Provider.autoDispose.family<LibraryType, int>((
  ref,
  libraryId,
) {
  final libraries = ref.watch(librariesProvider).value;
  if (libraries == null) return LibraryType.manga;
  for (final library in libraries) {
    if (library.id == libraryId) return library.type;
  }
  return LibraryType.manga;
});

final seriesForLibraryProvider = FutureProvider.autoDispose
    .family<List<SeriesDto>, int>(retry: serverRetry, (ref, libraryId) {
      return ref.watch(kavitaClientProvider).allSeriesForLibrary(libraryId);
    });

/// Which library the Library tab is showing. Null means "the first one",
/// resolved once the library list arrives.
class SelectedLibraryNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int libraryId) => state = libraryId;
}

final selectedLibraryProvider = NotifierProvider<SelectedLibraryNotifier, int?>(
  SelectedLibraryNotifier.new,
);

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final libraries = ref.watch(librariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navLibrary),
        actions: const [OfflineIndicator()],
      ),
      body: SafeArea(
        top: false,
        child: libraries.when(
          loading: () => const _LibraryGridSkeleton(),
          error: (error, _) =>
              _ErrorState(onRetry: () => ref.invalidate(librariesProvider)),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(gutter),
                  child: Text(
                    l10n.homeEmpty,
                    textAlign: TextAlign.center,
                    style: PatraText.body(color: patraTextMuted),
                  ),
                ),
              );
            }
            final selected = ref.watch(selectedLibraryProvider);
            final current = items.any((l) => l.id == selected)
                ? selected!
                : items.first.id;
            return Column(
              children: [
                _LibraryPills(
                  libraries: items,
                  selectedId: current,
                  onSelected: (id) =>
                      ref.read(selectedLibraryProvider.notifier).select(id),
                ),
                Expanded(child: _SeriesGrid(libraryId: current)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LibraryPills extends StatelessWidget {
  const _LibraryPills({
    required this.libraries,
    required this.selectedId,
    required this.onSelected,
  });

  final List<LibraryDto> libraries;
  final int selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: gutter, vertical: 10),
        itemCount: libraries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final library = libraries[index];
          final selected = library.id == selectedId;
          return InkWell(
            onTap: () => onSelected(library.id),
            borderRadius: BorderRadius.circular(radiusPill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? patraAccent.withValues(alpha: .16)
                    : patraSurface,
                borderRadius: BorderRadius.circular(radiusPill),
                border: Border.all(color: selected ? patraAccent : patraBorder),
              ),
              child: Text(
                library.name,
                style: PatraText.rowTitle(
                  color: selected ? patraAccent : patraText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The width a cover is drawn at in the grid, past which the grid takes
/// another column rather than blowing the covers up. Three across on a phone,
/// as the handoff draws it, whatever the phone's width.
const _maxTileWidth = 150.0;
const _gridSpacing = 12.0;

int _gridColumns(double width) {
  final available = width - gutter * 2;
  return ((available + _gridSpacing) / (_maxTileWidth + _gridSpacing))
      .ceil()
      .clamp(3, 10);
}

SliverGridDelegate _gridDelegate(double width) =>
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: _gridColumns(width),
      childAspectRatio: 0.5,
      crossAxisSpacing: _gridSpacing,
      mainAxisSpacing: 18,
    );

class _SeriesGrid extends ConsumerWidget {
  const _SeriesGrid({required this.libraryId});

  final int libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final client = ref.watch(kavitaClientProvider);
    final series = ref.watch(seriesForLibraryProvider(libraryId));

    return series.when(
      loading: () => const _LibraryGridSkeleton(),
      error: (error, _) => _ErrorState(
        onRetry: () => ref.invalidate(seriesForLibraryProvider(libraryId)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              l10n.libraryEmpty,
              style: PatraText.body(color: patraTextMuted),
            ),
          );
        }
        return RefreshIndicator(
          // RefreshIndicator only waits on this future, it never catches it:
          // a pull with the server down would raise an unhandled zone error.
          // The screen already shows the failure through the provider.
          onRefresh: () => ref
              .refresh(seriesForLibraryProvider(libraryId).future)
              .catchError((Object _) => const <SeriesDto>[]),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(gutter, 4, gutter, gutter),
            gridDelegate: _gridDelegate(MediaQuery.sizeOf(context).width),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final s = items[index];
              final progress = s.pages > 0 ? s.pagesRead / s.pages : 0.0;
              return CoverTile(
                url: client.seriesCoverUrl(s.id),
                headers: client.imageHeaders,
                title: s.name,
                serifTitle: true,
                progress: progress,
                read: s.pages > 0 && s.pagesRead >= s.pages,
                onTap: () async {
                  await context.push(
                    Uri(
                      path: '/series/${s.id}',
                      queryParameters: {
                        'name': s.name,
                        'library': '$libraryId',
                      },
                    ).toString(),
                  );
                  // Progress may have changed while reading.
                  ref.invalidate(seriesForLibraryProvider(libraryId));
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _LibraryGridSkeleton extends StatelessWidget {
  const _LibraryGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, gutter),
      gridDelegate: _gridDelegate(MediaQuery.sizeOf(context).width),
      // Three rows of however many columns the grid has, so the wait is shaped
      // like the screen that follows it.
      itemCount: _gridColumns(MediaQuery.sizeOf(context).width) * 3,
      itemBuilder: (context, index) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(
            aspectRatio: coverAspectRatio,
            child: Skeleton(radius: radiusCover),
          ),
          const SizedBox(height: 8),
          const Skeleton(height: 10),
        ],
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final offline = ref.watch(offlineProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.cloud_off_outlined : Icons.error_outline,
              color: patraTextMuted,
            ),
            const SizedBox(height: 12),
            Text(
              offline ? l10n.offlineBanner : l10n.serverUnreachable,
              textAlign: TextAlign.center,
              style: PatraText.body(color: patraTextMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
