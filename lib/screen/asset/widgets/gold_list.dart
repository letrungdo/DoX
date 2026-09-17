import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/asset/asset_gold.dart';
import 'package:do_x/screen/asset/widgets/asset_refreshable_list.dart';
import 'package:do_x/screen/asset/widgets/asset_sell_price_bar.dart';
import 'package:do_x/screen/asset/widgets/asset_tile.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GoldList extends StatelessWidget {
  const GoldList({
    super.key,
    required this.gold,
    this.emptyMessage,
    this.onRefresh,
    this.onEdit,
    this.onDelete,
  });

  final List<AssetGold> gold;

  /// Shown instead of the stock "nothing recorded yet" line when the list is
  /// empty only because a filter narrowed it.
  final String? emptyMessage;
  final Future<void> Function()? onRefresh;
  final void Function(AssetGold item)? onEdit;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AssetViewModel>();

    return AssetRefreshableList(
      onRefresh: onRefresh,
      emptyMessage: emptyMessage ?? context.l10n.assetGoldEmpty,
      // One extra row at the top: the prices everything below is valued at.
      itemCount: gold.isEmpty ? 0 : gold.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return AssetSellPriceBar(
            prices: _sellPrices(vm),
            onChanged: vm.setGoldSellPrice,
          );
        }

        return _buildItem(context, gold[index - 1]);
      },
    );
  }

  /// One row per kind of gold actually held, in the order it first appears.
  List<AssetSellPrice> _sellPrices(AssetViewModel vm) {
    final types = <String>{for (final item in gold) item.goldType};

    return [
      for (final type in types)
        AssetSellPrice(
          key: type,
          label: type,
          marketPrice: vm.marketGoldPrice(type),
          customPrice: vm.goldSellPrice(type),
        ),
    ];
  }

  Widget _buildItem(BuildContext context, AssetGold item) {
    final vm = context.read<AssetViewModel>();
    final l10n = context.l10n;
    final format = AssetFormat();

    final currentValue = item.quantity * vm.getCurrentGoldPrice(item);
    final buyValue = item.quantity * item.buyPrice;
    final profitLoss = currentValue - buyValue;
    final profitPercent = buyValue > 0 ? (profitLoss / buyValue) * 100 : 0.0;
    final estimate = vm.getGoldEstimatedReturn(item);
    final note = item.note?.trim();
    final profitColor = profitLoss >= 0
        ? context.colors.success
        : context.colors.danger;

    // Shared by the two halves of the detail row so they shrink together —
    // apart, each settled at its own scale and the columns came out ragged.
    final sizeGroup = AutoSizeGroup();

    return AssetTileCard(
      onTap: () => onEdit?.call(item),
      onLongPress: () => onDelete?.call(item.id),
      leading: AssetTileBadge(
        color: Colors.amber.withValues(alpha: 0.1),
        child: const Icon(Icons.monetization_on_rounded, color: Colors.amber),
      ),
      title: AssetTileHeader(
        name: item.goldType,
        value: format.money(currentValue),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssetTileRow(
            group: sizeGroup,
            left:
                "${format.quantity(item.quantity)} ${l10n.assetUnitTael}"
                " · ${format.compact(item.buyPrice)}"
                " · ${DateFormat('dd/MM/yy').format(item.buyDate)}",
            right:
                "${format.signedCompact(profitLoss)}"
                " (${format.signedPercent(profitPercent)})",
            rightColor: profitColor,
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
