import 'package:do_x/constants/app_const.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:flutter/material.dart';

/// One kind of holding and the price everything of that kind is valued at.
class AssetSellPrice {
  const AssetSellPrice({
    required this.key,
    required this.label,
    required this.marketPrice,
    required this.customPrice,
    this.isUsd = false,
  });

  /// What the price is keyed by: a gold type, or a market symbol.
  final String key;
  final String label;

  /// Today's quote, or null when nothing quotes this kind.
  final double? marketPrice;

  /// The price typed by hand, which stands in for the quote while it is set.
  final double? customPrice;
  final bool isUsd;

  double? get price => customPrice ?? marketPrice;
  bool get isCustom => customPrice != null;
}

/// The prices the list below is valued at, one row per kind of holding.
///
/// A price belongs to a kind, not to a holding: two taels of SJC bought in
/// different years still sell for the same price today. So it is entered once,
/// up here, rather than on each record — and shown rather than hidden in a
/// dialog, because a total computed from a price nobody can see is a total
/// nobody trusts.
class AssetSellPriceBar extends StatelessWidget {
  const AssetSellPriceBar({
    super.key,
    required this.prices,
    required this.onChanged,
  });

  final List<AssetSellPrice> prices;

  /// A null price hands the kind back to the feed's quote.
  final void Function(String key, double? price) onChanged;

  @override
  Widget build(BuildContext context) {
    if (prices.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Dimens.radiusCard),
      ),
      child: Column(
        children: [
          for (final price in prices) _Row(price: price, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.price, required this.onChanged});

  final AssetSellPrice price;
  final void Function(String key, double? price) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = AssetFormat();
    final value = price.price;
    final text = value == null
        ? l10n.assetSellPriceNoQuote
        : (price.isUsd ? format.usd(value) : format.money(value));

    return InkWell(
      borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
      onTap: () => _edit(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.assetSellPriceOf(price.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.secondary.size11,
                  ),
                  Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.primary.bold,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Tag(isCustom: price.isCustom),
            // Only a price that was typed in can be handed back to the feed.
            if (price.isCustom)
              IconButton(
                tooltip: l10n.assetSellPriceReset,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.undo_rounded, size: 18),
                onPressed: () => onChanged(price.key, null),
              )
            else
              IconButton(
                tooltip: l10n.assetSellPriceEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_rounded, size: 18),
                onPressed: () => _edit(context),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final entered = await showAppModal<double>(
      context,
      builder: (_) => _SellPriceDialog(price: price),
    );
    if (entered != null) onChanged(price.key, entered);
  }
}

/// Says which of the two prices the row is showing, so "143,500,000đ" is never
/// ambiguous between what the feed says and what was typed.
class _Tag extends StatelessWidget {
  const _Tag({required this.isCustom});

  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    final color = isCustom ? scheme.tertiary : scheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Dimens.radiusPill),
      ),
      child: Text(
        isCustom
            ? context.l10n.assetSellPriceEntered
            : context.l10n.assetSellPriceMarket,
        style: context.textTheme.secondary.size11.textColor(color),
      ),
    );
  }
}

class _SellPriceDialog extends StatefulWidget {
  const _SellPriceDialog({required this.price});

  final AssetSellPrice price;

  @override
  State<_SellPriceDialog> createState() => _SellPriceDialogState();
}

class _SellPriceDialogState extends State<_SellPriceDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Starts from the price already in use, so the common edit — nudging the
    // feed's quote to what a shop actually pays — is a couple of digits rather
    // than a whole number typed from scratch.
    _controller = TextEditingController(
      text: widget.price.price?.toCurrency() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return CuteDialog(
      title: l10n.assetSellPriceOf(widget.price.label),
      confirmText: l10n.save,
      onConfirm: () {
        final value = _controller.text.toMoney() ?? 0;
        if (value <= 0) {
          setState(() => _error = l10n.assetErrorInvalidPrice);
          return;
        }
        Navigator.pop(context, value);
      },
      children: [
        CuteMoneyField(
          controller: _controller,
          label: widget.price.isUsd
              ? l10n.assetSellPriceUsd
              : l10n.assetSellPrice,
          maxSuggestion: AppConst.moneySuggestionHigh,
          suffixText: widget.price.isUsd ? r"$" : "đ",
          errorText: _error,
          autofocus: true,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
      ],
    );
  }
}
