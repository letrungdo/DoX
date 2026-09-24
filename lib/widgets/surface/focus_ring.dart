import 'package:do_x/constants/dimens.dart';
import 'package:flutter/material.dart';

/// The ring a control draws around itself while the TV remote rests on it.
///
/// Each control draws its own, as a foreground decoration, rather than
/// leaving it to `TvShell`'s app-wide outline: the ring then follows the
/// control's own corner radius, is painted in the same frame and the same
/// layer as the control — so it never trails a scrolling row or lands on top
/// of an app bar the row has gone behind — and grows with the control's
/// focus lift for free.
///
/// Drawn hugging the control — its inner edge on the control's edge, its
/// corners following the control's own, so a round button gets a round ring —
/// and painted as a stroke only, so it works whatever the control's fill is,
/// transparent included. It takes no layout space; the lift the control
/// already reserves room for covers it.
class FocusRingDecoration extends Decoration {
  const FocusRingDecoration({required this.color, required this.radius});

  final Color color;

  /// The control's own corner radius; the ring's corners are this plus the
  /// ring's width, so the two stay concentric. [Dimens.radiusPill] gives a
  /// round ring.
  final double radius;

  /// The ring for a control with [radius] corners, or null while [focused] is
  /// false — the form a builder passes straight to `foregroundDecoration`.
  static FocusRingDecoration? of(
    BuildContext context, {
    required bool focused,
    required double radius,
  }) {
    if (!focused) return null;
    return FocusRingDecoration(
      color: Theme.of(context).colorScheme.primary,
      radius: radius,
    );
  }

  /// The stroke's centre line for a ring hugging [control], whose corners
  /// are [borderRadius]. Shared with `TvShell`'s outline so the two rings are
  /// the same shape.
  static RRect ringAround(Rect control, BorderRadius borderRadius) {
    // The stroke straddles the line it is drawn on, so the line sits half a
    // stroke outside the control for the ring's inner edge to land on it.
    const outset = Dimens.focusRingWidth / 2;
    Radius grow(Radius r) => Radius.elliptical(r.x + outset, r.y + outset);
    return RRect.fromRectAndCorners(
      control.inflate(outset),
      topLeft: grow(borderRadius.topLeft),
      topRight: grow(borderRadius.topRight),
      bottomLeft: grow(borderRadius.bottomLeft),
      bottomRight: grow(borderRadius.bottomRight),
      // A pill radius is larger than the box; scaled down it is a capsule.
    ).scaleRadii();
  }

  @override
  EdgeInsetsGeometry get padding => EdgeInsets.zero;

  // Fades in and out with the control's own animation instead of popping.
  @override
  FocusRingDecoration? lerpFrom(Decoration? a, double t) => a == null
      ? _withOpacity(t)
      : super.lerpFrom(a, t) as FocusRingDecoration?;

  @override
  FocusRingDecoration? lerpTo(Decoration? b, double t) => b == null
      ? _withOpacity(1 - t)
      : super.lerpTo(b, t) as FocusRingDecoration?;

  FocusRingDecoration _withOpacity(double t) => FocusRingDecoration(
    color: color.withValues(alpha: color.a * t.clamp(0.0, 1.0)),
    radius: radius,
  );

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _FocusRingPainter(this);

  @override
  bool operator ==(Object other) =>
      other is FocusRingDecoration &&
      other.color == color &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(color, radius);
}

class _FocusRingPainter extends BoxPainter {
  _FocusRingPainter(this.decoration);

  final FocusRingDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    canvas.drawRRect(
      FocusRingDecoration.ringAround(
        offset & size,
        BorderRadius.circular(decoration.radius),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = Dimens.focusRingWidth
        ..color = decoration.color,
    );
  }
}
