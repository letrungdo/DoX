import 'dart:math';

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
    this.onFullscreen,
  });

  final VideoPlayerController controller;
  final bool isOfficialAudio;
  final BorderRadius borderRadius;

  /// Makes the whole picture a tap to full screen, with a corner icon to say
  /// so.
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = controller.value.aspectRatio;
    final view = AspectRatio(
      aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
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
              if (onFullscreen != null)
                const Positioned(
                  right: Dimens.musicVideoBadgeInset,
                  bottom: Dimens.musicVideoBadgeInset,
                  child: Icon(
                    Icons.fullscreen_rounded,
                    size: Dimens.musicVideoFullscreenIconSize,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 4)],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final tap = onFullscreen;
    if (tap == null) return view;
    return Tooltip(
      message: context.l10n.musicVideoFullscreen,
      child: GestureDetector(onTap: tap, child: view),
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
