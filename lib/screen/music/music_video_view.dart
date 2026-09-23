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
    return AspectRatio(
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
            ],
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
