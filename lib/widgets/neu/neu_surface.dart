import 'package:do_x/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// The colour of the surface a neumorphic panel is drawn on.
///
/// A raised panel's shadows land on whatever is *behind* it, so that colour —
/// not the panel's own fill — is what its highlight has to be derived from.
/// [NeuCard] publishes its fill through this, so a card nested in a tinted card
/// lights up against the tint instead of against the scaffold.
class NeuSurface extends InheritedWidget {
  const NeuSurface({super.key, required this.color, required super.child});

  final Color color;

  /// The surface enclosing [context], falling back to the scaffold's own base
  /// colour when nothing published one.
  static Color of(BuildContext context) {
    final surface = context.dependOnInheritedWidgetOfExactType<NeuSurface>();
    return surface?.color ?? context.neu.base;
  }

  @override
  bool updateShouldNotify(NeuSurface oldWidget) => oldWidget.color != color;
}

extension NeuSurfaceContext on BuildContext {
  /// [NeuTheme.raised] with the enclosing surface filled in — the form to reach
  /// for when decorating a raised panel by hand instead of using [NeuCard].
  BoxDecoration neuRaised({
    double radius = 18,
    double depth = 1,
    Color? color,
    bool inset = false,
  }) {
    return neu.raised(
      radius: radius,
      depth: depth,
      color: color,
      background: NeuSurface.of(this),
      inset: inset,
    );
  }

  /// [color] at [amount] opacity, flattened onto the enclosing surface.
  ///
  /// The fill for a small pill or icon tile that carries a colour. Opaque, so it
  /// keeps its hue on a tinted card instead of muddying, and so it can be the
  /// only thing marking the shape — those used to be outlined, which the design
  /// avoids everywhere else.
  Color neuTint(Color color, {double amount = 0.16}) {
    return Color.alphaBlend(
      color.withValues(alpha: amount),
      NeuSurface.of(this),
    );
  }
}
