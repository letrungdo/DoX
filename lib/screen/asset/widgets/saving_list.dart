import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/model/asset/asset_saving.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SavingList extends StatelessWidget {
  const SavingList({super.key, required this.savings, this.onEdit, this.onDelete});

  final List<AssetSaving> savings;
  final void Function(AssetSaving item)? onEdit;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (savings.isEmpty) {
      return const Center(child: Text("Chưa có ghi chép tiết kiệm nào."));
    }

    return ListView.builder(
      padding: Dimens.screenPadding,
      itemCount: savings.length,
      itemBuilder: (context, index) {
        final item = savings[index];
        return _buildItem(context, item).contentConstrainedBox();
      },
    );
  }

  Widget _buildItem(BuildContext context, AssetSaving item) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final textTheme = context.textTheme;
    final monthlyInterest = item.monthlyInterest;
    final accruedInterest = item.accruedInterest;
    final currentValue = item.currentValue;

    return ChickenListTileCard(
      onTap: () => onEdit?.call(item),
      onLongPress: () => onDelete?.call(item.id),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.infoSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.account_balance_rounded, color: context.colors.info),
      ),
      title: Row(
        children: [
          Expanded(child: Text(item.bankName, style: textTheme.primary.bold)),
          Text(
            currencyFormat.format(currentValue),
            style: textTheme.primary.bold.textColor(context.colors.success),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Gửi: ${currencyFormat.format(item.amount)}",
                style: textTheme.secondary.copyWith(fontSize: 12),
              ),
              Text(
                "+${currencyFormat.format(accruedInterest)} lãi",
                style: textTheme.secondary.copyWith(fontSize: 11).textColor(context.colors.success),
              ),
            ],
          ),
          Text(
            "Lãi: ${currencyFormat.format(monthlyInterest)}/tháng · Ngày gửi: ${dateFormat.format(item.startDate)}",
            style: textTheme.secondary.copyWith(fontSize: 10),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: context.colors.successSoft,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          "${item.interestRate}%",
          style: textTheme.primary.bold.copyWith(fontSize: 11, color: context.colors.success),
        ),
      ),
    );
  }
}
