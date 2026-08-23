import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/record_change.dart';
import 'package:do_x/theme/text_theme.dart';
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
    final colors = context.colors;
    // The accent is already picked per theme (deep in light, bright in dark),
    // and its soft fill is opaque so the pill keeps its hue on tinted cards.
    final color = isNew ? colors.danger : colors.warning;
    final tint = isNew ? colors.dangerSoft : colors.warningSoft;
    return Container(
      margin: leading
          ? const EdgeInsets.only(right: 6)
          : const EdgeInsets.only(left: 6),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(Dimens.radiusSmall),
      ),
      child: Text(
        isNew ? l10n.badgeNew : l10n.badgeUpdated,
        style: DoTextTheme.pill.copyWith(
          fontSize: compact ? 9 : 10,
          color: color,
        ),
      ),
    );
  }
}
