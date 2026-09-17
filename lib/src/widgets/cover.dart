import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/kavita_client.dart';
import '../theme.dart';
import 'cover_placeholder.dart';

/// A 2:3 cover with the reading-progress bar pinned to its bottom edge.
///
/// Read is not a state of its own here: a finished cover is one whose
/// [progress] has reached 1, and [CoverProgressBar] draws that as a full bar.
/// The check badge this used to pin in the corner is gone — a mark added to
/// artwork is furniture on a grid meant to be scanned, and the bar was
/// already saying the same thing everywhere short of the end.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.url,
    required this.headers,
    required this.seriesId,
    required this.seriesName,
    this.progress = 0,
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

  /// 0..1 reading progress; 1 is a full bar, and read is what that means.
  final double progress;
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
