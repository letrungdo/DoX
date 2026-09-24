import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/model/asset/asset_summary.dart';
import 'package:do_x/screen/asset/widgets/asset_summary_stats.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:do_x/widgets/surface/app_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The page's headline: everything held, what it cost, and what it has made —
/// followed by the figures that belong to no single class.
///
/// The statistics used to sit in a card of their own, which put the portfolio's
/// value in two places and left the reader hopping between panels to put one
/// figure beside another. One card, one column of figures.
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
    final dateFormat = DateFormat('dd/MM/yy');
    final maturity = summary.nextMaturityDate;

    return AppCard(
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
          const Divider(height: 24),
          AssetStatRow(
            label: l10n.assetCostBasis,
            value: format.money(summary.totalCost),
          ),
          AssetStatRow(
            label: l10n.assetAvgMonthlyInterest,
            value: format.money(summary.monthlyProfit),
            valueColor: summary.monthlyProfit >= 0
                ? colors.success
                : colors.danger,
          ),
          AssetStatRow(
            label: l10n.assetYearlyInterest,
            value: format.money(summary.monthlyInterest * 12),
            valueColor: summary.monthlyInterest > 0 ? colors.success : null,
          ),
          AssetStatRow(
            label: l10n.assetMaturedSavings,
            value: l10n.assetHoldingCount(summary.maturedSavingsCount),
            // A matured deposit has stopped earning, so it is something to act
            // on rather than a neutral count.
            valueColor: summary.maturedSavingsCount > 0 ? colors.warning : null,
          ),
          AssetStatRow(
            label: l10n.assetNextMaturity,
            value: maturity == null
                ? l10n.assetNotAvailable
                : "${summary.nextMaturityBank} · ${dateFormat.format(maturity)}",
            note: maturity == null
                ? null
                : l10n.assetDaysLeft(
                    maturity.difference(DateTime.now()).inDays,
                  ),
          ),
        ],
      ),
    );
  }
}
