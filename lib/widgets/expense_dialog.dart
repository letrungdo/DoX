import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/widgets/input/cute_segmented_button.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:do_x/widgets/input/lunar_date_field.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Shared add/edit expense dialog used by both the batch detail screen and the
/// common expenses screen. [onSubmit] should return true on success (the dialog
/// closes) or false to keep it open (the caller surfaces its own error).
Future<void> showExpenseDialog(
  BuildContext context, {
  Expense? expense,
  required bool useLunar,
  required String addTitle,
  required String editTitle,
  required Future<bool> Function(Expense expense) onSubmit,
  Future<void> Function()? onDelete,
  bool allowWater = true,
}) {
  final l10n = AppLocalizations.of(context);
  final isEditing = expense != null;
  final amountController = TextEditingController(
    text: isEditing ? expense.amount.toCurrency() : '',
  );
  final noteController = TextEditingController(text: expense?.note ?? '');
  var selectedType = expense?.type ?? ExpenseType.feed;
  var expenseDate =
      expense?.date ?? LunarCalendar.solarToLunarDateTime(DateTime.now());
  String? amountError;

  return showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => CuteDialog(
        icon: _expenseAsset(selectedType),
        title: isEditing ? editTitle : addTitle,
        accent: Colors.orange,
        confirmText: isEditing ? l10n.update : l10n.save,
        destructiveText: isEditing && onDelete != null ? l10n.delete : null,
        onDestructive: isEditing && onDelete != null
            ? () {
                Navigator.pop(context);
                onDelete();
              }
            : null,
        onConfirm: () async {
          final amount = amountController.text.toMoney() ?? 0;
          if (amount <= 0) {
            setState(() => amountError = l10n.errorEnterAmount);
            return;
          }
          final result = Expense(
            id: expense?.id ?? const Uuid().v4(),
            type: selectedType,
            amount: amount,
            date: expenseDate,
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
          );
          final ok = await onSubmit(result);
          if (ok && context.mounted) Navigator.pop(context);
        },
        children: [
          CuteSegmentedButton<ExpenseType>(
            segments: [
              for (final type in ExpenseType.values)
                // Water is optional; keep it only when allowed or when editing
                // an old record that still uses it.
                if (type != ExpenseType.water ||
                    allowWater ||
                    selectedType == type)
                  ButtonSegment(
                    value: type,
                    label: Text(_expenseLabel(l10n, type)),
                  ),
            ],
            value: selectedType,
            onChanged: (value) => setState(() => selectedType = value),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: CuteMoneyField(
              controller: amountController,
              label: l10n.amountLabel,
              autofocus: !isEditing,
              errorText: amountError,
              onChanged: (_) {
                if (amountError != null) setState(() => amountError = null);
              },
            ),
          ),
          CuteTextField(controller: noteController, label: l10n.noteLabel),
          LunarDateField(
            label: l10n.expenseDate,
            value: expenseDate,
            useLunar: useLunar,
            onChanged: (date) => setState(() => expenseDate = date),
          ),
        ],
      ),
    ),
  );
}

String _expenseLabel(AppLocalizations l10n, ExpenseType type) {
  return switch (type) {
    ExpenseType.feed => l10n.expenseFeed,
    ExpenseType.medicine => l10n.expenseMedicine,
    ExpenseType.electricity => l10n.expenseElectricity,
    ExpenseType.water => l10n.expenseWater,
    ExpenseType.other => l10n.expenseOther,
  };
}

SvgGenImage _expenseAsset(ExpenseType type) {
  return switch (type) {
    ExpenseType.feed => Assets.images.feedCute,
    ExpenseType.medicine => Assets.images.medicineCute,
    ExpenseType.electricity => Assets.images.lampCute,
    ExpenseType.water => Assets.images.waterCute,
    ExpenseType.other => Assets.images.starCute,
  };
}
