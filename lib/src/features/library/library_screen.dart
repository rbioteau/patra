import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/models.dart';
import '../../auth/session.dart';
import '../../catalogue/catalogue_reads.dart' as catalogue;
import '../../routes.dart';
import '../../theme.dart';
import '../../widgets/cover.dart';
import '../../api/connection_failure.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/offline_indicator.dart';

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

/// The library the tab is actually showing, or null when there is no such
/// thing yet.
///
/// The selected one while it is still in the list, and otherwise the first —
/// one definition, because the grid and the app bar's scan menu have to mean
/// the same library and a control acting on "the current one" would be
/// meaningless if they could disagree. Null while the list is in flight, has
/// failed, or came back empty, which is the same reason: there is no current
/// library to act on.
final currentLibraryProvider = Provider.autoDispose<int?>((ref) {
  final libraries = ref.watch(catalogue.libraries.provider).value;
  if (libraries == null || libraries.isEmpty) return null;
  final selected = ref.watch(selectedLibraryProvider);
  return libraries.any((library) => library.id == selected)
      ? selected!
      : libraries.first.id;
});

/// Whether the profile being read as may ask for a scan at all.
///
/// The Administrator role and nothing else: every way into a scan is behind
/// Kavita's `AdminPolicy`, so for anybody else the control could earn nothing
/// but a 403 — and this app does not draw one that cannot work. One question,
/// asked by the app bar menu and by the empty state alike, because they are
/// the same rule and would be the same bug if they drifted.
final canScanProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider)?.isAdmin ?? false,
);

/// What the scan control is called right now.
///
/// One wording, because the menu item and the empty state's button are two
/// entry points to one action and a reader who opens the menu while the
/// button is spinning compares them directly.
String _scanLabel(AppLocalizations l10n, {required bool scanning}) =>
    scanning ? l10n.scanning : l10n.askServerToScan;

/// What came of asking for a scan: whether the server was asked at all, and
/// what came back if it was.
///
/// Two facts rather than a nullable failure, because "nothing went wrong" and
/// "nothing was asked" are not the same thing to say. A second call arriving
/// while the first is still in flight must not confirm a request the server
/// never saw, nor refresh a grid on its behalf — which is exactly what a bare
/// null would have done.
class ScanOutcome {
  const ScanOutcome._(this.asked, this.failure);

  /// The server was asked and took it. The scan happens afterwards.
  const ScanOutcome.requested() : this._(true, null);

  /// The server was asked and something came back instead.
  const ScanOutcome.failed(ConnectionFailure failure) : this._(true, failure);

  /// A scan of this library was already in flight, so nothing was sent.
  ///
  /// Unreachable while both controls disable themselves, which is what makes
  /// this the guard and not the path.
  const ScanOutcome.alreadyRunning() : this._(false, null);

  /// Whether the request went out at all.
  final bool asked;

  /// What came back instead, or null where nothing went wrong — which is not
  /// the same as nothing having been [asked].
  final ConnectionFailure? failure;
}

/// Asking the server to scan one library, and whether it is already being
/// asked.
///
/// A [Notifier] rather than a widget's `setState` because there are two ways
/// in — the app bar menu and the empty state's own button — and they must
/// never disagree about whether a scan is running: one flag, keyed by
/// library, so a scan asked for from either place disables both.
///
/// It reports the failure rather than wording it. Both callers word it the
/// same way through [_askForScan]; what a notifier cannot reach is a
/// `BuildContext`, and what it must not do is grow a second copy of the
/// message.
class LibraryScanNotifier extends Notifier<bool> {
  LibraryScanNotifier(this.libraryId);

  final int libraryId;

  @override
  bool build() => false;

  /// Requests a scan, and says which of the three things happened.
  ///
  /// A **403** clears [Profile.isAdmin] on the way out: the server has just
  /// said, fresher than the flag the last sign-in left, that this profile is
  /// not an administrator — so the controls it draws stop being drawn until a
  /// sign-in says otherwise, which is the same principle already applied to a
  /// refused key.
  Future<ScanOutcome> scan() async {
    if (state) return const ScanOutcome.alreadyRunning();
    state = true;
    try {
      await ref.read(kavitaClientProvider).scanLibrary(libraryId);
      return const ScanOutcome.requested();
    } on Object catch (error) {
      final failure = ConnectionFailure.from(error);
      if (failure.kind == ConnectionFailureKind.forbidden) {
        await ref.read(authProvider.notifier).clearAdmin();
      }
      return ScanOutcome.failed(failure);
    } finally {
      state = false;
    }
  }
}

