import 'package:flutter/material.dart';

/// Design tokens for the app's neumorphic ("soft UI") surfaces.
///
/// The model is the classic one (as in `flutter_neumorphism_ui`): a panel is the
/// *same colour* as the page, and the only thing separating them is a pair of
/// opaque shadows derived from that colour — the colour lightened on the side the
/// light comes from, darkened on the other. Nothing is outlined, and nothing is
/// tinted a step lighter to be found: the two rims are the edge.
///
/// Earlier revisions gave the panel its own fill and translucent shadows. Both
/// fought the effect: a translucent shade over a low-contrast page washes out to
/// a smudge, and lifting the fill left the rims with nothing to sit against.
///
/// Elements that must read as "not raised" (inputs, unselected segments, tracks)
/// use the flat [sunken] fill and no shadow at all.
class NeuTheme extends ThemeExtension<NeuTheme> {
  const NeuTheme({
    required this.base,
    required this.sunken,
    required this.darkShadow,
    required this.highlightLift,
    required this.shadeDrop,
    required this.panelLift,
    required this.depthScale,
  });

  /// Shared colour of the scaffold and of every raised panel.
  final Color base;

  /// Flat fill, a shade off [base], for elements that must read as "not
  /// raised": text fields, unselected segments, progress tracks. No shadow —
  /// the colour step alone carries it.
  final Color sunken;

  /// Plain shadow colour for the Material widgets that take one (dialogs, menus,
  /// the app bar). Panels use [shadeOf] instead, which follows their own fill.
  final Color darkShadow;

  /// How much [highlightOn] lightens a colour to get its lit rim.
  final double highlightLift;

  /// How much [shadeOf] darkens a colour to get its shaded rim. A touch deeper
  /// than [highlightLift]: shade carries more of the lift than light does, and
  /// on a pale page the highlight runs out of room first.
  final double shadeDrop;

  /// How far [panelOn] moves a background's lightness to get the fill of an
  /// untinted panel. Zero in this model — the panel is the page, and the rims
  /// are what separate them. Left as a token so a screen can be tried both ways
  /// without touching the shadow code.
  final double panelLift;

  /// Multiplies the shadow geometry — offset and blur together.
  ///
  /// The dark theme wants a slightly tighter pair: on a near-black page a wide
  /// blur has nothing to fade into, so the same geometry that reads as soft
  /// light in light mode starts to read as a smudge.
  final double depthScale;

  /// The page can sit this pale because both rims are opaque and derived from
  /// the panel's own colour: the lit one lands on white and the shade keeps its
  /// full 12% drop, so lightening the page does not wash the pair out the way it
  /// did when the shadows were translucent.
  static const light = NeuTheme(
    base: Color(0xFFE4EFEB), //
    sunken: Color(0xFFD7E5E0),
    darkShadow: Color(0x6B8CA69E),
    highlightLift: 0.1,
    shadeDrop: 0.12,
    panelLift: 0,
    depthScale: 1,
  );

  /// Dark neumorphism needs a base that is *not* near-black: both rims are
  /// derived from it, so the shade needs somewhere to go. This sits at ~9% white
  /// rather than the old `0xFF0D1513`.
  static const dark = NeuTheme(
    base: Color(0xFF16201E), //
    sunken: Color(0xFF111917),
    darkShadow: Color(0x6E050A09),
    highlightLift: 0.1,
    shadeDrop: 0.06,
    panelLift: 0,
    depthScale: 0.85,
  );

  /// Reference depth in logical pixels, before [depth] and [depthScale] scale
  /// it. Offset is 60% of it and blur 150%, which is the ratio that reads as one
  /// soft light source rather than as two outlines.
  static const _baseDepth = 8.0;

