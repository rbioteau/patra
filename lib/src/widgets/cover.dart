import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/kavita_client.dart';
import '../theme.dart';
import 'cover_placeholder.dart';

/// A 2:3 cover with the reading-progress bar pinned to its bottom edge and an
/// optional read badge in the top-right corner.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    required this.headers,
    required this.seriesId,
    required this.seriesName,
    this.progress = 0,
    this.read = false,
    this.radius = radiusCover,
    this.memCacheWidth,
  });

  final String url;
  final Map<String, String> headers;

  /// The series this cover belongs to, whether the picture itself is the
  /// series', a volume's or a chapter's. Required rather than optional for
  /// the same reason [imageCacheKey] is derived here: what is drawn where
  /// there is no picture is the series, so no call site may leave it out.
  final int seriesId;
  final String seriesName;

  /// 0..1 reading progress; the bar only shows strictly between the two.
  final double progress;
  final bool read;
  final double radius;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    // One drawing for both states, and literally the one object. A tile
    // showing its initial while the cover loads says strictly more than a
    // grey rectangle, and a grid cannot flicker between two placeholders as
    // its covers resolve at different times.
    final placeholder = CoverPlaceholder(
      seriesId: seriesId,
      seriesName: seriesName,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: url,
            // Derived here rather than passed in, so no call site can forget
            // it and quietly give one profile a cache of its own.
            cacheKey: imageCacheKey(url),
            httpHeaders: headers,
            fit: BoxFit.cover,
            memCacheWidth: memCacheWidth,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          ),
        ),
        if (read)
          Positioned(
            top: 4,
            right: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.check, size: 13, color: patraAccent),
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [CoverProgressBar(progress: progress)],
          ),
        ),
      ],
    );
  }
}

/// Cover plus caption, as used by the home shelves and the library grid.
class CoverTile extends StatelessWidget {
  const CoverTile({
    super.key,
    required this.url,
    required this.headers,
    required this.seriesId,
    required this.title,
    required this.onTap,
    this.progress = 0,
    this.read = false,
    this.serifTitle = false,
  });

  final String url;
  final Map<String, String> headers;

  /// The series pictured. Its caption is the series' name, which is also
  /// what the cover falls back to drawing where there is no picture.
  final int seriesId;
  final String title;
  final VoidCallback onTap;
  final double progress;
  final bool read;
  final bool serifTitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusCover),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: coverAspectRatio,
            child: CoverImage(
              url: url,
              headers: headers,
              seriesId: seriesId,
              seriesName: title,
              progress: progress,
              read: read,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: serifTitle
                ? PatraText.serifTitle(size: 14)
                : PatraText.rowTitle(),
          ),
        ],
      ),
    );
  }
}
