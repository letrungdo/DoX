import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/neu/neu_press.dart';
import 'package:do_x/widgets/neu/neu_surface.dart';
import 'package:flutter/material.dart';

class NeuChip extends StatelessWidget {
  const NeuChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.fontSize = 13,
    this.radius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double fontSize;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final scheme = context.theme.colorScheme;
    final background = NeuSurface.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget chip(bool pressed) => AnimatedContainer(
      duration: NeuPress.duration,
      padding: padding,
      decoration: neu.raised(
        radius: radius,
        // Held down, the lift goes to nothing and the chip settles flat into
        // the page — the same press every other neu surface shows.
        depth: pressed ? 0 : 0.6,
        color: isSelected ? scheme.primary : null,
        background: background,
        inset: isSelected,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
        ),
      ),
    );

    return NeuPress(
      onTap: onTap,
      builder: (context, pressed) =>
          Center(widthFactor: 1, heightFactor: 1, child: chip(pressed)),
    );
  }
}
