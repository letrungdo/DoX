import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/widgets/surface/app_pressable.dart';
import 'package:do_x/widgets/surface/focus_ring.dart';
import 'package:do_x/widgets/surface/surface_scope.dart';
import 'package:flutter/material.dart';

/// A flat filter chip: the neutral fill step when unselected, solid primary
/// with [ColorScheme.onPrimary] text when selected.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.fontSize = 13,
    this.radius = Dimens.radiusControlSmall,
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
    final surfaces = context.surfaces;
    final scheme = context.theme.colorScheme;
    final background = SurfaceScope.of(context);
    final fill = isSelected ? scheme.primary : surfaces.panelOn(background);
    final color = isSelected ? scheme.onPrimary : scheme.onSurfaceVariant;
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

    Widget chip(AppPressState state) => AnimatedContainer(
      duration: AppPressable.duration,
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: surfaces.stateFill(
          fill,
          content: color,
          pressed: state.pressed,
          focused: state.focused,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      foregroundDecoration: FocusRingDecoration.of(
        context,
        focused: state.focused,
        radius: radius,
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

    return AppPressable(
      onTap: onTap,
      builder: (context, state) =>
          Center(widthFactor: 1, heightFactor: 1, child: chip(state)),
    );
  }
}
