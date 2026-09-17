import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/model/asset/asset_summary.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Height of the stacked bar that shows what share each class holds.
const _allocationBarHeight = 10.0;

/// How a stat line splits its width between what it is called and what it is
/// worth.
///
/// Fixed shares rather than "whatever the label leaves over", the same way
/// [AssetTileRow] does it: a figure sized to its own text ends wherever that
/// text happens to end, so every line's figure landed in a different place and
/// none of them reached the card's edge.
const _labelFlex = 5;
const _valueFlex = 4;

/// The portfolio's yearly rate, and what that rate is worth in đồng.
///
/// The card carries the tint of the figure it holds. That fill is one of the
/// opaque `*Soft` colours rather than `accent.withValues(...)`: a translucent
/// fill lets the neumorphic shadow pair show through the panel, which reads as
/// a smudge behind the text instead of a tint.
class AssetReturnCard extends StatelessWidget {
  const AssetReturnCard({super.key, required this.summary});

  final AssetSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final textTheme = context.textTheme;
    final format = AssetFormat();
    final positive = summary.averageAnnualReturn >= 0;
    final accent = positive ? colors.success : colors.danger;

    return NeuCard(
      // The same inset as every other card on the page: the figures down the
      // right-hand side are read as one column, and 4px of drift there is
      // visible even though the cards are separate panels.
      padding: const EdgeInsets.all(16),
      color: positive ? colors.successSoft : colors.dangerSoft,
      child: Row(
        children: [
          Expanded(
            flex: _labelFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.assetAverageAnnualReturn,
                  style: textTheme.primary.medium.size13,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.assetAverageAnnualReturnHint,
                  style: textTheme.secondary.size11,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: _valueFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  format.signedPercent(summary.averageAnnualReturn),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.primary.bold.size20.textColor(accent),
                ),
                Text(
                  l10n.assetPerYear(
                    format.signedCompact(summary.estimatedYearlyProfit),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.secondary.size11,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the portfolio is made of: a stacked bar, then a line per class with
/// its value, its share and what it has made.
class AssetAllocationCard extends StatelessWidget {
  const AssetAllocationCard({super.key, required this.summary});

  final AssetSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final classes = <(String, AssetClassStat, Color, IconData)>[
      (
        l10n.assetSavings,
        summary.savings,
        colors.info,
        Icons.account_balance_rounded,
      ),
      (
        l10n.assetInvestments,
        summary.investments,
        colors.warning,
        Icons.trending_up_rounded,
      ),
      (
        l10n.assetGold,
        summary.gold,
        Colors.amber,
        Icons.monetization_on_rounded,
      ),
    ];

    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.assetAllocation,
            style: context.textTheme.primary.bold.size15,
          ),
          const SizedBox(height: 12),
          _AllocationBar(
            segments: [
              for (final (_, stat, color, _) in classes) (stat.value, color),
            ],
          ),
          for (final (label, stat, color, icon) in classes) ...[
            const SizedBox(height: 12),
            _AllocationRow(
              label: label,
              stat: stat,
              share: summary.shareOf(stat),
              color: color,
              icon: icon,
            ),
          ],
        ],
      ),
    );
  }
}

class _AllocationBar extends StatelessWidget {
  const _AllocationBar({required this.segments});

  final List<(double, Color)> segments;

  @override
  Widget build(BuildContext context) {
    final drawn = segments.where((s) => s.$1 > 0).toList();
    if (drawn.isEmpty) {
      return Container(
        height: _allocationBarHeight,
        decoration: BoxDecoration(
          color: context.colors.disabled,
          borderRadius: BorderRadius.circular(Dimens.radiusTiny),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(Dimens.radiusTiny),
      child: SizedBox(
        height: _allocationBarHeight,
        child: Row(
          children: [
            for (final (value, color) in drawn)
              // Flex is an int, so the shares are scaled up before rounding —
              // at whole percent a class worth half a percent would vanish.
              Expanded(
                flex: (value * 100).round().clamp(1, 1 << 30),
                child: ColoredBox(color: color),
              ),
          ],
        ),
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.label,
    required this.stat,
    required this.share,
    required this.color,
    required this.icon,
  });

  final String label;
  final AssetClassStat stat;
  final double share;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final format = AssetFormat();
    final profitColor = stat.profitLoss >= 0
        ? context.colors.success
        : context.colors.danger;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: _labelFlex,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.primary.medium.size13,
              ),
              Text(
                "${l10n.assetShareOfPortfolio(format.rate(share))}"
                " · ${l10n.assetHoldingCount(stat.count)}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.secondary.size11,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: _valueFlex,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  format.money(stat.value),
                  style: textTheme.primary.bold.size15,
                ),
              ),
              Text(
                "${format.signedCompact(stat.profitLoss)}"
                " (${format.signedPercent(stat.profitLossPercent)})",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.secondary.size11.textColor(profitColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The figures that do not belong to one class: what the deposits pay over a
/// year, how many have run out, and which term ends next.
class AssetStatsCard extends StatelessWidget {
  const AssetStatsCard({super.key, required this.summary});

  final AssetSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final format = AssetFormat();
    final dateFormat = DateFormat('dd/MM/yy');
    final maturity = summary.nextMaturityDate;

    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.assetStatistics,
            style: context.textTheme.primary.bold.size15,
          ),
          const SizedBox(height: 4),
          _StatRow(
            label: l10n.assetYearlyInterest,
            value: format.money(summary.monthlyInterest * 12),
            valueColor: summary.monthlyInterest > 0 ? colors.success : null,
          ),
          _StatRow(
            label: l10n.assetCurrentValue,
            value: format.money(summary.totalAssets),
          ),
          _StatRow(
            label: l10n.assetMaturedSavings,
            value: l10n.assetHoldingCount(summary.maturedSavingsCount),
            // A matured deposit has stopped earning, so it is something to act
            // on rather than a neutral count.
            valueColor: summary.maturedSavingsCount > 0 ? colors.warning : null,
          ),
          _StatRow(
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

/// The holding making the most and the one making the least, so the page says
/// something about the picks and not only about the totals.
class AssetPerformanceCard extends StatelessWidget {
  const AssetPerformanceCard({super.key, required this.summary});

  final AssetSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final best = summary.best;
    final worst = summary.worst;
    if (best == null) return const SizedBox.shrink();

    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.assetPerformance,
            style: context.textTheme.primary.bold.size15,
          ),
          const SizedBox(height: 4),
          _PerformerRow(label: l10n.assetBestPerformer, performer: best),
          if (worst != null)
            _PerformerRow(label: l10n.assetWorstPerformer, performer: worst),
        ],
      ),
    );
  }
}

class _PerformerRow extends StatelessWidget {
  const _PerformerRow({required this.label, required this.performer});

  final String label;
  final AssetPerformer performer;

  @override
  Widget build(BuildContext context) {
    final format = AssetFormat();
    final color = performer.profitLoss >= 0
        ? context.colors.success
        : context.colors.danger;

    return _StatRow(
      label: "$label · ${performer.name}",
      value: format.signedPercent(performer.profitLossPercent),
      note: format.signedCompact(performer.profitLoss),
      valueColor: color,
    );
  }
}

/// One label/figure line inside a stats card.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.note,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? note;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    final valueStyle = textTheme.primary.bold.size13;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: _labelFlex,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.secondary.size13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: _valueFlex,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  maxLines: 2,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: valueColor == null
                      ? valueStyle
                      : valueStyle.textColor(valueColor!),
                ),
                if (note != null)
                  Text(
                    note!,
                    maxLines: 1,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.secondary.size11,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
