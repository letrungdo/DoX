import 'package:do_x/constants/app_const.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/model/crypto/crypto_symbol.dart';
import 'package:do_x/screen/asset/widgets/asset_tile_format.dart';
import 'package:do_x/screen/asset/widgets/coin_logo.dart';
import 'package:do_x/services/binance_service.dart';
import 'package:do_x/view_model/asset_view_model.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/input/cute_date_field.dart';
import 'package:do_x/widgets/input/cute_input_decoration.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class AddInvestmentDialog extends StatefulWidget {
  const AddInvestmentDialog({
    super.key,
    this.investment,
    this.logo,
    required this.usdRate,
    this.onDelete,
  });

  final AssetInvestment? investment;

  /// The logo of the coin being edited, from the directory the list already
  /// loaded. Without it an edit opens showing the ticker while the picker
  /// right next to it shows the logo.
  final String? logo;

  /// Today's VND per USDT, offered as the rate of a holding bought today.
  final double usdRate;
  final VoidCallback? onDelete;

  @override
  State<AddInvestmentDialog> createState() => _AddInvestmentDialogState();
}

class _AddInvestmentDialogState extends State<AddInvestmentDialog> {
  /// The pair as Binance writes it, e.g. "BTCUSDT" — what the record stores.
  String? _symbol;

  /// The catalogue row behind [_symbol], when it came from the picker. Null
  /// while editing a record, where all that was kept is the pair itself.
  CryptoSymbol? _picked;

  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _rateController;
  late final TextEditingController _noteController;
  late DateTime _buyDate;

  final _binanceService = BinanceService();
  bool _loadingCoins = false;

  String? _symbolError;
  String? _quantityError;
  String? _priceError;
  String? _rateError;

  bool get _isEditing => widget.investment != null;

  /// USDT is the unit every other price is quoted in, so one of it costs one of
  /// it. Asking for that price only invites the balance to be typed twice.
  bool get _isStablecoin => _symbol == AssetFormat.usdtUnit;

  String? get _base {
    final symbol = _symbol;

    return symbol == null ? null : AssetViewModel.baseOf(symbol);
  }

