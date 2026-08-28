import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../api/models.dart';
import '../../auth/session.dart';

final librariesProvider = FutureProvider.autoDispose<List<LibraryDto>>(
  (ref) => ref.watch(kavitaClientProvider).libraries(),
);

class LibrariesScreen extends ConsumerWidget {
  const LibrariesScreen({super.key});

  static const _typeIcons = {
    0: Icons.menu_book, // Manga
    1: Icons.bolt, // Comic
    2: Icons.book, // Book
    3: Icons.image, // Images
    4: Icons.auto_stories, // Light Novel
    5: Icons.bolt, // ComicVine
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final libraries = ref.watch(librariesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.librariesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n.signOut,
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: libraries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorRetry(
          message: '$e',
          onRetry: () => ref.invalidate(librariesProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(librariesProvider.future),
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final library = items[index];
              return ListTile(
                leading: Icon(_typeIcons[library.type] ?? Icons.folder),
                title: Text(library.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  Uri(
                    path: '/library/${library.id}',
                    queryParameters: {'name': library.name},
                  ).toString(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
