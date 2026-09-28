import 'dart:ui' show lerpDouble;

import 'package:do_x/constants/dimens.dart';
import 'package:flutter/material.dart';

/// The one look every seek bar in the app shares: a flat rounded track and a
/// white thumb ringed and lit in the played colour, both thickening while the
/// bar is active — focused by the remote, hovered, or held.
///
/// The film player draws its bar by hand (it shows the buffered length too);
/// the music player's is a [Slider] themed with [seekBarSliderTheme]. Both
/// read their sizes from here, so neither drifts from the other.
///
/// Every value takes `active`, which runs from 0 (resting) to 1 (active), so
/// a caller can animate between the two.
abstract final class SeekBarStyle {
  static double trackHeight(double active) => lerpDouble(
    Dimens.seekBarTrackHeight,
    Dimens.seekBarActiveTrackHeight,
    active,
  )!;

  static double thumbSize(double active) => lerpDouble(
    Dimens.seekBarThumbSize,
    Dimens.seekBarActiveThumbSize,
    active,
  )!;

  static BoxDecoration thumbDecoration(Color playedColor, double active) {
    return BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: playedColor, width: lerpDouble(2, 3, active)!),
      boxShadow: [
        BoxShadow(
          color: playedColor.withValues(alpha: lerpDouble(0.4, 0.8, active)!),
          blurRadius: lerpDouble(4, 8, active)!,
          spreadRadius: lerpDouble(1, 2, active)!,
        ),
      ],
    );
  }
}

/// [base] made into the shared seek bar look for a [Slider].
///
/// The overlay is kept, invisible, for its size alone: it is what gives a
/// finger something bigger than the thin track to land on.
SliderThemeData seekBarSliderTheme(
  SliderThemeData base, {
  required double active,
  required Color playedColor,
  required Color trackColor,
}) {
  return base.copyWith(
    trackHeight: SeekBarStyle.trackHeight(active),
    trackShape: const _FlatTrackShape(),
    activeTrackColor: playedColor,
    inactiveTrackColor: trackColor,
    thumbShape: _SeekBarThumbShape(active: active, playedColor: playedColor),
    overlayShape: const RoundSliderOverlayShape(
      overlayRadius: Dimens.seekBarTouchRadius,
    ),
    overlayColor: Colors.transparent,
    tickMarkShape: SliderTickMarkShape.noTickMark,
  );
}

/// The rounded track with the played part no taller than the rest, as the
/// film player draws it.
class _FlatTrackShape extends RoundedRectSliderTrackShape {
  const _FlatTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: 0,
    );
  }
}

/// The film player's thumb, painted from the same decoration.
class _SeekBarThumbShape extends SliderComponentShape {
  const _SeekBarThumbShape({required this.active, required this.playedColor});

  final double active;
  final Color playedColor;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.square(SeekBarStyle.thumbSize(active));

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final size = Size.square(SeekBarStyle.thumbSize(active));
    SeekBarStyle.thumbDecoration(playedColor, active).createBoxPainter().paint(
      context.canvas,
      center - size.center(Offset.zero),
      ImageConfiguration(size: size, textDirection: textDirection),
    );
  }
}
