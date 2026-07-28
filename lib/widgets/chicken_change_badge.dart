import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/services/chicken_recent_changes.dart';
import 'package:flutter/material.dart';

/// Small pill marking a record that was added ("New", red) or edited
/// ("Edited", orange) recently. Renders nothing when [change] is null, so
/// callers can drop it straight into a row.
class ChickenChangeBadge extends StatelessWidget {
  const ChickenChangeBadge(
    this.change, {
    super.key,
    this.compact = false,
    this.leading = false,
  });

  final RecordChange? change;

  /// Tighter padding/text for dense rows.
  final bool compact;

  /// Badge sits before the label instead of after it, so the margin flips side.
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final change = this.change;
    if (change == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final isNew = change == RecordChange.added;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Orange on a light tint is hard to read, so the light theme uses darker
    // shades for the text/border and keeps the tint for the fill.
    final tint = isNew ? Colors.red : Colors.orange;
    final color = isDark
        ? tint
        : (isNew ? Colors.red[800]! : Colors.orange[900]!);
    return Container(
      margin: leading
          ? const EdgeInsets.only(right: 6)
          : const EdgeInsets.only(left: 6),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        isNew ? l10n.badgeNew : l10n.badgeUpdated,
        style: TextStyle(
          fontSize: compact ? 9 : 10,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
