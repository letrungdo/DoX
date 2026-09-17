import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/model/asset/asset_saving.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:do_x/screen/asset/widgets/asset_refreshable_list.dart';
import 'package:do_x/screen/asset/widgets/asset_tile.dart';
import 'package:do_x/screen/asset/widgets/bank_logo.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SavingList extends StatelessWidget {
  const SavingList({
    super.key,
    required this.savings,
    this.emptyMessage,
    this.onRefresh,
    this.onEdit,
    this.onDelete,
  });

  final List<AssetSaving> savings;

  /// Shown instead of the stock "nothing recorded yet" line when the list is
  /// empty only because a filter narrowed it.
  final String? emptyMessage;
  final Future<void> Function()? onRefresh;
  final void Function(AssetSaving item)? onEdit;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    // Watched, not read: the directory that backs the logos lands a moment
    // after the deposits do.
    context.watch<AssetViewModel>();

    return AssetRefreshableList(
      onRefresh: onRefresh,
      emptyMessage: emptyMessage ?? context.l10n.assetSavingEmpty,
      itemCount: savings.length,
      itemBuilder: (context, index) => _buildItem(context, savings[index]),
    );
  }

  Widget _buildItem(BuildContext context, AssetSaving item) {
    final vm = context.read<AssetViewModel>();
    final l10n = context.l10n;
    final format = AssetFormat();
    final dateFormat = DateFormat('dd/MM/yy');

    final accruedInterest = item.accruedInterest;
    final accruedPercent = item.amount > 0
        ? (accruedInterest / item.amount) * 100
        : 0.0;
    final maturity = item.maturityDate;
    final logo = vm.bankOf(item.bankName)?.logo;
    final sizeGroup = AutoSizeGroup();

    // A matured deposit is no longer earning, so its figures keep the row's
    // default ink: green here would claim a return it is not making.
    final interestColor = item.isMatured ? null : context.colors.success;
    final note = item.note?.trim();

    return AssetTileCard(
      onTap: () => onEdit?.call(item),
      onLongPress: () => onDelete?.call(item.id),
      title: AssetTileHeader(
        name: item.bankName,
        // A logo is read at a glance where a name has to be read word by word.
        nameChild: logo == null ? null : BankLogo(logo: logo, size: 22),
        value: format.money(item.currentValue),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssetTileRow(
            group: sizeGroup,
            left:
                "${format.compact(item.amount)}"
                " · ${l10n.assetRatePerYear(format.rate(item.interestRate))}"
                " · ${dateFormat.format(item.startDate)}",
            right:
                "${format.signedCompact(accruedInterest)}"
                " (${format.signedPercent(accruedPercent)})",
            rightColor: interestColor,
          ),
          AssetTileNote(
            text: item.isMatured && maturity != null
                ? l10n.assetMaturedOn(dateFormat.format(maturity))
                : l10n.assetPerMonth(
                    format.signedCompact(item.monthlyInterest),
                  ),
            color: interestColor,
          ),
          if (note != null && note.isNotEmpty) AssetTileNote(text: note),
        ],
      ),
    );
  }
}
