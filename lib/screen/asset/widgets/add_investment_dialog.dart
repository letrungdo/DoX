import 'package:do_x/constants/app_const.dart';
import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/asset/asset_investment.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/input/cute_date_field.dart';
import 'package:do_x/widgets/input/cute_input_decoration.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class AddInvestmentDialog extends StatefulWidget {
  const AddInvestmentDialog({super.key, this.investment, this.onDelete});

  final AssetInvestment? investment;
  final VoidCallback? onDelete;

  @override
  State<AddInvestmentDialog> createState() => _AddInvestmentDialogState();
}

class _AddInvestmentDialogState extends State<AddInvestmentDialog> {
  MarketCode? _selectedCode;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late DateTime _buyDate;

  String? _codeError;
  String? _quantityError;
  String? _priceError;

  bool get _isEditing => widget.investment != null;

  @override
  void initState() {
    super.initState();
    final inv = widget.investment;
    _selectedCode = MarketCode.from(inv?.symbol);
    _quantityController = TextEditingController(
      text: inv?.quantity.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: inv?.buyPrice.toCurrency() ?? '',
    );
    _buyDate = inv?.buyDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final quantityText = _quantityController.text;
    final quantity = double.tryParse(quantityText) ?? 0;
    final price = _priceController.text.toMoney() ?? 0;

    setState(() {
      _codeError = _selectedCode == null ? l10n.assetErrorRequired : null;
      _quantityError = (quantityText.isEmpty || quantity <= 0)
          ? l10n.assetErrorInvalidQuantity
          : null;
      _priceError = price <= 0 ? l10n.assetErrorInvalidPrice : null;
    });

    if (_codeError != null || _quantityError != null || _priceError != null) {
      return;
    }

    final investment = (widget.investment ?? AssetInvestment(
      id: const Uuid().v4(),
      symbol: _selectedCode!.code,
      type: _selectedCode!.group == MarketGroup.crypto
          ? InvestmentType.crypto
          : InvestmentType.stock,
      quantity: quantity,
      buyPrice: price,
      buyDate: _buyDate,
    )).copyWith(
      symbol: _selectedCode!.code,
      type: _selectedCode!.group == MarketGroup.crypto
          ? InvestmentType.crypto
          : InvestmentType.stock,
      quantity: quantity,
      buyPrice: price,
      buyDate: _buyDate,
    );
    Navigator.pop(context, investment);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
          title: Text(l10n.assetSymbol),
          subtitle: Text(
            _selectedCode?.name ?? l10n.assetErrorRequired,
            style: TextStyle(
              color: _codeError != null
                  ? context.theme.colorScheme.error
                  : null,
            ),
          ),
          trailing: const Icon(Icons.arrow_drop_down),
          onTap: () async {
            final picked = await showAppOptionSheet<MarketCode>(
              context,
              title: l10n.marketPicker,
              options: MarketCode.values,
              selected: _selectedCode,
              labelBuilder: (m) => "${m.name} (${m.code})",
            );
            if (picked != null) {
              setState(() {
                _selectedCode = picked;
                _codeError = null;
              });
            }
          },
        ),
        TextField(
          controller: _quantityController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: cuteInputDecoration(context, l10n.assetQuantity)
              .copyWith(errorText: _quantityError),
          onChanged: (_) {
            if (_quantityError != null) setState(() => _quantityError = null);
          },
        ),
        CuteMoneyField(
          controller: _priceController,
          label: l10n.assetBuyPrice,
          maxSuggestion: AppConst.moneySuggestionHigh,
          errorText: _priceError,
          onChanged: (_) {
            if (_priceError != null) setState(() => _priceError = null);
          },
        ),
        CuteDateField(
          label: l10n.assetBuyDate,
          value: _buyDate,
          onChanged: (d) => setState(() => _buyDate = d),
        ),
      ],
    );
  }
}
