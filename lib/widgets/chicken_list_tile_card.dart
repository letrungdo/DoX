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
  });

  final Widget title;
  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: contentPadding,
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
