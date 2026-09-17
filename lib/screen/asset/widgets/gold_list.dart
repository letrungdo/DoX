import 'package:auto_size_text/auto_size_text.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/model/asset/asset_gold.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GoldList extends StatelessWidget {
  const GoldList({super.key, required this.gold, this.onEdit, this.onDelete});

  final List<AssetGold> gold;
  final void Function(AssetGold item)? onEdit;
  final void Function(String id)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (gold.isEmpty) {
      return Center(child: Text(context.l10n.assetGoldEmpty));
    }

    return ListView.builder(
      padding: Dimens.screenPadding,
      itemCount: gold.length,
      itemBuilder: (context, index) {
        final item = gold[index];
        return _buildItem(context, item).contentConstrainedBox();
      },
    );
  }

  Widget _buildItem(BuildContext context, AssetGold item) {
    final vm = context.read<AssetViewModel>();
    final l10n = context.l10n;
    final textTheme = context.textTheme;
    final format = AssetFormat(Localizations.localeOf(context).toString());

    final currentValue = item.quantity * vm.getCurrentGoldPrice(item);
    final buyValue = item.quantity * item.buyPrice;
    final profitLoss = currentValue - buyValue;
    final profitPercent = buyValue > 0 ? (profitLoss / buyValue) * 100 : 0.0;
    final estimate = vm.getGoldEstimatedReturn(item);
    final profitColor = profitLoss >= 0
        ? context.colors.success
        : context.colors.danger;

    // Shared by the two halves of the detail row so they shrink together —
    // apart, each settled at its own scale and the columns came out ragged.
    final sizeGroup = AutoSizeGroup();

    return ChickenListTileCard(
      onTap: () => onEdit?.call(item),
      onLongPress: () => onDelete?.call(item.id),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
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
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AutoSizeText(
                l10n.assetEstimatedReturn(
                  format.signedCompact(estimate.perYear),
                  format.signedPercent(estimate.perYearPercent),
                  format.signedCompact(estimate.perMonth),
                  format.signedPercent(estimate.perMonthPercent),
                ),
                maxLines: 1,
                minFontSize: 8,
                overflow: TextOverflow.ellipsis,
                style: textTheme.secondary.size11.textColor(profitColor),
              ),
            ),
        ],
      ),
    );
  }
}

/// The tile's headline: what it is on the left, what it is worth on the right.
class AssetTileHeader extends StatelessWidget {
  const AssetTileHeader({super.key, required this.name, required this.value});

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.primary.bold,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: AutoSizeText(
            value,
            maxLines: 1,
            minFontSize: 11,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: textTheme.primary.bold,
          ),
        ),
      ],
    );
  }
}

/// A detail line: facts on the left, the figure they add up to on the right.
///
/// The two sides are given fixed shares of the width rather than letting the
/// left one take whatever it wants, which is what left every tile's columns
/// landing in a different place.
class AssetTileRow extends StatelessWidget {
  const AssetTileRow({
    super.key,
    required this.left,
    required this.right,
    required this.group,
    this.rightColor,
  });

  final String left;
  final String right;
  final AutoSizeGroup group;
  final Color? rightColor;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.secondary.size12;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: AutoSizeText(
              left,
              group: group,
              maxLines: 1,
              minFontSize: 8,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: AutoSizeText(
              right,
              group: group,
              maxLines: 1,
              minFontSize: 8,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: rightColor != null ? style.textColor(rightColor!) : style,
            ),
          ),
        ],
      ),
    );
  }
}
