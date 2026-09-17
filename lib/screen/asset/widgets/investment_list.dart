import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/screen/asset/widgets/asset_refreshable_list.dart';
import 'package:do_x/screen/asset/widgets/asset_sell_price_bar.dart';
import 'package:do_x/screen/asset/widgets/asset_tile.dart';
import 'package:do_x/screen/asset/widgets/asset_total_bar.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:do_x/screen/asset/widgets/coin_logo.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class InvestmentList extends StatelessWidget {
  const InvestmentList({
    super.key,
    required this.investments,
    this.emptyMessage,
    this.onRefresh,
    this.onEdit,
    this.onDelete,
  });

  final List<AssetInvestment> investments;

  /// Shown instead of the stock "nothing recorded yet" line when the list is
  /// empty only because a filter narrowed it.
  final String? emptyMessage;
  final Future<void> Function()? onRefresh;
  final void Function(AssetInvestment item)? onEdit;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssetViewModel>();

    return AssetRefreshableList(
      onRefresh: onRefresh,
      emptyMessage: emptyMessage ?? context.l10n.assetInvestmentEmpty,
      // One extra row at the top: the prices everything below is valued at.
      itemCount: investments.isEmpty ? 0 : investments.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            children: [
              AssetTotalBar(
                value: investments.fold(
                  0,
                  (sum, e) =>
                      sum + e.quantity * vm.getCurrentInvestmentPrice(e),
                ),
                cost: investments.fold(
                  0,
                  (sum, e) => sum + e.quantity * vm.getBuyPriceInVnd(e),
                ),
              ),
              AssetSellPriceBar(
                prices: _sellPrices(context, vm),
                onChanged: (_, rate) => vm.setUsdRate(rate),
              ),
            ],
          );
        }

        return _buildItem(context, investments[index - 1]);
      },
    );
  }

  /// One row, and it is the exchange rate. Each coin's price comes from
  /// Binance and is not worth arguing with; the rate those prices are counted
  /// in is the one figure a person might want to set themselves — to value the
  /// portfolio at the rate their own exchange pays, say.
  List<AssetSellPrice> _sellPrices(BuildContext context, AssetViewModel vm) {
    return [
      AssetSellPrice(
        key: 'usdt_vnd',
        label: 'USDT/VND',
        caption: context.l10n.assetUsdRate,
        marketPrice: vm.marketUsdRate,
        customPrice: vm.customUsdRate,
      ),
    ];
  }

  Widget _buildItem(BuildContext context, AssetInvestment item) {
    final vm = context.read<AssetViewModel>();
    final l10n = context.l10n;
    final format = AssetFormat();

    final base = AssetViewModel.baseOf(item.symbol);
    final currentValue = item.quantity * vm.getCurrentInvestmentPrice(item);
    // The buy price is recorded in USDT; every figure below is in đồng, so it
    // is converted before it is compared.
    final buyPriceVnd = vm.getBuyPriceInVnd(item);
    final buyValue = item.quantity * buyPriceVnd;
    final profitLoss = currentValue - buyValue;
    final profitPercent = buyValue > 0 ? (profitLoss / buyValue) * 100 : 0.0;
    final profitColor = profitLoss >= 0
        ? context.colors.success
        : context.colors.danger;

    final estimate = vm.getInvestmentEstimatedReturn(item);
    final note = item.note?.trim();

    final sizeGroup = AutoSizeGroup();

    return AssetTileCard(
      onTap: () => onEdit?.call(item),
      onLongPress: () => onDelete?.call(item.id),
      leading: CoinLogo(base: base, logo: vm.cryptoAssetOf(item.symbol)?.logo),
      title: AssetTileHeader(name: base, value: format.money(currentValue)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssetTileRow(
            group: sizeGroup,
            left:
                "${format.quantity(item.quantity)}"
                " · ${format.usdt(item.buyPrice)}"
                " · ${DateFormat('dd/MM/yy').format(item.buyDate)}",
            right:
                "${format.signedCompact(profitLoss)}"
                " (${format.signedPercent(profitPercent)})",
            rightColor: profitColor,
          ),
          // A USDT price says nothing on its own to someone holding đồng, so
          // what it converts to today goes right underneath it.
          AssetTileNote(
            text: l10n.assetValueInVnd(format.compact(buyPriceVnd)),
          ),
          if (estimate != null)
            AssetTileNote(
              text: l10n.assetEstimatedReturn(
                format.signedCompact(estimate.perYear),
                format.signedPercent(estimate.perYearPercent),
                format.signedCompact(estimate.perMonth),
                format.signedPercent(estimate.perMonthPercent),
              ),
              color: profitColor,
            ),
          if (note != null && note.isNotEmpty) AssetTileNote(text: note),
        ],
      ),
    );
  }
}
