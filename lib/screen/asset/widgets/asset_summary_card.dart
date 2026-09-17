import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/model/asset/asset_summary.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';

/// The page's headline: everything held, what it cost, and what it has made.
class AssetSummaryCard extends StatelessWidget {
  const AssetSummaryCard({super.key, required this.summary});

  final AssetSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = context.textTheme;
    final format = AssetFormat();
    final profit = summary.totalProfitLoss;
    final profitColor = profit >= 0 ? colors.success : colors.danger;

    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(l10n.assetTotal, style: textTheme.secondary.size13),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              format.money(summary.totalAssets),
              style: textTheme.primary.bold.size24.textColor(colors.money),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${format.signedCompact(profit)}"
            " (${format.signedPercent(summary.totalProfitLossPercent)})",
            style: textTheme.primary.bold.size13.textColor(profitColor),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MinorStat(
                  label: l10n.assetCostBasis,
                  value: format.money(summary.totalCost),
                ),
              ),
              Expanded(
                child: _MinorStat(
                  label: l10n.assetMonthlyInterest,
                  value: format.money(summary.monthlyInterest),
                  valueColor: summary.monthlyInterest > 0
                      ? colors.success
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MinorStat extends StatelessWidget {
  const _MinorStat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final style = textTheme.primary.bold.size15;

    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.secondary.size13,
        ),
        const SizedBox(height: 2),
        FittedBox(
          child: Text(
            value,
            style: valueColor == null ? style : style.textColor(valueColor!),
          ),
        ),
      ],
    );
  }
}
