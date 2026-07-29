import 'package:do_x/extensions/context_extensions.dart';
import 'package:flutter/material.dart';

/// Raised neumorphic panel — the replacement for [Card] across the app.
///
/// Keeps a Card-shaped API (`child`, `color`, `margin`, `clipBehavior`) so call
/// sites read the same, but draws a light/dark shadow pair instead of Material
/// elevation plus an outline. When [onTap] is given the panel sinks on press,
/// which is the only affordance neumorphism has left once borders are gone.
class NeuCard extends StatefulWidget {
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

  @override
  State<NeuCard> createState() => _NeuCardState();
}

class _NeuCardState extends State<NeuCard> {
  bool _pressed = false;

  bool get _tappable => widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final radius = BorderRadius.circular(widget.radius);
    // Pressing flattens the panel towards the surface rather than moving it, so
    // nothing shifts under the finger.
    final depth = _pressed ? widget.depth * 0.3 : widget.depth;

    Widget? content = widget.child;
    if (widget.padding != null) {
      content = Padding(padding: widget.padding!, child: content);
    }
    if (_tappable) {
      content = InkWell(
        borderRadius: radius,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onHighlightChanged: (value) => setState(() => _pressed = value),
        child: content,
      );
    }
    // Always a Material, even without a tap handler of our own: children often
    // bring their own InkWell/ListTile, and without one here their ink lands on
    // the nearest ancestor Material — behind this card's opaque fill, so the
    // highlight is invisible and unclipped by the rounded corners.
    content = Material(
      type: MaterialType.transparency,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      margin: widget.margin,
      clipBehavior: widget.clipBehavior,
      decoration: neu.raised(
        radius: widget.radius,
        depth: depth,
        color: widget.color,
      ),
      child: content,
    );
  }
}
