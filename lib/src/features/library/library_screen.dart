import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../theme.dart';
import '../../widgets/cover.dart';
import '../../api/connection_failure.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/offline_indicator.dart';

final librariesProvider = FutureProvider.autoDispose<List<Library>>(
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
    .family<List<Series>, int>(retry: serverRetry, (ref, libraryId) {
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
                Expanded(
                  child: _SeriesGrid(
                    libraryId: current,
                    libraryName: items
                        .firstWhere((library) => library.id == current)
                        .name,
                  ),
                ),
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

  final List<Library> libraries;
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
  const _SeriesGrid({required this.libraryId, required this.libraryName});

  final int libraryId;
  final String libraryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(kavitaClientProvider);
    final series = ref.watch(seriesForLibraryProvider(libraryId));

    return series.when(
      loading: () => const _LibraryGridSkeleton(),
      error: (error, _) => _ErrorState(
        onRetry: () => ref.invalidate(seriesForLibraryProvider(libraryId)),
      ),
      data: (items) {
        if (items.isEmpty) {
          // Pullable like the grid it stands in for: after asking for a scan
          // there has to be a way to look again, and a bare Center has none.
          return RefreshIndicator(
            onRefresh: () => ref
                .refresh(seriesForLibraryProvider(libraryId).future)
                .catchError((Object _) => const <Series>[]),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: gutter * 1.6),
              children: [
                const SizedBox(height: 36),
                _EmptyLibrary(libraryId: libraryId, libraryName: libraryName),
              ],
            ),
          );
        }
        return RefreshIndicator(
          // RefreshIndicator only waits on this future, it never catches it:
          // a pull with the server down would raise an unhandled zone error.
          // The screen already shows the failure through the provider.
          onRefresh: () => ref
              .refresh(seriesForLibraryProvider(libraryId).future)
              .catchError((Object _) => const <Series>[]),
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

/// An empty library, and the one thing that can be done about it from here.
///
/// A library is empty because the server has not scanned its files, not
/// because anything is wrong with the app — so the copy points at the server
/// rather than apologising, and names the library so there is no doubt which
/// one is meant.
///
/// The button is offered **only to an admin**. Every way into a scan is
/// behind Kavita's `AdminPolicy` (`RequireRole("Admin")`) — `scan`,
/// `scan-multiple`, `scan-all`, and `scan-folder`, which is
/// `[AllowAnonymous]` but checks the account itself and refuses. A non-admin
/// could earn nothing but a 403 from it, and this app does not draw controls
/// that cannot work: it is the same rule that leaves an EPUB row untappable.
class _EmptyLibrary extends ConsumerStatefulWidget {
  const _EmptyLibrary({required this.libraryId, required this.libraryName});

  final int libraryId;
  final String libraryName;

  @override
  ConsumerState<_EmptyLibrary> createState() => _EmptyLibraryState();
}

class _EmptyLibraryState extends ConsumerState<_EmptyLibrary> {
  bool _scanning = false;

  Future<void> _scan() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final host = ref.read(sessionProvider)?.host ?? '';
    setState(() => _scanning = true);
    try {
      await ref.read(kavitaClientProvider).scanLibrary(widget.libraryId);
      if (!mounted) return;
      // The scan is a background job on the server: it is *requested* here,
      // never finished here, and saying otherwise would be a lie the moment
      // the library is large.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.scanRequested)));
      setState(() => _scanning = false);
      // Last, because it can take this widget out of the tree.
      ref.invalidate(seriesForLibraryProvider(widget.libraryId));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _scanning = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(ConnectionFailure.from(error).message(l10n, host)),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canScan = ref.watch(sessionProvider)?.isAdmin ?? false;

    return Column(
      children: [
        // Dashed: the handoff's mark for a place to fill, the same one the
        // "add a server" slot wears.
        SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: DashedBorderPainter(
              color: patraText.withValues(alpha: .28),
            ),
            child: Icon(
              Icons.dashboard_customize_outlined,
              size: 24,
              color: patraText.withValues(alpha: .45),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.libraryEmpty, style: PatraText.rowTitle(size: 14)),
        const SizedBox(height: 6),
        _EmptyBody(libraryName: widget.libraryName),
        if (canScan) ...[
          const SizedBox(height: 18),
          ConstrainedBox(
            // A button given the width of the screen stops reading as a
            // button — the same 280-cap reasoning as the resume button, at
            // the size the handoff draws this one.
            constraints: const BoxConstraints(maxWidth: 200),
            child: OutlinedButton.icon(
              onPressed: _scanning ? null : _scan,
              style: OutlinedButton.styleFrom(
                foregroundColor: patraAccent,
                side: BorderSide(color: patraAccent.withValues(alpha: .5)),
                minimumSize: const Size.fromHeight(44),
              ),
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: patraAccent,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_scanning ? l10n.scanning : l10n.askServerToScan),
            ),
          ),
        ],
      ],
    );
  }
}

/// The explanation, with the library's own name picked out of it.
///
/// The sentence is one localized string with a placeholder — splitting it in
/// two would put a French sentence together in English word order — so the
/// name has to be located in the result rather than concatenated onto it.
///
/// Located by asking for the sentence with a **sentinel** in the placeholder,
/// not by searching for the name: `indexOf(name)` finds the first look-alike
/// anywhere, so a library called "Patra" emphasised the word the English
/// sentence opens with, and one called "serveur" the wrong noun in French.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.libraryName});

  final String libraryName;

  /// A character no translation will contain and no library can be named.
  static const _marker = '\u0000';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = PatraText.metadata(size: 12).copyWith(height: 1.55);
    final template = l10n.libraryEmptyBody(_marker);
    final at = template.indexOf(_marker);

    return Text.rich(
      at < 0
          ? TextSpan(text: l10n.libraryEmptyBody(libraryName), style: style)
          : TextSpan(
              style: style,
              children: [
                TextSpan(text: template.substring(0, at)),
                TextSpan(
                  text: libraryName,
                  style: style.copyWith(color: patraText.withValues(alpha: .7)),
                ),
                TextSpan(text: template.substring(at + _marker.length)),
              ],
            ),
      textAlign: TextAlign.center,
    );
  }
}