  /// The shadow pair for a panel filled with [fill], sitting [depth] high — 1 is
  /// a card, ~0.6 a chip, 1.4 a hero panel.
  ///
  /// [inset] swaps the two rims, which is the pressed/debossed look: it reads as
  /// the panel having sunk into the page, and is what [NeuCard] shows while held.
  List<BoxShadow> raisedShadows({
    required Color fill,
    double depth = 1,
    bool inset = false,
  }) {
    final d = _baseDepth * depth * depthScale;
    final shade = shadeOf(fill);
    final highlight = highlightOn(fill);
    if (inset) {
      // Pulled in by a negative spread so the pair hugs the edge instead of
      // spilling outwards — a pressed panel casts nothing far from itself.
      return [
        BoxShadow(
          color: shade,
          offset: Offset(d * 0.5, d * 0.5),
          blurRadius: d,
          spreadRadius: -d * 0.25,
        ),
        BoxShadow(
          color: highlight,
          offset: Offset(-d * 0.5, -d * 0.5),
          blurRadius: d,
          spreadRadius: -d * 0.25,
        ),
      ];
    }
    return [
      BoxShadow(
        color: shade,
        offset: Offset(d * 0.6, d * 0.6),
        blurRadius: d * 1.5,
      ),
      BoxShadow(
        color: highlight,
        offset: Offset(-d * 0.6, -d * 0.6),
        blurRadius: d * 1.5,
      ),
    ];
  }

  /// The lit rim of a panel filled with [color]: that colour lightened, opaque.
  ///
  /// Derived from the panel's own fill rather than fixed, so a tinted card lights
  /// up in its own hue — a neutral white rim on a pink card looked like two
  /// unrelated surfaces stacked.
  Color highlightOn(Color color) {
    final hsl = HSLColor.fromColor(color.withValues(alpha: 1));
    return hsl
        .withLightness((hsl.lightness + highlightLift).clamp(0.0, 1.0))
        .toColor();
  }

  /// The shaded rim of a panel filled with [color]: that colour darkened, opaque,
  /// with a nudge of saturation so it stays in the palette instead of going grey.
  Color shadeOf(Color color) {
    final hsl = HSLColor.fromColor(color.withValues(alpha: 1));
    return hsl
        .withLightness((hsl.lightness - shadeDrop).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.05).clamp(0.0, 1.0))
        .toColor();
  }

  /// Fill of an untinted panel sitting on [background]; see [panelLift].
  Color panelOn(Color background) {
    if (panelLift == 0) return background;
    final hsl = HSLColor.fromColor(background);
    return HSLColor.fromAHSL(
      background.a,
      hsl.hue,
      hsl.saturation,
      (hsl.lightness + panelLift).clamp(0.0, 1.0),
    ).toColor();
  }

  /// Decoration for a raised panel. [color] is a semantic tint (state), and
  /// [background] the surface the panel sits on — pass it so an untinted panel
  /// nested in a tinted card takes the card's colour rather than the scaffold's.
  BoxDecoration raised({
    double radius = 18,
    double depth = 1,
    Color? color,
    Color? background,
    bool inset = false,
  }) {
    final fill = color ?? panelOn(background ?? base);
    return BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: raisedShadows(fill: fill, depth: depth, inset: inset),
    );
  }

  @override
  ThemeExtension<NeuTheme> copyWith({
    Color? base,
    Color? sunken,
    Color? darkShadow,
    double? highlightLift,
    double? shadeDrop,
    double? panelLift,
    double? depthScale,
  }) {
    return NeuTheme(
      base: base ?? this.base, //
      sunken: sunken ?? this.sunken,
      darkShadow: darkShadow ?? this.darkShadow,
      highlightLift: highlightLift ?? this.highlightLift,
      shadeDrop: shadeDrop ?? this.shadeDrop,
      panelLift: panelLift ?? this.panelLift,
      depthScale: depthScale ?? this.depthScale,
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
      darkShadow: Color.lerp(darkShadow, other.darkShadow, t)!,
      highlightLift: highlightLift + (other.highlightLift - highlightLift) * t,
      shadeDrop: shadeDrop + (other.shadeDrop - shadeDrop) * t,
      panelLift: panelLift + (other.panelLift - panelLift) * t,
      depthScale: depthScale + (other.depthScale - depthScale) * t,
    );
  }
}
