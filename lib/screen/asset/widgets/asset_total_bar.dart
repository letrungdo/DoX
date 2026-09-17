import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:flutter/material.dart';

/// What the list below adds up to.
///
/// It is computed from the rows actually shown, so narrowing the year narrows
/// the total with it — a total that ignored the filter would quietly answer a
/// different question from the one on screen.
class AssetTotalBar extends StatelessWidget {
  const AssetTotalBar({
    super.key,
    required this.value,
    required this.cost,
    this.profitCaption,
  });

  /// What the holdings are worth today, in VND.
  final double value;

  /// What they cost — for a deposit, the principal, so the "profit" line is
  /// the interest it has earned.
  final double cost;
  final String? profitCaption;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = AssetFormat();
    final profit = value - cost;
    final percent = cost > 0 ? (profit / cost) * 100 : 0.0;
    final color = profit >= 0 ? context.colors.success : context.colors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Dimens.radiusCard),
      ),
      child: Column(
        children: [
          _row(
            context,
            caption: l10n.assetCurrentValue,
            text: format.money(value),
            style: context.textTheme.primary.bold,
          ),
          const SizedBox(height: 2),
          _row(
            context,
            caption: profitCaption ?? l10n.assetProfitLoss,
            text:
                "${format.signedCompact(profit)}"
                " (${format.signedPercent(percent)})",
            style: context.textTheme.secondary.size12.textColor(color),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String caption,
    required String text,
    required TextStyle style,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.secondary.size12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AutoSizeText(
            text,
            maxLines: 1,
            minFontSize: 10,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
