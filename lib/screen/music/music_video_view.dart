import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The current track's video, in its own shape, on black.
///
/// Carries a small badge when the sound is the video's own, so a song that
/// suddenly sounds different is explained rather than mistaken for a fault.
class MusicVideoView extends StatelessWidget {
  const MusicVideoView({
    super.key,
    required this.controller,
    required this.isOfficialAudio,
    required this.borderRadius,
  });

  final VideoPlayerController controller;
  final bool isOfficialAudio;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = controller.value.aspectRatio;
    final picture = ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(controller),
          if (isOfficialAudio)
            Positioned(
              left: Dimens.musicVideoBadgeInset,
              bottom: Dimens.musicVideoBadgeInset,
              child: _OfficialAudioBadge(
                label: context.l10n.musicVideoOfficialAudio,
              ),
            ),
        ],
      ),
    );
    return AspectRatio(
      aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
      // Square corners need no clip, and a clip over the picture is paid for
      // on every frame — full screen, the one place that has them.
      child: borderRadius == BorderRadius.zero
          ? picture
          : ClipRRect(borderRadius: borderRadius, child: picture),
    );
  }
}

/// The video filling whatever box it is given, cropped rather than
/// letterboxed: the small picture in the phone's player, and the picture on
/// its way between there and the whole screen.
class MusicVideoFill extends StatelessWidget {
  const MusicVideoFill({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    return ColoredBox(
      color: Colors.black,
      child: size.isEmpty
          ? const SizedBox.expand()
          : FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(controller),
              ),
            ),
    );
  }
}

/// The video where the phone's player shows the artwork, in the shape of
/// the screen it opens onto. A tap opens it full screen.
class MusicVideoThumbnail extends StatelessWidget {
  const MusicVideoThumbnail({
    super.key,
    required this.controller,
    required this.onTap,
    this.hidden = false,
  });

  final VideoPlayerController controller;
  final VoidCallback onTap;

  /// Leaves the spot dark: the picture is on its way to or from the whole
  /// screen, drawn above the page, and one of it is enough.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.musicVideoFullscreen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
          child: SizedBox(
            width: Dimens.musicMiniVideoHeight * Dimens.musicMiniVideoAspect,
            height: Dimens.musicMiniVideoHeight,
            child: hidden
                ? const ColoredBox(color: Colors.black)
                : MusicVideoFill(controller: controller),
          ),
        ),
      ),
    );
  }
}

class _OfficialAudioBadge extends StatelessWidget {
  const _OfficialAudioBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            const Icon(Icons.verified_rounded, size: 12, color: Colors.white),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// The quality a picture of [size] is known by — "360p", "720p HD" — or an
/// empty string before the player knows its size.
///
/// Read off the width as well as the height, the way YouTube names its
/// streams: a letterboxed 1280×536 is its 720p, not a 536p.
String musicVideoQualityLabel(Size size) {
  if (size.isEmpty) return '';
  final long = max(size.width, size.height);
  final short = min(size.width, size.height);
  final lines = max(short, long * 9 / 16);
  const tiers = [144, 240, 360, 480, 720, 1080, 1440, 2160];
  final tier = tiers.firstWhere(
    (t) => t >= lines * 0.9,
    orElse: () => tiers.last,
  );
  return tier >= 720 ? '${tier}p HD' : '${tier}p';
}

/// The track's artwork in a square of [size], or a note where it has none:
/// what the phone's player and the full screen show in place of a video.
class MusicArtwork extends StatelessWidget {
  const MusicArtwork({super.key, required this.url, this.size});

  final String url;

  /// Null to fill the box it is given.
  final double? size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: url.isNotEmpty
          ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
          : ColoredBox(
              color: Colors.black,
              child: FittedBox(
                child: Icon(
                  Icons.music_note_rounded,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
    );
  }
}
