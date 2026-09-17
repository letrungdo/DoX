import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:do_x/screen/asset/widgets/gold_list.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class InvestmentList extends StatelessWidget {
  const InvestmentList({
    super.key,
    required this.investments,
    this.onEdit,
    this.onDelete,
  });

  final List<AssetInvestment> investments;
  final void Function(AssetInvestment item)? onEdit;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (investments.isEmpty) {
      return Center(child: Text(context.l10n.assetInvestmentEmpty));
    }

    return ListView.builder(
      padding: Dimens.screenPadding,
      itemCount: investments.length,
      itemBuilder: (context, index) {
        final item = investments[index];
        return _buildItem(context, item).contentConstrainedBox();
      },
    );
  }

  Widget _buildItem(BuildContext context, AssetInvestment item) {
    final vm = context.read<AssetViewModel>();
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final format = AssetFormat(Localizations.localeOf(context).toString());

    final isUsdQuoted = MarketCode.from(item.symbol)?.isUsdQuoted ?? false;
    final currentValue = item.quantity * vm.getCurrentInvestmentPrice(item);
    // The buy price of a dollar-quoted market is stored in dollars; every
    // figure below is in đồng, so it is converted before it is compared.
    final buyPriceVnd = vm.getBuyPriceInVnd(item);
    final buyValue = item.quantity * buyPriceVnd;
    final profitLoss = currentValue - buyValue;
    final profitPercent = buyValue > 0 ? (profitLoss / buyValue) * 100 : 0.0;
    final profitColor = profitLoss >= 0
        ? context.colors.success
        : context.colors.danger;

    final isCrypto = item.type == InvestmentType.crypto;
    final badgeColor = isCrypto ? Colors.orange : Colors.blue;
    final sizeGroup = AutoSizeGroup();

    return ChickenListTileCard(
      onTap: () => onEdit?.call(item),
      onLongPress: () => onDelete?.call(item.id),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Text(
          isCrypto ? 'C' : 'S',
          style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
        ),
      ),
      title: AssetTileHeader(
        name: item.symbol,
        value: format.money(currentValue),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssetTileRow(
            group: sizeGroup,
            left:
                "${format.quantity(item.quantity)}"
                " · ${isUsdQuoted ? format.usd(item.buyPrice) : format.compact(item.buyPrice)}"
                " · ${DateFormat('dd/MM/yy').format(item.buyDate)}",
            right:
                "${format.signedCompact(profitLoss)}"
                " (${format.signedPercent(profitPercent)})",
            rightColor: profitColor,
          ),
          // A dollar price says nothing on its own to someone holding đồng, so
          // what it converts to today goes right underneath it.
          if (isUsdQuoted)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AutoSizeText(
                l10n.assetValueInVnd(format.compact(buyPriceVnd)),
                maxLines: 1,
                minFontSize: 8,
                overflow: TextOverflow.ellipsis,
                style: textTheme.secondary.size11,
              ),
            ),
        ],
      ),
    );
  }
}
