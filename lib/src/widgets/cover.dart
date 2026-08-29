import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// A 2:3 cover with the reading-progress bar pinned to its bottom edge and an
/// optional read badge in the top-right corner.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    required this.headers,
    this.progress = 0,
    this.read = false,
    this.radius = radiusCover,
    this.memCacheWidth,
  });

  final String url;
  final Map<String, String> headers;

  /// 0..1 reading progress; the bar only shows strictly between the two.
  final double progress;
  final bool read;
  final double radius;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: url,
            httpHeaders: headers,
            fit: BoxFit.cover,
            memCacheWidth: memCacheWidth,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => const ColoredBox(color: versoSurface),
            errorWidget: (_, _, _) => ColoredBox(
              color: versoSurface,
              child: Icon(
                Icons.menu_book_outlined,
                color: versoTextMuted,
                size: 20,
              ),
            ),
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
                child: Icon(Icons.check, size: 13, color: versoAccent),
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
    required this.title,
    required this.onTap,
    this.progress = 0,
    this.read = false,
    this.serifTitle = false,
  });

  final String url;
  final Map<String, String> headers;
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
                ? VersoText.serifTitle(size: 14)
                : VersoText.rowTitle(),
          ),
        ],
      ),
    );
  }
}
