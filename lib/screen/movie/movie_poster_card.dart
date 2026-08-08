import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';

/// Poster card shared by the browse grid and the "related movies" rail.
///
/// [showOverlays] turns the badge, library state and view/like counters on; the
/// related rail wants the bare poster and title only.
class MoviePosterCard extends StatelessWidget {
  const MoviePosterCard({
    super.key,
    required this.movie,
    required this.onTap,
    this.onLongPress,
    this.isWatched = false,
    this.isFavorite = false,
    this.showOverlays = true,
    this.titleMaxLines = 1,
    this.titleFontSize = 12,
  });

  final Movie movie;

  /// Receives the card's rect on screen so a caller can zoom out of exactly
  /// this card.
  final ValueChanged<Rect> onTap;
  final VoidCallback? onLongPress;
  final bool isWatched;
  final bool isFavorite;
  final bool showOverlays;
  final int titleMaxLines;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayBadge = movie.hasVietsub ? l10n.vietsub : movie.badge;
    final hasCounters = (movie.views?.isNotEmpty ?? false) || (movie.likes?.isNotEmpty ?? false);
    final originalTitle = movie.originalTitle;

    return NeuCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        onTap(box.localToGlobal(Offset.zero) & box.size);
      },
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: movie.poster,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade900,
                    child: const Center(child: Icon(Icons.movie, color: Colors.white24)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade800,
                    child: const Icon(Icons.broken_image_rounded, color: Colors.white38),
                  ),
                ),
                if (showOverlays && displayBadge != null && displayBadge.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.pinkAccent.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        displayBadge,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                if (showOverlays && (isWatched || isFavorite))
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.68), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isWatched) const Icon(Icons.check_circle_rounded, color: Colors.lightGreenAccent, size: 17),
                          if (isWatched && isFavorite) const SizedBox(width: 4),
                          if (isFavorite) const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 17),
                        ],
                      ),
                    ),
                  ),
                if (showOverlays && hasCounters)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (movie.views?.isNotEmpty ?? false) ...[
                            const Icon(Icons.visibility_rounded, size: 11, color: Colors.white70),
                            const SizedBox(width: 3),
                            Text(movie.views!, style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ],
                          if ((movie.views?.isNotEmpty ?? false) && (movie.likes?.isNotEmpty ?? false)) const SizedBox(width: 7),
                          if (movie.likes?.isNotEmpty ?? false) ...[
                            const Icon(Icons.favorite_rounded, size: 11, color: Colors.pinkAccent),
                            const SizedBox(width: 3),
                            Text(movie.likes!, style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  movie.title,
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w600, height: 1.2),
                ),
                if (originalTitle != null && originalTitle.isNotEmpty && originalTitle != movie.title)
                  Text(
                    originalTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleFontSize - 2,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      height: 1.2,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
