import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

@RoutePage()
class GlobalExpensesScreen extends StatefulScreen implements AutoRouteWrapper {
  const GlobalExpensesScreen({super.key});

  @override
  State<GlobalExpensesScreen> createState() => _GlobalExpensesScreenState();

  @override
  Widget wrappedRoute(BuildContext context) => this;
}

class _GlobalExpensesScreenState extends ScreenState<GlobalExpensesScreen, ChickenViewModel> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.commonExpenses,
        actions: [IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _showExpenseDialog())],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final years = {DateTime.now().year, ...vm.globalExpenses.map((expense) => expense.date.year)}.toList()
            ..sort((a, b) => b.compareTo(a));
          final expenses = vm.globalExpenses.where((expense) {
            return _selectedYear == 0 || expense.date.year == _selectedYear;
          }).toList()..sort((a, b) => b.date.compareTo(a.date));
          final total = expenses.fold<double>(0, (sum, expense) => sum + expense.amount);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.yearLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _selectedYear,
                      items: [
                        DropdownMenuItem(value: 0, child: Text(l10n.all)),
                        ...years.map((year) => DropdownMenuItem(value: year, child: Text("$year"))),
                      ],
                      onChanged: (year) {
                        if (year != null) setState(() => _selectedYear = year);
                      },
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          l10n.totalAmount("${total.toCurrency()}đ"),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: vm.refreshData,
                  child: expenses.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: constraints.maxHeight,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Assets.images.feedCute.svg(width: 72, height: 72),
                                    const SizedBox(height: 16),
                                    Text(
                                      vm.globalExpenses.isEmpty
                                          ? l10n.noCommonExpenses
                                          : l10n.noCommonExpensesInYear(_selectedYear),
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    if (vm.globalExpenses.isEmpty) ...[
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () => _showExpenseDialog(),
                                        child: Text(l10n.addFirstExpense),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: expenses.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final expense = expenses[index];
                            return ChickenListTileCard(
                              onTap: () => _showExpenseDialog(expense),
                              leading: _expenseSvg(expense.type),
                              title: Text(
                                expense.note ?? _expenseLabel(expense.type),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text("${_dateFormat.format(expense.date)} · ${_expenseLabel(expense.type)}"),
                              trailing: Text(
                                "${expense.amount.toCurrency()}đ",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ).webConstrainedBox();
        },
      ),
    );
  }

  void _showExpenseDialog([Expense? expense]) {
    final l10n = AppLocalizations.of(context);
    final isEditing = expense != null;
    final amountController = TextEditingController(
      text: expense == null
          ? ''
          : expense.amount == expense.amount.truncateToDouble()
          ? expense.amount.toStringAsFixed(0)
          : expense.amount.toString(),
    );
    final noteController = TextEditingController(text: expense?.note ?? '');
    var selectedType = expense?.type ?? ExpenseType.feed;
    var expenseDate = expense?.date ?? DateTime.now();

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.feedCute,
          title: isEditing ? l10n.editCommonExpense : l10n.addCommonExpense,
          accent: Colors.orange,
          confirmText: isEditing ? l10n.update : l10n.save,
          onConfirm: () async {
            final amount = double.tryParse(amountController.text) ?? 0;
            if (amount <= 0) return;
            try {
              final updatedExpense = Expense(
                id: expense?.id ?? const Uuid().v4(),
                type: selectedType,
                amount: amount,
                date: expenseDate,
                note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
              );
              if (isEditing) {
                await vm.updateGlobalExpense(updatedExpense);
              } else {
                await vm.addGlobalExpense(updatedExpense);
              }
              if (context.mounted) Navigator.pop(context);
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(l10n.saveCommonExpenseFailed(error.toString())), backgroundColor: Colors.red),
                );
              }
            }
          },
          children: [
            DropdownButtonFormField<ExpenseType>(
              initialValue: selectedType,
              items: ExpenseType.values.map((type) {
                return DropdownMenuItem(value: type, child: Text(_expenseLabel(type)));
              }).toList(),
              onChanged: (value) => setState(() => selectedType = value!),
              decoration: cuteInputDecoration(context, l10n.expenseType),
              borderRadius: BorderRadius.circular(14),
            ),
            CuteTextField(
              controller: amountController,
              label: l10n.amountLabel,
              prefixText: "đ ",
              keyboardType: TextInputType.number,
            ),
            CuteTextField(controller: noteController, label: l10n.noteLabel),
            CuteDateField(
              label: l10n.expenseDate,
              value: expenseDate,
              onChanged: (date) => setState(() => expenseDate = date),
            ),
          ],
        ),
      ),
    );
  }

  String _expenseLabel(ExpenseType type) {
    final l10n = AppLocalizations.of(context);
    return switch (type) {
      ExpenseType.feed => l10n.expenseFeed,
      ExpenseType.medicine => l10n.expenseMedicine,
      ExpenseType.electricity => l10n.expenseElectricity,
      ExpenseType.water => l10n.expenseWater,
      ExpenseType.other => l10n.expenseOther,
    };
  }

  Widget _expenseSvg(ExpenseType type) {
    final asset = switch (type) {
      ExpenseType.feed => Assets.images.feedCute,
      ExpenseType.medicine => Assets.images.medicineCute,
      ExpenseType.electricity => Assets.images.lampCute,
      ExpenseType.water => Assets.images.waterCute,
      ExpenseType.other => Assets.images.starCute,
    };
    return asset.svg(width: 30, height: 30);
  }
}
