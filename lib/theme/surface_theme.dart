import 'package:do_x/constants/dimens.dart';
import 'package:flutter/material.dart';

/// Design tokens for the app's flat, tonal surfaces.
///
/// One layering rule: a surface is told apart from what it sits on by a
/// *different opaque fill*, never by a shadow and — for a resting card — never
/// by a border. The page is [base], a card on it is [surface], a card inside a
/// card (or a dialog, or a sheet) is that parent's fill with [nestOverlay]
/// blended over it. Hierarchy comes from those fill steps, type weight and
/// spacing; colour is reserved for meaning.
///
/// Shadows survive only on things that genuinely float over content — a popup
/// menu, a snack bar, a toast, the keyboard accessory bar — and they all use
/// [floatShadow].
///
/// Elements that must read as "not a surface" (inputs, unselected tracks,
/// disabled buttons, placeholder art) use the muted [sunken] fill.
class SurfaceTheme extends ThemeExtension<SurfaceTheme> {
  const SurfaceTheme({
    required this.base,
    required this.surface,
    required this.elevated,
    required this.sunken,
    required this.hairline,
    required this.primarySoft,
    required this.nestOverlay,
    required this.focusOverlay,
    required this.scrim,
    required this.pressOpacity,
    required this.floatShadow,
    required this.darkShadow,
  });

  /// The page: scaffold, app bar, TV rail, canvas.
  final Color base;

  /// An untinted card, neutral button or chip resting on the page.
  final Color surface;

  /// Dialogs, bottom sheets, popup and dropdown menus.
  final Color elevated;

  /// Muted fill for elements that must read as "not a surface": text fields,
  /// unselected switch tracks, progress tracks, disabled buttons.
  final Color sunken;

  /// Dividers, the bottom bar's top edge, the TV rail's edge. Never drawn
  /// around a resting card.
  final Color hairline;

  /// Tonal fill for a selected nav/rail row, the current music track, and a
  /// tonal button (`accent: primarySoft, foreground: primary`).
  final Color primarySoft;

  /// Blended over any background other than the page to get the fill of an
  /// untinted panel nested in it; see [panelOn]. Works over tints too, so a
  /// card in a tinted card is the tint one step deeper (or lighter).
  final Color nestOverlay;

  /// Blended over a control's fill while the TV remote rests on it, on top of
  /// the ring and the growth `TvShell` and `AppPressable` already draw.
  final Color focusOverlay;

  /// The barrier behind a dialog or bottom sheet.
  final Color scrim;

  /// Opacity of the press layer, drawn in the control's content colour.
  final double pressOpacity;

  /// The one shadow in the app, for surfaces that float over content.
  final List<BoxShadow> floatShadow;

  /// The colour of [floatShadow], for the Material widgets that take a
  /// `shadowColor` rather than a list of shadows.
  final Color darkShadow;

