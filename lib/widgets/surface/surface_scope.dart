import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// The colour of the surface a flat panel is drawn on.
///
/// An untinted panel's fill is one step off whatever is *behind* it (see
/// `SurfaceTheme.panelOn`), so that colour has to be known. [AppCard] publishes its
/// fill through this, and so do dialogs and sheets, so a card nested in a card,
/// a tinted card or a sheet steps off its real parent instead of the scaffold.
class SurfaceScope extends InheritedWidget {
  const SurfaceScope({super.key, required this.color, required super.child});

  final Color color;

  /// The surface enclosing [context], falling back to the scaffold's own base
  /// colour when nothing published one.
  static Color of(BuildContext context) {
    final surface = context.dependOnInheritedWidgetOfExactType<SurfaceScope>();
    return surface?.color ?? context.surfaces.base;
  }

  @override
  bool updateShouldNotify(SurfaceScope oldWidget) => oldWidget.color != color;
}

extension SurfaceScopeContext on BuildContext {
  /// [SurfaceTheme.panel] with the enclosing surface filled in — a flat
  /// decoration for a panel drawn by hand instead of with [AppCard].
  BoxDecoration panelDecoration({
    double radius = Dimens.radiusCard,
    Color? color,
  }) {
    return surfaces.panel(
      radius: radius,
      color: color,
      background: SurfaceScope.of(this),
    );
  }

  /// [color] at [amount] opacity, flattened onto the enclosing surface.
  ///
  /// The fill for a small pill or icon tile that carries a colour. Opaque, so it
  /// keeps its hue on a tinted card instead of muddying, and so it can be the
  /// only thing marking the shape — the design outlines nothing at rest.
  Color tintOnSurface(Color color, {double amount = 0.16}) {
    return Color.alphaBlend(
      color.withValues(alpha: amount),
      SurfaceScope.of(this),
    );
  }
}
