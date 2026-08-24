import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class InvestmentList extends StatelessWidget {
  const InvestmentList({super.key, required this.investments, this.onEdit, this.onDelete});

  final List<AssetInvestment> investments;
  final void Function(AssetInvestment item)? onEdit;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (investments.isEmpty) {
      return const Center(child: Text("Chưa có ghi chép đầu tư nào."));
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
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final textTheme = context.textTheme;
    
    final currentPrice = vm.getCurrentInvestmentPrice(item);
    final currentValue = item.quantity * currentPrice;
    final buyValue = item.quantity * item.buyPrice;
    final profitLoss = currentValue - buyValue;
    final profitPercent = buyValue > 0 ? (profitLoss / buyValue) * 100 : 0.0;

    return ChickenListTileCard(
      onTap: () => onEdit?.call(item),
      onLongPress: () => onDelete?.call(item.id),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: item.type == InvestmentType.crypto 
            ? Colors.orange.withValues(alpha: 0.1) 
            : Colors.blue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Text(
          item.type == InvestmentType.crypto ? 'C' : 'S',
          style: TextStyle(
            color: item.type == InvestmentType.crypto ? Colors.orange : Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(child: Text(item.symbol, style: textTheme.primary.bold)),
          Text(
            currencyFormat.format(currentValue),
            style: textTheme.primary.bold.textColor(
              profitLoss >= 0 ? context.colors.success : context.colors.danger,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AutoSizeText(
                  "SL: ${item.quantity} - Giá: ${currencyFormat.format(item.buyPrice)}",
                  style: textTheme.secondary.copyWith(fontSize: 12),
                  maxLines: 1,
                  minFontSize: 9,
                ),
              ),
              const SizedBox(width: 4),
              AutoSizeText(
                "${profitLoss >= 0 ? '+' : ''}${currencyFormat.format(profitLoss)} (${profitPercent.toStringAsFixed(2)}%)",
                style: textTheme.secondary.copyWith(fontSize: 11).textColor(
                  profitLoss >= 0 ? context.colors.success : context.colors.danger,
                ),
                maxLines: 1,
                minFontSize: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
