import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/chicken_date.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_loading_bar.dart';
import 'package:do_x/widgets/chicken_add_icon.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/input/cute_segmented_button.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/widgets/input/lunar_date_field.dart';
import 'package:flutter/material.dart';
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

class _GlobalExpensesScreenState
    extends ScreenState<GlobalExpensesScreen, ChickenViewModel> {
  String _fmt(DateTime date) =>
      ChickenDate.format(date, useLunar: vm.useLunarCalendar);
  int _selectedYear = DateTime.now().year;

  @override
  void initData() {
    super.initData();
    vm.ensureExpensesLoaded();
  }

  @override
  void onResume() {
    super.onResume();
    vm.ensureExpensesLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.commonExpenses,
        bottom: AppBarLoadingBar<ChickenViewModel>(
          selector: (vm) => vm.isExpensesLoading,
        ),
        actions: [
          IconButton(
            icon: ChickenAddIcon(icon: Assets.images.feedCute),
            onPressed: () => _showExpenseDialog(),
          ),
        ],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final years = {
            DateTime.now().year,
            ...vm.globalExpenses.map((expense) => vm.displayYear(expense.date)),
          }.toList()..sort((a, b) => b.compareTo(a));
          final expenses = vm.globalExpenses.where((expense) {
            return _selectedYear == 0 ||
                vm.displayYear(expense.date) == _selectedYear;
          }).toList()..sort((a, b) => b.date.compareTo(a.date));
          final total = expenses.fold<double>(
            0,
            (sum, expense) => sum + expense.amount,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.yearLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _selectedYear,
                      items: [
                        DropdownMenuItem(value: 0, child: Text(l10n.all)),
                        ...years.map(
                          (year) => DropdownMenuItem(
                            value: year,
                            child: Text("$year"),
                          ),
                        ),
                      ],
                      onChanged: (year) {
                        if (year != null) setState(() => _selectedYear = year);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: "${l10n.totalLabel}: ",
                                style: TextStyle(
                                  color: context
                                      .theme
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              TextSpan(
                                text: "${total.toCurrency()}đ",
                                style: TextStyle(color: context.colors.money),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => vm.loadExpenses(showLoading: true),
                  child: expenses.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: constraints.maxHeight,
                                child: vm.isExpensesLoading
                                    ? const SizedBox.shrink()
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Assets.images.feedCute.svg(
                                            width: 72,
                                            height: 72,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            vm.globalExpenses.isEmpty
                                                ? l10n.noCommonExpenses
                                                : l10n.noCommonExpensesInYear(
                                                    _selectedYear,
                                                  ),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          if (vm.globalExpenses.isEmpty) ...[
                                            const SizedBox(height: 16),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _showExpenseDialog(),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                "${_fmt(expense.date)} · ${_expenseLabel(expense.type)}",
                              ),
                              trailing: Text(
                                "${expense.amount.toCurrency()}đ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.money,
                                ),
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
      text: expense == null ? '' : expense.amount.toCurrency(),
    );
    final noteController = TextEditingController(text: expense?.note ?? '');
    var selectedType = expense?.type ?? ExpenseType.feed;
    var expenseDate = expense?.date ?? LunarCalendar.solarToLunarDateTime(DateTime.now());
    String? amountError;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: _expenseAsset(selectedType),
          title: isEditing ? l10n.editCommonExpense : l10n.addCommonExpense,
          accent: Colors.orange,
          confirmText: isEditing ? l10n.update : l10n.save,
          destructiveText: isEditing ? l10n.delete : null,
          onDestructive: isEditing
              ? () {
                  Navigator.pop(context);
                  _confirmDeleteExpense(expense);
                }
              : null,
          onConfirm: () async {
            final amount = amountController.text.toMoney() ?? 0;
            if (amount <= 0) {
              setState(() => amountError = l10n.errorEnterAmount);
              return;
            }
            try {
              final updatedExpense = Expense(
                id: expense?.id ?? const Uuid().v4(),
                type: selectedType,
                amount: amount,
                date: expenseDate,
                note: noteController.text.trim().isEmpty
                    ? null
                    : noteController.text.trim(),
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
                  SnackBar(
                    content: Text(
                      l10n.saveCommonExpenseFailed(error.toString()),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          children: [
            CuteSegmentedButton<ExpenseType>(
              segments: [
                for (final type in ExpenseType.values)
                  // Water is unused for common expenses; keep it only when
                  // editing an old record that still has it.
                  if (type != ExpenseType.water || selectedType == type)
                    ButtonSegment(
                      value: type,
                      label: Text(_expenseLabel(type)),
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
              useLunar: vm.useLunarCalendar,
              onChanged: (date) => setState(() => expenseDate = date),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteExpense(Expense expense) async {
    final l10n = AppLocalizations.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => CuteDialog(
        icon: Assets.images.feedCute,
        title: l10n.deleteCommonExpense,
        accent: Colors.red,
        confirmText: l10n.delete,
        isDestructive: true,
        onConfirm: () => Navigator.pop(context, true),
        children: [
          Text(
            l10n.confirmDeleteCommonExpense(
              _fmt(expense.date),
              '${expense.amount.toCurrency()}đ',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await vm.deleteGlobalExpense(expense.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.deleteCommonExpenseFailed(error.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  SvgGenImage _expenseAsset(ExpenseType type) {
    return switch (type) {
      ExpenseType.feed => Assets.images.feedCute,
      ExpenseType.medicine => Assets.images.medicineCute,
      ExpenseType.electricity => Assets.images.lampCute,
      ExpenseType.water => Assets.images.waterCute,
      ExpenseType.other => Assets.images.starCute,
    };
  }

  Widget _expenseSvg(ExpenseType type) {
    return _expenseAsset(type).svg(width: 30, height: 30);
  }
}
