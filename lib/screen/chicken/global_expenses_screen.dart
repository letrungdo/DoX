import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/chicken_date.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_loading_bar.dart';
import 'package:do_x/widgets/input/year_filter.dart';
import 'package:do_x/widgets/chicken_add_icon.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/expense_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls the list to the top after a new record is added (it sorts to the
  /// top). Waits a frame so the new item is laid out first.
  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

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
          }).toList();
          // Stable sort by date desc so that, for the same date, the most
          // recently added record (kept at the front of the source list)
          // stays on top.
          mergeSort(expenses, compare: (a, b) => b.date.compareTo(a.date));
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
                    YearFilter(
                      selectedYear: _selectedYear,
                      years: years,
                      includeAll: true,
                      onChanged: (year) =>
                          setState(() => _selectedYear = year),
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
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: expenses.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final expense = expenses[index];
                            return ChickenListTileCard(
                              color: expense.id == vm.highlightedId
                                  ? context.theme.colorScheme.primary
                                        .withValues(alpha: 0.18)
                                  : null,
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
    // Water is unused for common expenses; the shared dialog still keeps it
    // when editing an old record that has it.
    showExpenseDialog(
      context,
      expense: expense,
      useLunar: vm.useLunarCalendar,
      addTitle: l10n.addCommonExpense,
      editTitle: l10n.editCommonExpense,
      allowWater: false,
      onDelete: () => _confirmDeleteExpense(expense!),
      onSubmit: (updatedExpense) async {
        try {
          if (expense != null) {
            await vm.updateGlobalExpense(updatedExpense);
          } else {
            await vm.addGlobalExpense(updatedExpense);
            vm.flashHighlight(updatedExpense.id);
            _scrollToTop();
          }
          return true;
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.saveCommonExpenseFailed(error.toString())),
                backgroundColor: Colors.red,
              ),
            );
          }
          return false;
        }
      },
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
