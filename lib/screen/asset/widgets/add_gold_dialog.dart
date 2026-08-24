import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/asset/asset_gold.dart';
import 'package:do_x/model/asset/gold_type.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/input/cute_date_field.dart';
import 'package:do_x/widgets/input/cute_input_decoration.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/constants/app_const.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class AddGoldDialog extends StatefulWidget {
  const AddGoldDialog({super.key, this.gold, this.onDelete});

  final AssetGold? gold;
  final VoidCallback? onDelete;

  @override
  State<AddGoldDialog> createState() => _AddGoldDialogState();
}

class _AddGoldDialogState extends State<AddGoldDialog> {
  GoldAssetType? _selectedType;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late DateTime _buyDate;

  String? _typeError;
  String? _quantityError;
  String? _priceError;

  bool get _isEditing => widget.gold != null;

  @override
  void initState() {
    super.initState();
    final gold = widget.gold;
    _selectedType = GoldAssetType.fromLabel(gold?.goldType);
    _quantityController = TextEditingController(
      text: gold?.quantity.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: gold?.buyPrice.toCurrency() ?? '',
    );
    _buyDate = gold?.buyDate ?? DateTime.now();
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
      _typeError = _selectedType == null ? l10n.assetErrorRequired : null;
      _quantityError = (quantityText.isEmpty || quantity <= 0)
          ? l10n.assetErrorInvalidQuantity
          : null;
      _priceError = price <= 0 ? l10n.assetErrorInvalidPrice : null;
    });

    if (_typeError != null || _quantityError != null || _priceError != null) {
      return;
    }

    final gold = (widget.gold ?? AssetGold(
      id: const Uuid().v4(),
      goldType: _selectedType!.label,
      quantity: quantity,
      buyPrice: price,
      buyDate: _buyDate,
    )).copyWith(
      goldType: _selectedType!.label,
      quantity: quantity,
      buyPrice: price,
      buyDate: _buyDate,
    );
    Navigator.pop(context, gold);
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
          title: Text(l10n.assetGoldType),
          subtitle: Text(
            _selectedType?.label ?? l10n.assetErrorRequired,
            style: TextStyle(
              color: _typeError != null
                  ? context.theme.colorScheme.error
                  : null,
            ),
          ),
          trailing: const Icon(Icons.arrow_drop_down),
          onTap: () async {
            final picked = await showAppOptionSheet<GoldAssetType>(
              context,
              title: "Chọn loại vàng",
              options: GoldAssetType.values,
              selected: _selectedType,
              labelBuilder: (t) => t.label,
            );
            if (picked != null) {
              setState(() {
                _selectedType = picked;
                _typeError = null;
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
