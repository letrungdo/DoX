import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/neu/neu_press.dart';
import 'package:do_x/widgets/neu/neu_surface.dart';
import 'package:flutter/material.dart';

/// Raised neumorphic panel — the replacement for [Card] across the app.
///
/// Keeps a Card-shaped API (`child`, `color`, `margin`, `clipBehavior`) so call
/// sites read the same, but draws a light/dark shadow pair instead of Material
/// elevation plus an outline. When [onTap] is given the panel sinks on press,
/// which is the only affordance neumorphism has left once borders are gone.
class NeuCard extends StatelessWidget {
  const NeuCard({
    super.key,
    this.child,
    this.color,
    this.margin,
    this.padding,
    this.radius = 18,
    this.depth = 1,
    this.onTap,
    this.onLongPress,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget? child;

  /// Fill that replaces the shared surface colour, for cards that carry a
  /// semantic tint (`colors.successSoft` and friends). This is how a card shows
  /// state — neumorphic panels have no border to tint.
  final Color? color;

  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double depth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Clip clipBehavior;

  bool get _tappable => onTap != null || onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final borderRadius = BorderRadius.circular(radius);
    // What this card is drawn on: an untinted card takes that colour, so one
    // nested in a tinted card stays in the card's colour rather than the page's.
    final background = NeuSurface.of(context);
    final fill = color ?? neu.panelOn(background);

    Widget? content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }
    // Always a Material, even without a tap handler of our own: children often
    // bring their own InkWell/ListTile, and without one here their ink lands on
    // the nearest ancestor Material — behind this card's opaque fill, so the
    // highlight is invisible and unclipped by the rounded corners.
    content = Material(
      type: MaterialType.transparency,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    Widget panel(bool pressed) => AnimatedContainer(
      duration: NeuPress.duration,
      curve: Curves.easeOut,
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: neu.raised(
        radius: radius,
        // Held down, the lift goes to nothing and the panel settles flat into
        // the page — the same press `flutter_neumorphic` draws.
        depth: pressed ? 0 : depth,
        color: color,
        background: background,
      ),
      // Cards nested in this one sit on its fill, not on the scaffold.
      child: NeuSurface(color: fill, child: content!),
    );

    if (!_tappable) return panel(false);

    // A card is a wide surface, so it shrinks less than a button would: the
    // same 3% here reads as the whole panel lurching.
    return NeuPress(
      pressedScale: 0.99,
      onTap: onTap,
      onLongPress: onLongPress,
      builder: (context, pressed) => panel(pressed),
    );
  }
}
