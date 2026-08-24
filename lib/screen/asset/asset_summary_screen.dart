import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/model/asset/asset_summary.dart';
import 'package:do_x/screen/asset/widgets/asset_summary_card.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

@RoutePage()
class AssetSummaryScreen extends StatefulScreen implements AutoRouteWrapper {
  const AssetSummaryScreen({super.key, required this.assetVm});

  final AssetViewModel assetVm;

  @override
  State<AssetSummaryScreen> createState() => _AssetSummaryScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: assetVm,
      child: this,
    );
  }
}

class _AssetSummaryScreenState
    extends ScreenState<AssetSummaryScreen, AssetViewModel> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return AppScaffold(
      appBar: DoAppBar(title: l10n.assetSummary),
      body: Consumer<AssetViewModel>(
        builder: (context, vm, child) {
          final summary = vm.summary;
          if (summary == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: Dimens.screenPadding,
            child: Column(
              children: [
                AssetSummaryCard(summary: summary),
                const SizedBox(height: 24),
                _buildTotalReturnRow(context, summary),
                const SizedBox(height: 24),
                _buildBreakdownItem(
                  context,
                  l10n.assetSavings,
                  summary.totalSavings,
                  currencyFormat,
                  Icons.account_balance_rounded,
                  context.colors.info,
                ),
                const SizedBox(height: 12),
                _buildBreakdownItem(
                  context,
                  l10n.assetInvestments,
                  summary.totalInvestments,
                  currencyFormat,
                  Icons.trending_up_rounded,
                  context.colors.warning,
                ),
                const SizedBox(height: 12),
                _buildBreakdownItem(
                  context,
                  l10n.assetGold,
                  summary.totalGold,
                  currencyFormat,
                  Icons.monetization_on_rounded,
                  Colors.amber,
                ),
              ],
            ).contentConstrainedBox(),
          );
        },
      ),
    );
  }

  Widget _buildTotalReturnRow(BuildContext context, AssetSummary summary) {
    final color = summary.averageAnnualReturn >= 0 
        ? context.colors.success 
        : context.colors.danger;
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: color.withValues(alpha: 0.05),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Lợi nhuận trung bình/năm", 
                  style: context.textTheme.secondary.size13,
                ),
                Text(
                  "Dựa trên tất cả các loại tài sản",
                  style: context.textTheme.secondary.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            "${summary.averageAnnualReturn >= 0 ? '+' : ''}${summary.averageAnnualReturn.toStringAsFixed(2)}%",
            style: context.textTheme.primary.bold.size20.textColor(color),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(
    BuildContext context,
    String label,
    double amount,
    NumberFormat format,
    IconData icon,
    Color color,
  ) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.textTheme.secondary.size13),
                const SizedBox(height: 2),
                Text(
                  format.format(amount),
                  style: context.textTheme.primary.bold.size16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
