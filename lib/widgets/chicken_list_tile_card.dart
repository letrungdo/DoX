import 'package:flutter/material.dart';

/// A shared rounded card for chicken feature lists.
///
/// Clipping at the [Card] level keeps ListTile's tap and long-press ink
/// highlights inside the card's rounded shape.
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
    this.borderColor,
  });

  final Widget title;
  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  /// Outline that replaces the card theme's neutral one. Used with [color] so a
  /// tinted card is framed in its own hue instead of a grey that muddies it.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      color: color,
      shape: borderColor == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor!),
            ),
      elevation: borderColor == null ? null : 0,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: contentPadding,
        minVerticalPadding: 4,
        visualDensity: const VisualDensity(vertical: -1),
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