/// Deliberately **not** `autoDispose`: an in-flight scan must not be
/// forgotten because nothing happened to watch it for a frame — which is what
/// the empty state leaving the tree as a grid fills would do. What is kept is
/// one bool per library, for the life of the session.
final libraryScanProvider =
    NotifierProvider.family<LibraryScanNotifier, bool, int>(
      LibraryScanNotifier.new,
    );

/// Asks for a scan and says what came of it — the one place either entry
/// point words the answer, so the two can never word it differently.
///
/// [refreshGrid] is the deliberate asymmetry between them. The empty state
/// has nothing on screen to lose and every reason to look again; from the
/// menu an invalidate would drop a populated grid to its skeleton for a
/// background job that has not produced anything yet, and the confirmation
/// already says to pull down.
Future<void> _askForScan(
  BuildContext context,
  WidgetRef ref,
  int libraryId, {
  required bool refreshGrid,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final host = ref.read(sessionProvider)?.host ?? '';

  final outcome = await ref
      .read(libraryScanProvider(libraryId).notifier)
      .scan();
  // Nothing was sent, so there is nothing to confirm and nothing to refresh.
  if (!outcome.asked || !context.mounted) return;

  final failure = outcome.failure;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          // The scan is a background job on the server: it is *requested*
          // here, never finished here, and saying otherwise would be a lie
          // the moment the library is large.
          failure == null ? l10n.scanRequested : failure.message(l10n, host),
        ),
      ),
    );

  // Last, because it can take the widget that asked out of the tree.
  if (refreshGrid && failure == null) {
    ref.invalidate(catalogue.seriesForLibrary(libraryId).invalidatable);
  }
}

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final libraries = ref.watch(catalogue.libraries.provider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navLibrary),
        actions: const [OfflineIndicator(), _ScanMenu()],
      ),
      body: SafeArea(
        top: false,
        child: libraries.when(
          loading: () => const _LibraryGridSkeleton(),
          error: (error, _) => _ErrorState(
            onRetry: () => ref.invalidate(catalogue.libraries.invalidatable),
          ),
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
            // Non-null here: the list has arrived with something in it, which
            // is the whole of what makes a current library exist.
            final current = ref.watch(currentLibraryProvider)!;
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

/// The one thing an administrator can do to the library they are looking at,
/// wherever it is in the app that they are looking at it.
///
/// A **menu** rather than a button, and its one item **worded** rather than
/// drawn: a refresh glyph in this app bar would be taken for the pull-to-
/// refresh already on the screen below, which does something else entirely —
/// pulling asks Kavita what it already knows, a scan is what changes the
/// answer.
///
/// Drawn only for an administrator, because every way into a scan is behind
/// Kavita's `AdminPolicy` and a non-admin could earn nothing from it but a
/// 403 — the same rule that leaves an EPUB row untappable. And only once a
/// library is selected, because a menu whose one item acts on "the current
/// library" says nothing while the list is still in flight or has failed.
class _ScanMenu extends ConsumerWidget {
  const _ScanMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final libraryId = ref.watch(currentLibraryProvider);
    if (!ref.watch(canScanProvider) || libraryId == null) {
      return const SizedBox.shrink();
    }

    // Offline **disables** the item and says why, rather than hiding it: an
    // item that vanished would read as the role having gone, which is the one
    // thing it must not be confused with. Gated on the flag rather than on a
    // health probe because being wrong here is self-correcting — the request
    // fails, `ConnectionFailure` words it — and it keeps the item honest with
    // the indicator beside it.
    final offline = ref.watch(offlineProvider);
    final scanning = ref.watch(libraryScanProvider(libraryId));

    return PopupMenuButton<_LibraryAction>(
      tooltip: l10n.libraryActions,
      // Never called for a disabled item, so the two guards below are the
      // whole of what stops a second request.
      onSelected: (_) =>
          _askForScan(context, ref, libraryId, refreshGrid: false),
      itemBuilder: (_) => [
        PopupMenuItem<_LibraryAction>(
          value: _LibraryAction.scan,
          enabled: !offline && !scanning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // While a scan is running the label is its own reason; offline
              // it is not, so the reason goes underneath.
              Text(_scanLabel(l10n, scanning: scanning)),
              if (offline && !scanning) ...[
                const SizedBox(height: 2),
                Text(l10n.scanNeedsServer, style: PatraText.metadata(size: 11)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// What the Library tab's menu can do.
///
/// One value, and it exists because `PopupMenuButton` reads a null result as
/// a dismissal: a non-null value is the only way `onSelected` can tell a
/// choice from a tap outside the menu. `scan-all` would be the second.
enum _LibraryAction { scan }

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
    final series = ref.watch(catalogue.seriesForLibrary(libraryId).provider);

    return series.when(
      loading: () => const _LibraryGridSkeleton(),
      error: (error, _) => _ErrorState(
        onRetry: () =>
            ref.invalidate(catalogue.seriesForLibrary(libraryId).invalidatable),
      ),
      data: (items) {
        if (items.isEmpty) {
          // Pullable like the grid it stands in for: after asking for a scan
          // there has to be a way to look again, and a bare Center has none.
          return RefreshIndicator(
            onRefresh: () => ref
                .refresh(catalogue.seriesForLibrary(libraryId).refreshable)
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
              .refresh(catalogue.seriesForLibrary(libraryId).refreshable)
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
                seriesId: s.id,
                title: s.name,
                serifTitle: true,
                progress: progress,
                read: s.isRead,
                onTap: () async {
                  await context.push(seriesLocation(s));
                  // Progress may have changed while reading.
                  ref.invalidate(
                    catalogue.seriesForLibrary(libraryId).invalidatable,
                  );
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
///
/// It keeps its own button now that the app bar carries a scan menu too,
/// because the two do different jobs: this one explains why there is nothing
/// and offers the fix in place, the menu is for a library whose contents have
/// gone stale. Two entry points to one action — the action itself lives in
/// [LibraryScanNotifier], so neither can be running a scan the other does not
/// know about.
class _EmptyLibrary extends ConsumerWidget {
  const _EmptyLibrary({required this.libraryId, required this.libraryName});

  final int libraryId;
  final String libraryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canScan = ref.watch(canScanProvider);
    final scanning = ref.watch(libraryScanProvider(libraryId));

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
        _EmptyBody(libraryName: libraryName, canScan: canScan),
        if (canScan) ...[
          const SizedBox(height: 18),
          ConstrainedBox(
            // A button given the width of the screen stops reading as a
            // button — the same 280-cap reasoning as the resume button, at
            // the size the handoff draws this one.
            constraints: const BoxConstraints(maxWidth: 200),
            child: OutlinedButton.icon(
              onPressed: scanning
                  ? null
                  : () =>
                        _askForScan(context, ref, libraryId, refreshGrid: true),
              style: OutlinedButton.styleFrom(
                foregroundColor: patraAccent,
                side: BorderSide(color: patraAccent.withValues(alpha: .5)),
                minimumSize: const Size.fromHeight(44),
              ),
              icon: scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: patraAccent,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_scanLabel(l10n, scanning: scanning)),
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
///
/// The sentence itself depends on the role, and that is not a nicety: the
/// non-admin's ends by sending them to Kavita, which for them is still the
/// only route to a scan, while telling an administrator to go to Kavita for
/// something there is a button for two lines below would be wrong. Two
/// strings rather than one with a clause, because a translation has to be
/// free to reshape the whole sentence.
class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.libraryName, required this.canScan});

  final String libraryName;

  /// Whether this profile can ask for the scan itself.
  final bool canScan;

  /// A character no translation will contain and no library can be named.
  static const _marker = '\u0000';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = PatraText.metadata(size: 12).copyWith(height: 1.55);
    String body(String library) => canScan
        ? l10n.libraryEmptyBodyAdmin(library)
        : l10n.libraryEmptyBody(library);
    final template = body(_marker);
    final at = template.indexOf(_marker);

    return Text.rich(
      at < 0
          ? TextSpan(text: body(libraryName), style: style)
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
