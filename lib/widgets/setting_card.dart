import 'package:do_x/constants/dimens.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';

/// One row of a settings list: a tinted icon badge, a label and whatever
/// control the setting needs (a switch, a dropdown, a chevron).
///
/// Shared so the app's settings screens stay one list broken across pages
/// rather than several lists that each look slightly different.
class SettingCard extends StatelessWidget {
  const SettingCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;

  /// Tints the icon and its badge; also the label's colour for a destructive
  /// row, where the whole line has to read as a warning.
  final Color color;

  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
          ),
          child: Icon(icon, color: color),
        ),
        title: DefaultTextStyle.merge(
          style: const TextStyle(fontWeight: FontWeight.w600),
          child: title,
        ),
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }
}
