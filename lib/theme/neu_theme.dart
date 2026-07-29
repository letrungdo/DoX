import 'package:flutter/material.dart';

/// Design tokens for the app's neumorphic ("soft UI") surfaces.
///
/// Neumorphism only reads when every panel shares the scaffold's colour and is
/// separated from it by light/dark shadow pairs instead of borders, so [base] is
/// deliberately the same value as `scaffoldBackgroundColor`. Panels are raised:
/// the light shadow at the top-left, the dark one at the bottom-right. Nothing
/// is drawn concave — elements that need to read as "not raised" (inputs,
/// unselected segments, tracks) use the flat [sunken] fill and no shadow.
class NeuTheme extends ThemeExtension<NeuTheme> {
  const NeuTheme({
    required this.base,
    required this.sunken,
    required this.lightShadow,
    required this.darkShadow,
  });

  /// Shared colour of the scaffold and of every raised panel.
  final Color base;

  /// Flat fill, a shade off [base], for elements that must read as "not
  /// raised": text fields, unselected segments, progress tracks. No shadow —
  /// the colour step alone carries it.
  final Color sunken;

  /// Highlight side of a shadow pair (top-left when raised).
  final Color lightShadow;

  /// Shade side of a shadow pair (bottom-right when raised).
  final Color darkShadow;

  static const light = NeuTheme(
    base: Color(0xFFE7F1ED), //
    sunken: Color(0xFFDCE8E3),
    lightShadow: Color(0xE6FFFFFF),
    darkShadow: Color(0x6B8CA69E),
  );

  /// Dark neumorphism needs a base that is *not* near-black: the highlight has
  /// to have room to lift off the surface, so the dark theme sits at ~9% white
  /// rather than the old `0xFF0D1513`.
  ///
  /// Both shadows carry the base's teal cast instead of being pure white and
  /// pure black. On a tinted dark surface, white washes out to a dead grey and
  /// black turns the shade into a sooty smudge — neither belongs to the palette.
  /// Tinting them keeps the pair reading as light and shade on *this* surface.
  static const dark = NeuTheme(
    base: Color(0xFF16201E), //
    sunken: Color(0xFF111917),
    lightShadow: Color(0x2B3B514C),
    darkShadow: Color(0x6E050A09),
  );

  /// Shadow pair for a panel that sits above the surface. [depth] scales blur,
  /// offset and spread together, so `0.5` is a subtle chip and `1.4` a hero
  /// card.
  ///
  /// Blur stays ~2.5× the offset: at a ratio near 1 the two shadows keep a hard
  /// edge and the card reads as double-outlined rather than lifted, while a much
  /// higher ratio spreads them so thin they disappear on this low-contrast base.
  /// Visibility comes from the shade's own darkness, not from a wider blur —
  /// hence a mid-tone [darkShadow] and only a slight negative spread.
  ///
  /// [tint] is the panel's own fill when it differs from [base]. A tinted card
  /// dropping the neutral grey-teal shade looked like two unrelated colours
  /// stacked, so its shade is derived from the fill instead — see [shadeOf].
  List<BoxShadow> raisedShadows({double depth = 1, Color? tint}) {
    return [
      BoxShadow(
        color: tint == null ? darkShadow : shadeOf(tint),
        blurRadius: 15 * depth,
        spreadRadius: -1 * depth,
        offset: Offset(6 * depth, 6 * depth),
      ),
      BoxShadow(
        color: lightShadow,
        blurRadius: 15 * depth,
        spreadRadius: -1 * depth,
        offset: Offset(-6 * depth, -6 * depth),
      ),
    ];
  }

  /// The shade a panel filled with [tint] casts: [darkShadow] rotated onto the
  /// tint's hue.
  ///
  /// Only the hue is taken from the tint. Lightness stays exactly [darkShadow]'s
  /// so every card in a list casts a shade of the same weight, whatever its
  /// tint — deriving lightness from the fill instead made pale tints explode
  /// into vivid mid-tones (`successSoft` #D6EDDF came out a neon #39BE6D).
  /// Saturation is the neutral's plus a nudge: enough to read as coloured, not
  /// enough to compete with the card.
  Color shadeOf(Color tint) {
    final neutral = HSLColor.fromColor(darkShadow.withValues(alpha: 1));
    return HSLColor.fromAHSL(
      darkShadow.a,
      HSLColor.fromColor(tint).hue,
      (neutral.saturation + 0.18).clamp(0.0, 1.0),
      neutral.lightness,
    ).toColor();
  }

  /// Panels are never outlined: an edge next to a shadow pair reads as a second,
  /// competing boundary. State that used to be carried by a tinted border is
  /// carried by the fill [color] instead — and by the shade that fill casts.
  BoxDecoration raised({double radius = 18, double depth = 1, Color? color}) {
    return BoxDecoration(
      color: color ?? base,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: raisedShadows(
        depth: depth,
        tint: color == null || color == base ? null : color,
      ),
    );
  }

  @override
  ThemeExtension<NeuTheme> copyWith({
    Color? base,
    Color? sunken,
    Color? lightShadow,
    Color? darkShadow,
  }) {
    return NeuTheme(
      base: base ?? this.base, //
      sunken: sunken ?? this.sunken,
      lightShadow: lightShadow ?? this.lightShadow,
      darkShadow: darkShadow ?? this.darkShadow,
    );
  }

  @override
  ThemeExtension<NeuTheme> lerp(ThemeExtension<NeuTheme>? other, double t) {
    if (other is! NeuTheme) {
      return this;
    }
    return NeuTheme(
      base: Color.lerp(base, other.base, t)!, //
      sunken: Color.lerp(sunken, other.sunken, t)!,
      lightShadow: Color.lerp(lightShadow, other.lightShadow, t)!,
      darkShadow: Color.lerp(darkShadow, other.darkShadow, t)!,
    );
  }
}
