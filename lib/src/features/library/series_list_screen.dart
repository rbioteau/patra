import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/models.dart';
import '../../auth/session.dart';

final seriesForLibraryProvider = FutureProvider.autoDispose
    .family<List<SeriesDto>, int>((ref, libraryId) {
      return ref.watch(kavitaClientProvider).allSeriesForLibrary(libraryId);
    });

class SeriesListScreen extends ConsumerWidget {
  const SeriesListScreen({
    super.key,
    required this.libraryId,
    required this.libraryName,
  });

  final int libraryId;
  final String libraryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(kavitaClientProvider);
    final series = ref.watch(seriesForLibraryProvider(libraryId));
    return Scaffold(
      appBar: AppBar(title: Text(libraryName)),
      body: series.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(seriesForLibraryProvider(libraryId).future),
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              childAspectRatio: 0.62,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final s = items[index];
              return _SeriesCard(
                series: s,
                coverUrl: client.seriesCoverUrl(s.id),
                headers: client.imageHeaders,
                onTap: () async {
                  await context.push(
                    Uri(
                      path: '/series/${s.id}',
                      queryParameters: {'name': s.name},
                    ).toString(),
                  );
                  // Progress may have changed while reading.
                  ref.invalidate(seriesForLibraryProvider(libraryId));
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.series,
    required this.coverUrl,
    required this.headers,
    required this.onTap,
  });

  final SeriesDto series;
  final String coverUrl;
  final Map<String, String> headers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = series.pages > 0 ? series.pagesRead / series.pages : 0.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: coverUrl,
                httpHeaders: headers,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (_, _, _) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          ),
          if (progress > 0 && progress < 1)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: LinearProgressIndicator(value: progress, minHeight: 3),
            ),
          const SizedBox(height: 4),
          Text(
            series.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
