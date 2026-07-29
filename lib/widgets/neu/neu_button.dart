import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/neu/neu_surface.dart';
import 'package:flutter/material.dart';

/// A neumorphic pill that sinks into the surface while held.
///
/// The two rims swapping on press is the affordance: without borders or
/// elevation, that flip is what tells the user the thing is a control. [accent]
/// tints the fill for primary actions; a plain button keeps the surface colour.
class NeuButton extends StatefulWidget {
  const NeuButton({
    super.key,
    required this.child,
    this.onPressed,
    this.accent,
    this.foreground,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.radius = 16,
    this.depth = 0.85,
    this.expand = false,
  });

  final Widget child;
  final VoidCallback? onPressed;

  /// Fill for primary actions. `null` keeps the shared surface colour.
  final Color? accent;

  /// Label/icon colour. Defaults to what reads on [accent] (or on the surface
  /// when there is none) — pass it when the accent is not the primary colour,
  /// e.g. a destructive action filled with `scheme.error`.
  final Color? foreground;

  final EdgeInsetsGeometry padding;
  final double radius;
  final double depth;

  /// Stretch to the parent's width, for bottom-of-sheet actions.
  final bool expand;

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final scheme = context.theme.colorScheme;
    final enabled = widget.onPressed != null;
    final borderRadius = BorderRadius.circular(widget.radius);
    final background = NeuSurface.of(context);
    final fill = widget.accent ?? neu.panelOn(background);
    final foreground = !enabled
        ? context.colors.disabled
        : widget.foreground ??
              (widget.accent == null ? scheme.onSurface : scheme.onPrimary);

    Widget content = DefaultTextStyle.merge(
      style: TextStyle(
        color: foreground,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      child: IconTheme.merge(
        data: IconThemeData(color: foreground, size: 20),
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );

    final button = GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: enabled ? fill : neu.sunken,
          borderRadius: borderRadius,
          boxShadow: !enabled
              ? null
              : neu.raisedShadows(
                  fill: fill,
                  depth: widget.depth,
                  // Held down, the rims swap: the button reads as pressed into
                  // the surface instead of losing its shadows altogether.
                  inset: _pressed,
                ),
        ),
        child: content,
      ),
    );

    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Square neumorphic icon button, for app bar actions and toolbars.
class NeuIconButton extends StatelessWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 42,
    this.iconSize = 20,
    this.color,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = NeuButton(
      onPressed: onPressed,
      radius: 14,
      depth: 0.6,
      padding: EdgeInsets.zero,
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: color ?? context.colors.iconColor,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
