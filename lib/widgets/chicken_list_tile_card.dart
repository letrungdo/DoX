import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';

/// A shared rounded card for chicken feature lists.
///
/// Taps are handled by the surrounding [NeuCard] rather than the [ListTile], so
/// the whole panel sinks while held — the neumorphic press cue — instead of only
/// the tile showing an ink highlight.
class ChickenListTileCard extends StatelessWidget {
  const ChickenListTileCard({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.margin,
    this.contentPadding,
    this.onTap,
    this.onLongPress,
    this.color,
  });

  final Widget title;
  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  /// Tint that carries the row's state. Neumorphic cards have no border, so the
  /// fill is the only place that signal can live.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      margin: margin,
      color: color,
      radius: 16,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ListTile(
        contentPadding: contentPadding,
        minVerticalPadding: 4,
        visualDensity: const VisualDensity(vertical: -1),
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }
}
