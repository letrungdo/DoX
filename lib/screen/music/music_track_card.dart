import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/music_track.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One track in the list: artwork, title, artist, counts and the heart.
///
/// A widget of its own rather than a closure in the list's builder, because
/// the ride into view below needs the row's own [BuildContext]. The builder of
/// a `SliverChildBuilderDelegate` is handed the *sliver's* element, so asking
/// it to be made visible scrolled the whole grid to its edge instead of the
/// row — which is how a row the remote had just reached ended up hidden above
/// the top of the viewport.
class MusicTrackCard extends StatelessWidget {
  const MusicTrackCard({
    super.key,
    required this.track,
    required this.isCurrent,
    required this.isLiked,
    required this.focusNode,
    required this.likeFocusNode,
    required this.onTap,
    required this.onToggleLike,
  });

  final MusicTrack track;
  final bool isCurrent;
  final bool isLiked;

  /// The row itself, which is what the remote walks the list by.
  final FocusNode focusNode;

  /// The heart. Reached from [focusNode] with the right arrow and nowhere
  /// else — see [_onKey].
  final FocusNode likeFocusNode;

  final VoidCallback onTap;
  final VoidCallback onToggleLike;

  static String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isTv = deviceType.isTv;
    return Focus(
      // Not a stop of its own: the row's card is that. This one listens, so
      // the row can ride the list when the remote reaches it, and carries the
      // key handling that joins the row to its heart.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) => _rideIntoView(context, hasFocus),
      onKeyEvent: isTv ? _onKey : null,
      child: NeuCard(
        focusNode: focusNode,
        onTap: onTap,
        color: isCurrent
            ? context.theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
            : null,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox.square(
                dimension: Dimens.musicTrackArtSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      Dimens.radiusControlSmall,
                    ),
                    image: track.artworkUrl.isNotEmpty
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(track.artworkUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: track.artworkUrl.isEmpty
                        ? context.theme.disabledColor.withValues(alpha: 0.2)
                        : null,
                  ),
                  child: track.artworkUrl.isEmpty
                      ? const Icon(Icons.music_note_rounded)
                      : null,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.theme.hintColor,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildCounts(context),
                  ],
                ),
              ),
            ),
            // Shut out of the traversal on a television and reached by hand
            // instead. The heart sits *inside* the row's own rectangle, and
            // directional traversal only ever looks at what is beyond the
            // edge it is moving towards — so an arrow could never land on it,
            // while a row underneath was sometimes answered for by the heart
            // in it. Neither is something the viewer can predict.
            FocusTraversalGroup(
              descendantsAreTraversable: !deviceType.isTv,
              child: IconButton(
                focusNode: likeFocusNode,
                icon: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 20,
                ),
                color: isLiked
                    ? context.theme.colorScheme.error
                    : context.theme.hintColor,
                onPressed: onToggleLike,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildCounts(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.favorite_rounded,
          size: 12,
          color: context.theme.colorScheme.error.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 4),
        Text(
          _formatNumber(track.likesCount),
          style: TextStyle(fontSize: 10, color: context.theme.hintColor),
        ),
        const SizedBox(width: 12),
        Icon(
          Icons.repeat_rounded,
          size: 12,
          color: context.theme.colorScheme.primary.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 4),
        Text(
          _formatNumber(track.repostsCount),
          style: TextStyle(fontSize: 10, color: context.theme.hintColor),
        ),
      ],
    );
  }

  /// Joins the row and its heart into one chain the remote can walk.
  ///
  /// Right off the row lands on the heart; every arrow off the heart hands
  /// the focus back to the row first and then moves from there, so the rest
  /// of the page is reached from the row it belongs to whichever of the two
  /// the remote happened to be on.
  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => TraversalDirection.up,
      LogicalKeyboardKey.arrowDown => TraversalDirection.down,
      LogicalKeyboardKey.arrowLeft => TraversalDirection.left,
      LogicalKeyboardKey.arrowRight => TraversalDirection.right,
      _ => null,
    };
    if (direction == null) return KeyEventResult.ignored;

    final onLike = FocusManager.instance.primaryFocus == likeFocusNode;
    if (!onLike) {
      if (direction != TraversalDirection.right) return KeyEventResult.ignored;
      likeFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    focusNode.requestFocus();
    if (direction == TraversalDirection.left) return KeyEventResult.handled;
    // The row is where the move is measured from, so it has to hold the focus
    // before the move is asked for; the manager applies the request on a
    // microtask, before anything is drawn.
    scheduleMicrotask(() => focusNode.focusInDirection(direction));
    return KeyEventResult.handled;
  }

  /// Parks a row the remote has just reached half way up its viewport, so it
  /// is never left flush against an edge with its focus ring cut off.
  void _rideIntoView(BuildContext context, bool hasFocus) {
    if (!hasFocus || !deviceType.isTv) return;
    unawaited(
      Scrollable.ensureVisible(
        context,
        alignment: Dimens.tvFocusScrollAlignment,
        duration: Dimens.tvFocusScrollDuration,
      ),
    );
  }
}
