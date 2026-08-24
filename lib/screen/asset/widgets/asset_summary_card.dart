import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/model/asset/asset_summary.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AssetSummaryCard extends StatelessWidget {
  const AssetSummaryCard({super.key, required this.summary});

  final AssetSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final scheme = context.theme.colorScheme;
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return Card(
      elevation: 0,
      color: scheme.primaryContainer.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Dimens.radiusCard),
        side: BorderSide(color: scheme.primaryContainer.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Tổng tài sản",
              style: textTheme.secondary.size13,
            ),
            const SizedBox(height: 4),
            Text(
              currencyFormat.format(summary.totalAssets),
              style: textTheme.primary.bold.size20.textColor(scheme.primary),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMinorStat(
                  context,
                  "Lãi tháng",
                  currencyFormat.format(summary.monthlyInterest),
                  colors.success,
                ),
                _buildMinorStat(
                  context,
                  "Lợi nhuận/Lỗ",
                  currencyFormat.format(summary.totalProfitLoss),
                  summary.totalProfitLoss >= 0 ? colors.success : colors.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinorStat(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    final textTheme = context.textTheme;
    return Column(
      children: [
        Text(label, style: textTheme.secondary.size13),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.primary.bold.textColor(valueColor),
        ),
      ],
    );
  }
}
