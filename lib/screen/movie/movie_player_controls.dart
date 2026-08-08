import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/movie/movie_player_layout.dart';
import 'package:do_x/screen/movie/movie_thumbnail_track.dart';
import 'package:flutter/material.dart';

/// Round translucent button used for play/pause in the middle of the player.
class PlayerCenterButton extends StatelessWidget {
  const PlayerCenterButton({super.key, required this.icon, required this.onPressed, this.size = 48});

  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: size * 0.6),
        ),
      ),
    );
  }
}

/// Transient feedback that stays visible even while the controls are hidden:
/// the 2x badge of a long press and the ±10s badges of a double tap.
class PlayerGestureOverlays extends StatelessWidget {
  const PlayerGestureOverlays({super.key, required this.isSpeedBoosted, required this.skipForwardValue, required this.skipBackwardValue});

  final bool isSpeedBoosted;
  final int skipForwardValue;
  final int skipBackwardValue;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          if (isSpeedBoosted)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_forward_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '2x',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (skipBackwardValue > 0)
            _SkipBadge(alignment: Alignment.centerLeft, icon: Icons.fast_rewind_rounded, label: '-${skipBackwardValue}s'),
          if (skipForwardValue > 0)
            _SkipBadge(alignment: Alignment.centerRight, icon: Icons.fast_forward_rounded, label: '+${skipForwardValue}s'),
        ],
      ),
    );
  }
}

class _SkipBadge extends StatelessWidget {
  const _SkipBadge({required this.alignment, required this.icon, required this.label});

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        margin: EdgeInsets.only(left: alignment == Alignment.centerLeft ? 32 : 0, right: alignment == Alignment.centerRight ? 32 : 0),
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mute button + slider shown above the volume icon.
class PlayerVolumePopup extends StatelessWidget {
  const PlayerVolumePopup({
    super.key,
    required this.volume,
    required this.icon,
    required this.onToggleMute,
    required this.onChanged,
    required this.onChangeStart,
  });

  final double volume;
  final IconData icon;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: volume == 0 ? l10n.unmute : l10n.mute,
              icon: Icon(icon, color: Colors.white),
              onPressed: onToggleMute,
            ),
            SizedBox(
              width: 120,
              child: Slider(
                value: volume,
                onChangeStart: (_) => onChangeStart(),
                onChanged: onChanged,
                activeColor: Colors.pinkAccent,
                inactiveColor: Colors.white30,
              ),
            ),
            SizedBox(
              width: 38,
              child: Text(
                '${(volume * 100).round()}%',
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back (full screen only) and settings buttons floating over the video.
class PlayerTopBar extends StatelessWidget {
  const PlayerTopBar({super.key, required this.showBack, required this.onBack, required this.onSettings});

  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (showBack) _RoundIconButton(icon: Icons.arrow_back_rounded, size: 28, onTap: onBack) else const SizedBox.shrink(),
        _RoundIconButton(icon: Icons.settings_rounded, size: 24, onTap: onSettings),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.size, required this.onTap});

  final IconData icon;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

/// Scrub preview: the sprite frame for [position] with its timestamp below.
class PlayerScrubPreview extends StatelessWidget {
  const PlayerScrubPreview({
    super.key,
    required this.track,
    required this.cue,
    required this.width,
    required this.referer,
    required this.fallback,
    required this.position,
  });

  final ThumbnailTrack? track;
  final ThumbnailCue? cue;
  final double width;
  final String referer;
  final Widget fallback;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white70),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ThumbnailPreview(track: track, cue: cue, width: width, referer: referer, fallback: fallback),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                formatDuration(position),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