  @override
  void initState() {
    super.initState();
    final inv = widget.investment;
    _symbol = inv?.symbol;
    _quantityController = TextEditingController(
      text: inv?.quantity.toString() ?? '',
    );
    _priceController = TextEditingController(
      // Not toCurrency(): that rounds to two decimals, which reads a coin
      // bought at 0.00000812 back as 0 and would save it that way.
      text: inv == null ? '' : AssetFormat().priceInput(inv.buyPrice),
    );
    _rateController = TextEditingController(
      text: (inv?.buyFxRate ?? widget.usdRate).toCurrency(),
    );
    _noteController = TextEditingController(text: inv?.note ?? '');
    _buyDate = inv?.buyDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _rateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Opens Binance's USDT catalogue as a searchable list: every pair it trades,
  /// with today's price and the coin's logo.
  Future<void> _pickCoin(AppLocalizations l10n) async {
    if (_loadingCoins) return;
    setState(() => _loadingCoins = true);

    final result = await _binanceService.getUsdtSymbols();
    if (!mounted) return;
    setState(() => _loadingCoins = false);

    final coins = result.data;
    if (coins == null || coins.isEmpty) {
      context.showToast(l10n.assetCoinLoadFailed, isError: true);
      return;
    }

    final format = AssetFormat();
    final picked = await showAppSearchSheet<CryptoSymbol>(
      context,
      title: l10n.assetCoinPick,
      options: coins,
      selected: coins.where((c) => c.symbol == _symbol).firstOrNull,
      labelBuilder: (c) => c.base,
      subtitleBuilder: (c) => [
        if (c.name != null) c.name!,
        if (c.price != null) format.usdt(c.price!),
      ].join(' · '),
      leadingBuilder: (c) => CoinLogo(base: c.base, logo: c.logo, size: 32),
      searchIndex: (c) => c.searchIndex,
      searchHint: l10n.assetCoinSearchHint,
    );
    if (picked == null) return;

    setState(() {
      // A price typed for another coin means nothing for this one, so picking a
      // different coin fills the field with what that coin costs today — which
      // is the right answer for a holding bought today and a starting point for
      // any other. Re-picking the same coin leaves what was recorded alone.
      if (picked.symbol != _symbol) {
        final price = picked.price;
        _priceController.text = price == null
            ? ''
            : AssetFormat().priceInput(price);
        _priceError = null;
      }
      _picked = picked;
      _symbol = picked.symbol;
      _symbolError = null;
    });
  }

  void _submit(AppLocalizations l10n) {
    final symbol = _symbol;
    final quantityText = _quantityController.text;
    final quantity = double.tryParse(quantityText) ?? 0;
    final price = _isStablecoin ? 1.0 : _priceController.text.toMoney() ?? 0;
    final rate = _rateController.text.toMoney() ?? 0;
    final note = _noteController.text.trim();

    setState(() {
      _symbolError = symbol == null ? l10n.assetErrorRequired : null;
      _quantityError = (quantityText.isEmpty || quantity <= 0)
          ? l10n.assetErrorInvalidQuantity
          : null;
      _priceError = price <= 0 ? l10n.assetErrorInvalidPrice : null;
      _rateError = rate <= 0 ? l10n.assetErrorInvalidRate : null;
    });

    if (symbol == null ||
        _quantityError != null ||
        _priceError != null ||
        _rateError != null) {
      return;
    }

    final investment =
        (widget.investment ??
                AssetInvestment(
                  id: const Uuid().v4(),
                  symbol: symbol,
                  type: InvestmentType.crypto,
                  quantity: quantity,
                  buyPrice: price,
                  buyDate: _buyDate,
                ))
            .copyWith(
              symbol: symbol,
              type: InvestmentType.crypto,
              quantity: quantity,
              buyPrice: price,
              buyDate: _buyDate,
              buyFxRate: rate,
              note: note.isEmpty ? null : note,
            );
    Navigator.pop(context, investment);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final base = _base;

    return CuteDialog(
      title: _isEditing ? l10n.update : l10n.assetAdd,
      confirmText: _isEditing ? l10n.update : l10n.add,
      onConfirm: () => _submit(l10n),
      destructiveText: _isEditing ? l10n.delete : null,
      onDestructive: _isEditing
          ? () {
              Navigator.pop(context);
              widget.onDelete?.call();
            }
          : null,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: base == null
              ? null
              : CoinLogo(
                  base: base,
                  logo: _picked?.logo ?? widget.logo,
                  size: 36,
                ),
          title: Text(l10n.assetSymbol),
          subtitle: Text(
            base == null
                ? l10n.assetErrorRequired
                : [base, ?_picked?.name].join(' · '),
            style: TextStyle(
              color: _symbolError != null
                  ? context.theme.colorScheme.error
                  : null,
            ),
          ),
          trailing: _loadingCoins
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_drop_down),
          onTap: () => _pickCoin(l10n),
        ),
        TextField(
          controller: _quantityController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: cuteInputDecoration(
            context,
            l10n.assetQuantity,
          ).copyWith(errorText: _quantityError),
          onChanged: (_) {
            if (_quantityError != null) setState(() => _quantityError = null);
          },
        ),
        // Always USDT: every pair this tab records is quoted in it, so there is
        // no currency to choose and nothing to re-read when the coin changes.
        if (_isStablecoin)
          Text(l10n.assetUsdtFixedPrice, style: context.textTheme.secondary)
        else
          CuteMoneyField(
            controller: _priceController,
            label: l10n.assetBuyPriceUsd,
            maxSuggestion: AppConst.moneySuggestionHigh,
            suffixText: AssetFormat.usdtUnit,
            errorText: _priceError,
            onChanged: (_) {
              if (_priceError != null) setState(() => _priceError = null);
            },
          ),
        // What the đồng cost: the coin's price alone says nothing about a gain
        // made while the currency itself moved.
        CuteMoneyField(
          controller: _rateController,
          label: l10n.assetBuyFxRate,
          hint: l10n.assetBuyFxRateHint,
          maxSuggestion: AppConst.moneySuggestionHigh,
          errorText: _rateError,
          onChanged: (_) {
            if (_rateError != null) setState(() => _rateError = null);
          },
        ),
        CuteDateField(
          label: l10n.assetBuyDate,
          value: _buyDate,
          onChanged: (d) => setState(() => _buyDate = d),
        ),
        CuteTextField(
          controller: _noteController,
          label: l10n.assetNote,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
        ),
      ],
    );
  }
}
