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
    this.trailing,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final double fontSize;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Icon drawn after the label — a chevron on a chip that opens a picker
  /// rather than one that toggles a filter.
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final neu = context.neu;
    final scheme = context.theme.colorScheme;
    final background = NeuSurface.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final color = isSelected
        ? Colors.white
        : (isDark ? Colors.white70 : Colors.black87);
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
        // Centres the label in the pill, which it otherwise is not.
        //
        // A line's box is the font's ascent plus its descent, and a font that
        // can write Vietnamese keeps an ascent tall enough for `Ẫ` — room
        // that `Tổng hợp` never uses. Centring that box leaves the words
        // sitting low, with a gap above them and the tail of the `ợ` against
        // the bottom edge. Pinning the box to the em square and splitting
        // what is left evenly centres the letters instead.
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );

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
      child: trailing == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                Flexible(child: text),
                Icon(trailing, size: fontSize + 5, color: color),
              ],
            ),
    );

    return NeuPress(
      onTap: onTap,
      builder: (context, pressed) =>
          Center(widthFactor: 1, heightFactor: 1, child: chip(pressed)),
    );
  }
}
