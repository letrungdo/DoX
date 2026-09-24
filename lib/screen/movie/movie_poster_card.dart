import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/movie_model.dart';
import 'package:do_x/screen/movie/movie_player_layout.dart';
import 'package:do_x/services/movie_library_service.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';

/// The pixel width to decode a poster drawn [width] logical pixels wide at.
///
/// A poster arrives at whatever size the server keeps, often several times
/// what a grid cell shows, and decoded at full size a screenful of them holds
/// tens of megabytes. `null` when the width is not known yet, which decodes at
/// full size rather than guessing.
int? posterDecodeWidth(BuildContext context, double width) {
  if (!width.isFinite || width <= 0) return null;
  return (width * MediaQuery.devicePixelRatioOf(context)).round();
}

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
    this.libraryState,
    this.isSelected = false,
    this.showOverlays = true,
    this.titleMaxLines = 1,
    this.titleFontSize = 12,
    this.focusNode,
  });

  final Movie movie;

  /// Lets the grid move the remote back onto this exact card — after the
  /// player overlay closes, say, when the node that held focus has gone with
  /// it. Handed straight down to the [NeuCard]'s press surface.
  final FocusNode? focusNode;

  /// Receives the card's rect on screen so a caller can zoom out of exactly
  /// this card.
  final ValueChanged<Rect> onTap;
  final VoidCallback? onLongPress;
  final bool isWatched;
  final bool isFavorite;
  final MovieLibraryState? libraryState;
  final bool isSelected;
  final bool showOverlays;
  final int titleMaxLines;
  final double titleFontSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayBadge = movie.hasVietsub ? l10n.vietsub : movie.badge;
    final hasCounters =
        (movie.views?.isNotEmpty ?? false) ||
        (movie.likes?.isNotEmpty ?? false);
    final originalTitle = movie.originalTitle;

    final progressSeconds = libraryState?.lastPositionSeconds;
    final progressEpisode = libraryState?.lastEpisodeName;

    return NeuCard(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      depth: isSelected ? 0 : 0.6,
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        onTap(box.localToGlobal(Offset.zero) & box.size);
      },
      onLongPress: onLongPress,
      focusNode: focusNode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => CachedNetworkImage(
                    imageUrl: movie.poster,
                    fit: BoxFit.cover,
                    memCacheWidth: posterDecodeWidth(
                      context,
                      constraints.maxWidth,
                    ),
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: Icon(Icons.movie, color: Colors.white24),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade800,
                      child: const Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
                if (showOverlays &&
                    displayBadge != null &&
                    displayBadge.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.pinkAccent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(Dimens.radiusSmall),
                      ),
                      child: Text(
                        displayBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (showOverlays && (isWatched || isFavorite))
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(Dimens.radiusSmall),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isWatched)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.lightGreenAccent,
                              size: 17,
                            ),
                          if (isWatched && isFavorite) const SizedBox(width: 4),
                          if (isFavorite)
                            const Icon(
                              Icons.favorite_rounded,
                              color: Colors.pinkAccent,
                              size: 17,
                            ),
                        ],
                      ),
                    ),
                  ),
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showOverlays && hasCounters)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(Dimens.radiusSmall),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (movie.views?.isNotEmpty ?? false) ...[
                            const Icon(
                              Icons.visibility_rounded,
                              size: 11,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              movie.views!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if ((movie.views?.isNotEmpty ?? false) &&
                              (movie.likes?.isNotEmpty ?? false))
                            const SizedBox(width: 7),
                          if (movie.likes?.isNotEmpty ?? false) ...[
                            const Icon(
                              Icons.favorite_rounded,
                              size: 11,
                              color: Colors.pinkAccent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              movie.likes!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (showOverlays &&
                    progressSeconds != null &&
                    progressSeconds > 0)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(Dimens.radiusSmall),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            progressEpisode != null
                                ? '$progressEpisode · ${formatDuration(Duration(seconds: progressSeconds))}'
                                : formatDuration(
                                    Duration(seconds: progressSeconds),
                                  ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
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
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (originalTitle != null &&
                    originalTitle.isNotEmpty &&
                    originalTitle != movie.title)
                  Text(
                    originalTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleFontSize - 2,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
