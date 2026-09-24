import 'dart:ui' show lerpDouble;

import 'package:do_x/constants/dimens.dart';
import 'package:do_x/screen/movie/movie_player_layout.dart';
import 'package:do_x/screen/movie/movie_thumbnail_track.dart';
import 'package:do_x/widgets/focusable_tap.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Round translucent button used for play/pause in the middle of the player.
class PlayerCenterButton extends StatelessWidget {
  const PlayerCenterButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 48,
  });

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
  const PlayerGestureOverlays({
    super.key,
    required this.isSpeedBoosted,
    required this.skipForwardValue,
    required this.skipBackwardValue,
  });

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(Dimens.radiusCard),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.fast_forward_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '2x',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (skipBackwardValue > 0)
            _SkipBadge(
              alignment: Alignment.centerLeft,
              icon: Icons.fast_rewind_rounded,
              label: '-${skipBackwardValue}s',
            ),
          if (skipForwardValue > 0)
            _SkipBadge(
              alignment: Alignment.centerRight,
              icon: Icons.fast_forward_rounded,
              label: '+${skipForwardValue}s',
            ),
        ],
      ),
    );
  }
}

class _SkipBadge extends StatelessWidget {
  const _SkipBadge({
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        margin: EdgeInsets.only(
          left: alignment == Alignment.centerLeft ? 32 : 0,
          right: alignment == Alignment.centerRight ? 32 : 0,
        ),
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Volume button of the bottom bar: tap opens the slider, hold mutes.
///
/// Deliberately ink-free: over a video, a material ripple/highlight paints as a
/// grey block, and neither [IconButton] nor [InkResponse] can be talked out of
/// it entirely. A bare gesture detector also keeps `onLongPress` for itself,
/// which an ancestor detector would lose to the button's own tap recognizer.
class PlayerVolumeButton extends StatelessWidget {
  const PlayerVolumeButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.onLongPress,
    this.onHover,
    this.muted = false,
  });

  static const size = 40.0;

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final ValueChanged<bool>? onHover;
  final VoidCallback onLongPress;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      // A tooltip defaults to long press on touch, which would pop its bubble
      // over the button every time the user holds to mute. Hover still works.
      triggerMode: TooltipTriggerMode.manual,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover?.call(true),
        onExit: (_) => onHover?.call(false),
        // Focusable, not a bare detector: on a TV this button is only
        // reachable by walking the D-pad onto it, and a detector has no focus
        // node for the remote to land on.
        child: FocusableTap(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              icon,
              size: 22,
              color: muted ? Colors.white70 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Vertical volume slider that pops up over the volume button. It carries no
/// speaker icon of its own — the button it grows out of already is one.
class PlayerVolumePopup extends StatelessWidget {
  const PlayerVolumePopup({
    super.key,
    required this.volume,
    required this.onChanged,
    required this.onChangeStart,
  });

  final double volume;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeStart;

  /// Wide enough for "100" to stay on one line and for the upright slider to
  /// keep a usable touch target.
  static const width = 42.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(2, 6, 2, 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(Dimens.radiusControl),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${(volume * 100).round()}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              height: 120,
              // The box width is the slider's touch depth once it stands up.
              width: 38,
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  // A default Slider reserves its overlay radius at both ends,
                  // which reads as dead space once the slider stands upright.
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                  ),
                  child: Slider(
                    value: volume,
                    onChangeStart: (_) => onChangeStart(),
                    onChanged: onChanged,
                    activeColor: Colors.pinkAccent,
                    inactiveColor: Colors.white30,
                  ),
                ),
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
  const PlayerTopBar({
    super.key,
    required this.showBack,
    required this.onBack,
    required this.onSettings,
    this.title,
    this.subtitle,
  });

  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack)
          _RoundIconButton(
            icon: Icons.arrow_back_rounded,
            size: 28,
            onTap: onBack,
          )
        else
          const SizedBox.shrink(),
        if (title != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ] else
          const Spacer(),
        _RoundIconButton(
          icon: Icons.settings_rounded,
          size: 24,
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

/// How long the bar takes to thicken when it is focused, hovered or held.
const _seekBarActiveDuration = Duration(milliseconds: 150);

/// Sleek seek bar with animated track expansion and glowing thumb handle.
///
/// Only the thickness animates. The played and buffered lengths are set
/// outright: animating them turned every position report into 150ms of frames,
/// which over a whole film meant the player never stopped drawing.
class VideoSeekBar extends StatelessWidget {
  const VideoSeekBar({
    super.key,
    required this.controller,
    required this.isFocused,
    required this.isHovered,
    required this.isDragging,
    required this.isScrubbing,
    this.dragFraction,
    this.live = true,
    this.playedColor = Colors.pinkAccent,
    this.bufferedColor = Colors.white30,
    this.backgroundColor = Colors.white12,
  });

  final VideoPlayerController? controller;
  final bool isFocused;
  final bool isHovered;
  final bool isDragging;
  final bool isScrubbing;
  final double? dragFraction;

  /// Whether the bar follows the controller. Off while the controls are
  /// hidden: nobody can see the bar then, and following it would still cost a
  /// frame on every position report.
  final bool live;
  final Color playedColor;
  final Color bufferedColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final activeController = controller;
    if (activeController == null || !activeController.value.isInitialized) {
      return SizedBox(
        height: 20,
        child: Center(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    final isActive = isFocused || isHovered || isDragging || isScrubbing;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isActive ? 1 : 0),
      duration: _seekBarActiveDuration,
      builder: (context, active, _) {
        if (!live) return _buildTrack(activeController.value, active);
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: activeController,
          builder: (context, value, _) => _buildTrack(value, active),
        );
      },
    );
  }

  /// [active] runs from 0 (resting) to 1 (focused, hovered or held) while the
  /// bar thickens, and everything that grows with it is interpolated from it.
  Widget _buildTrack(VideoPlayerValue value, double active) {
    final trackHeight = lerpDouble(4, 6, active)!;
    final thumbSize = lerpDouble(10, 14, active)!;
    final totalMs = value.duration.inMilliseconds;
    final positionMs = value.position.inMilliseconds;

    double playedFraction = 0.0;
    if (totalMs > 0) {
      if ((isDragging || isScrubbing) && dragFraction != null) {
        playedFraction = dragFraction!.clamp(0.0, 1.0);
      } else {
        playedFraction = (positionMs / totalMs).clamp(0.0, 1.0);
      }
    }

    double bufferedFraction = 0.0;
    if (totalMs > 0 && value.buffered.isNotEmpty) {
      final bufferedEnd = value.buffered.last.end.inMilliseconds;
      bufferedFraction = (bufferedEnd / totalMs).clamp(0.0, 1.0);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final playedWidth = (width * playedFraction).clamp(0.0, width);
        final bufferedWidth = (width * bufferedFraction).clamp(0.0, width);
        final radius = BorderRadius.circular(trackHeight / 2);

        return SizedBox(
          height: 20,
          width: width,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              // Track Background
              Container(
                height: trackHeight,
                width: width,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: radius,
                ),
              ),
              // Buffered Bar
              Container(
                height: trackHeight,
                width: bufferedWidth,
                decoration: BoxDecoration(
                  color: bufferedColor,
                  borderRadius: radius,
                ),
              ),
              // Played Bar
              Container(
                height: trackHeight,
                width: playedWidth,
                decoration: BoxDecoration(
                  color: playedColor,
                  borderRadius: radius,
                ),
              ),
              // Thumb Handle / Highlight Dot
              Positioned(
                left: (playedWidth - thumbSize / 2).clamp(
                  0.0,
                  width - thumbSize,
                ),
                child: Container(
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: playedColor,
                      width: lerpDouble(2, 3, active)!,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: playedColor.withValues(
                          alpha: lerpDouble(0.4, 0.8, active)!,
                        ),
                        blurRadius: lerpDouble(4, 8, active)!,
                        spreadRadius: lerpDouble(1, 2, active)!,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
          borderRadius: BorderRadius.circular(Dimens.radiusSmall),
          border: Border.all(color: Colors.white70),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ThumbnailPreview(
                track: track,
                cue: cue,
                width: width,
                referer: referer,
                fallback: fallback,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                formatDuration(position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