  static const light = SurfaceTheme(
    base: Color(0xFFF1F5F4), //
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFFFF),
    sunken: Color(0xFFE6ECEA),
    hairline: Color(0xFFDDE4E2),
    primarySoft: Color(0xFFE0EDEB),
    nestOverlay: Color(0x0D0F3D37),
    // The primary at 8%.
    focusOverlay: Color(0x1400695C),
    scrim: Color(0x66000000),
    pressOpacity: 0.10,
    floatShadow: [
      BoxShadow(color: Color(0x1F0F1E1C), blurRadius: 24, offset: Offset(0, 8)),
    ],
    darkShadow: Color(0x1F0F1E1C),
  );

  static const dark = SurfaceTheme(
    base: Color(0xFF0E1413), //
    surface: Color(0xFF172020),
    elevated: Color(0xFF202A29),
    sunken: Color(0xFF243030),
    hairline: Color(0xFF2A3533),
    primarySoft: Color(0xFF1B3D39),
    nestOverlay: Color(0x0DFFFFFF),
    // White at 12%: a focused card steps from #172020 to #333B3B, which is
    // visible from a sofa.
    focusOverlay: Color(0x1FFFFFFF),
    scrim: Color(0x99000000),
    pressOpacity: 0.10,
    floatShadow: [
      BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
    darkShadow: Color(0x80000000),
  );

  /// Fill of an untinted panel sitting on [background]: [surface] on the page,
  /// otherwise the background with [nestOverlay] blended over it.
  Color panelOn(Color background) {
    if (background == base) return surface;
    return Color.alphaBlend(nestOverlay, background);
  }

  /// The fill a flat control shows for its state. [content] is the label/icon
  /// colour; the press layer is drawn in it, M3-style. Pass [pressOpacity] to
  /// override the theme's, e.g. 0.12 on a saturated primary or error fill.
  Color stateFill(
    Color fill, {
    required Color content,
    bool pressed = false,
    bool focused = false,
    double? pressOpacity,
  }) {
    var color = fill;
    if (focused) color = Color.alphaBlend(focusOverlay, color);
    if (pressed) {
      color = Color.alphaBlend(
        content.withValues(alpha: pressOpacity ?? this.pressOpacity),
        color,
      );
    }
    return color;
  }

  /// Always empty: panels carry no shadow. Kept so hand-rolled decorations
  /// still compile until they move to [AppCard] or a plain [BoxDecoration].
  List<BoxShadow> raisedShadows({
    required Color fill,
    double depth = 1,
    bool inset = false,
  }) => const [];

  /// Flat decoration for a panel drawn by hand. [color] is a semantic tint
  /// (state), and [background] the surface the panel sits on — pass it so an
  /// untinted panel nested in a card takes the nested fill.
  ///
  /// `depth: 0` means "pressed": every hand-rolled caller writes
  /// `depth: pressed ? 0 : x`, so it gets the press layer. Any other depth,
  /// and [inset], are ignored — selection is already carried by [color].
  BoxDecoration raised({
    double radius = Dimens.radiusCard,
    double depth = 1,
    Color? color,
    Color? background,
    bool inset = false,
  }) {
    final fill = color ?? panelOn(background ?? base);
    return BoxDecoration(
      color: depth == 0
          ? stateFill(fill, content: _pressContent, pressed: true)
          : fill,
      borderRadius: BorderRadius.circular(radius),
    );
  }

  /// The content colour a hand-rolled press is drawn in: dark on the light
  /// theme, light on the dark one.
  Color get _pressContent =>
      ThemeData.estimateBrightnessForColor(base) == Brightness.dark
      ? Colors.white
      : Colors.black;

  @override
  ThemeExtension<SurfaceTheme> copyWith({
    Color? base,
    Color? surface,
    Color? elevated,
    Color? sunken,
    Color? hairline,
    Color? primarySoft,
    Color? nestOverlay,
    Color? focusOverlay,
    Color? scrim,
    double? pressOpacity,
    List<BoxShadow>? floatShadow,
    Color? darkShadow,
  }) {
    return SurfaceTheme(
      base: base ?? this.base, //
      surface: surface ?? this.surface,
      elevated: elevated ?? this.elevated,
      sunken: sunken ?? this.sunken,
      hairline: hairline ?? this.hairline,
      primarySoft: primarySoft ?? this.primarySoft,
      nestOverlay: nestOverlay ?? this.nestOverlay,
      focusOverlay: focusOverlay ?? this.focusOverlay,
      scrim: scrim ?? this.scrim,
      pressOpacity: pressOpacity ?? this.pressOpacity,
      floatShadow: floatShadow ?? this.floatShadow,
      darkShadow: darkShadow ?? this.darkShadow,
    );
  }

  @override
  ThemeExtension<SurfaceTheme> lerp(
    ThemeExtension<SurfaceTheme>? other,
    double t,
  ) {
    if (other is! SurfaceTheme) {
      return this;
    }
    return SurfaceTheme(
      base: Color.lerp(base, other.base, t)!, //
      surface: Color.lerp(surface, other.surface, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      nestOverlay: Color.lerp(nestOverlay, other.nestOverlay, t)!,
      focusOverlay: Color.lerp(focusOverlay, other.focusOverlay, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      pressOpacity: pressOpacity + (other.pressOpacity - pressOpacity) * t,
      floatShadow: BoxShadow.lerpList(floatShadow, other.floatShadow, t)!,
      darkShadow: Color.lerp(darkShadow, other.darkShadow, t)!,
    );
  }
}
