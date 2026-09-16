import 'dart:math' as math;

import 'package:flutter/material.dart';

extension ColorExtensions on Color? {
  String? toHexString({bool includeAlpha = true}) {
    final color = this;
    if (color == null) return null;

    final aInt = (color.a * 255).toInt();
    final rInt = (color.r * 255).toInt();
    final gInt = (color.g * 255).toInt();
    final bInt = (color.b * 255).toInt();

    final aHex = aInt.toRadixString(16).padLeft(2, '0');
    final rHex = rInt.toRadixString(16).padLeft(2, '0');
    final gHex = gInt.toRadixString(16).padLeft(2, '0');
    final bHex = bInt.toRadixString(16).padLeft(2, '0');

    // The moment API spells colors #RRGGBB(AA) - alpha last, as in the
    // #FFFFFFE6 its own client posts for a 90% white caption.
    return '#$rHex$gHex$bHex${includeAlpha ? aHex : ""}'.toUpperCase();
  }

  /// The ink of the two that reads better on a background of this color.
  ///
  /// [Color.computeLuminance] ignores alpha, so a translucent background is
  /// composited over [backdrop] first - otherwise black at 10% opacity reads as
  /// "dark" and gets handed white ink it cannot carry.
  Color? getTextColor({Color backdrop = Colors.black}) {
    final color = this;
    if (color == null) return null;
    final solid = Color.alphaBlend(color, backdrop);
    return contrastRatio(solid, darkTextColor) >=
            contrastRatio(solid, lightTextColor)
        ? darkTextColor
        : lightTextColor;
  }

  /// Ink for a dark background: white at 90%, which the moment API spells
  /// #FFFFFFE6. Written ARGB here, so the alpha leads.
  static const lightTextColor = Color(0xE6FFFFFF);

  /// Ink for a light background.
  static const darkTextColor = Color.fromARGB(255, 2, 22, 59);

  /// WCAG AA for body text. Below this a caption is legible only to someone
  /// already looking for it.
  static const minTextContrast = 4.5;
}

extension ColorReadability on Color {
  /// A background and an ink that can actually be read together.
  ///
  /// Choosing the better of two inks is not enough on its own: a mid-tone
  /// accent - a medium blue, a muted olive - carries neither dark nor light
  /// text, and the better of the two still lands under [minContrast]. So the
  /// color keeps the hue and saturation the user picked while its lightness
  /// moves away from the ink until the pair clears the bar.
  ({Color background, Color foreground}) readablePair({
    Color backdrop = Colors.black,
    double minContrast = ColorExtensions.minTextContrast,
  }) {
    // The caption sits on a photo, so an opaque pill is what gets drawn no
    // matter how transparent the picked color was.
    var background = Color.alphaBlend(this, backdrop);
    final foreground = background.getTextColor(backdrop: backdrop)!;

    // The ink stays put and only the background moves: flipping the ink
    // mid-walk would send the background back the way it came. 20 steps of 4%
    // spans the whole lightness range, and the walk stops at black or white.
    final darken = foreground.computeLuminance() > 0.5;
    var hsl = HSLColor.fromColor(background);
    for (var i = 0; i < 20; i++) {
      if (contrastRatio(background, foreground) >= minContrast) break;
      final lightness = (hsl.lightness + (darken ? -0.04 : 0.04)).clamp(
        0.0,
        1.0,
      );
      if (lightness == hsl.lightness) break;
      hsl = hsl.withLightness(lightness);
      background = hsl.toColor();
    }

    return (background: background, foreground: foreground);
  }
}

/// WCAG contrast between an opaque [background] and [ink] laid over it: 1 for
/// two identical colors, 21 for black on white.
double contrastRatio(Color background, Color ink) {
  final a = background.computeLuminance();
  final b = Color.alphaBlend(ink, background).computeLuminance();
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}
