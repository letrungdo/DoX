import 'package:do_x/constants/app_const.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/asset/asset_saving.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/input/cute_date_field.dart';
import 'package:do_x/widgets/input/cute_input_decoration.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class AddSavingDialog extends StatefulWidget {
  const AddSavingDialog({super.key, this.saving, this.onDelete});

  final AssetSaving? saving;
  final VoidCallback? onDelete;

  @override
  State<AddSavingDialog> createState() => _AddSavingDialogState();
}

class _AddSavingDialogState extends State<AddSavingDialog> {
  late final TextEditingController _bankController;
  late final TextEditingController _amountController;
  late final TextEditingController _rateController;
  late DateTime _startDate;

  String? _bankError;
  String? _amountError;
  String? _rateError;

  bool get _isEditing => widget.saving != null;

  @override
  void initState() {
    super.initState();
    final saving = widget.saving;
    _bankController = TextEditingController(text: saving?.bankName ?? '');
    _amountController = TextEditingController(
      text: saving?.amount.toCurrency() ?? '',
    );
    _rateController = TextEditingController(
      text: saving?.interestRate.toString() ?? '',
    );
    _startDate = saving?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _bankController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _submit(AppLocalizations l10n) {
    final bank = _bankController.text.trim();
    final amount = _amountController.text.toMoney() ?? 0;
    final rateText = _rateController.text;
    final rate = double.tryParse(rateText) ?? 0;

    setState(() {
      _bankError = bank.isEmpty ? l10n.assetErrorRequired : null;
      _amountError = amount <= 0 ? l10n.assetErrorInvalidAmount : null;
      _rateError = (rateText.isEmpty || rate <= 0)
          ? l10n.assetErrorInvalidRate
          : null;
    });

    if (_bankError != null || _amountError != null || _rateError != null) {
      return;
    }

    final saving = (widget.saving ?? AssetSaving(
      id: const Uuid().v4(),
      bankName: bank,
      amount: amount,
      interestRate: rate,
      startDate: _startDate,
    )).copyWith(
      bankName: bank,
      amount: amount,
      interestRate: rate,
      startDate: _startDate,
    );
    Navigator.pop(context, saving);
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
        TextField(
          controller: _bankController,
          textCapitalization: TextCapitalization.words,
          decoration: cuteInputDecoration(context, l10n.assetBankName)
              .copyWith(errorText: _bankError),
          onChanged: (_) {
            if (_bankError != null) setState(() => _bankError = null);
          },
        ),
        CuteMoneyField(
          controller: _amountController,
          label: l10n.assetAmount,
          maxSuggestion: AppConst.moneySuggestionHigh,
          errorText: _amountError,
          onChanged: (_) {
            if (_amountError != null) setState(() => _amountError = null);
          },
        ),
        TextField(
          controller: _rateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: cuteInputDecoration(context, l10n.assetInterestRate)
              .copyWith(errorText: _rateError),
          onChanged: (_) {
            if (_rateError != null) setState(() => _rateError = null);
          },
        ),
        CuteDateField(
          label: l10n.assetStartDate,
          value: _startDate,
          onChanged: (d) => setState(() => _startDate = d),
        ),
      ],
    );
  }
}
