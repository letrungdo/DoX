import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/theme/text_theme.dart';
import 'package:do_x/utils/chicken_date.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/chicken_add_icon.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:do_x/widgets/chicken_change_badge.dart';
import 'package:do_x/widgets/chicken_stale_banner.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/expense_dialog.dart';
import 'package:do_x/widgets/input/year_filter.dart';
import 'package:do_x/widgets/total_amount_text.dart';
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
  late int _selectedYear;

  /// The year to ask the server for; null when the picker is on "all", which
  /// is the one case that needs every year.
  int? get _yearFilter => _selectedYear == 0 ? null : _selectedYear;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedYear = vm.currentDisplayYear();
  }

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
    vm.ensureLoaded({ChickenSection.globalExpenses}, year: _yearFilter);
  }

  @override
  void onResume() {
    super.onResume();
    vm.ensureLoaded({ChickenSection.globalExpenses}, year: _yearFilter);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      appBar: DoAppBar(
        title: l10n.commonExpenses,
        titleSuffix: AppBarSyncIcon<ChickenViewModel>(
          selector: (vm) => vm.isFetching,
        ),
        actions: [
          ChickenAddButton(
            icon: Assets.images.feedCute,
            onPressed: vm.isReadOnly ? null : () => _showExpenseDialog(),
          ),
        ],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final years = {
            vm.currentDisplayYear(),
            ...vm.yearsFor({ChickenSection.globalExpenses}),
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
              const ChickenStaleBanner(
                sections: {ChickenSection.globalExpenses},
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    YearFilter(
                      selectedYear: _selectedYear,
                      years: years,
                      includeAll: true,
                      onChanged: (year) {
                        setState(() => _selectedYear = year);
                        // A different year is a different list — start it from
                        // the top instead of keeping the old scroll offset.
                        _scrollToTop();
                        // Another year means another read: the server only
                        // sent the one that was selected.
                        vm.ensureLoaded({
                          ChickenSection.globalExpenses,
                        }, year: _yearFilter);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: TotalAmountText(total)),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      vm.loadData(sections: {ChickenSection.globalExpenses}),
                  child: expenses.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: constraints.maxHeight,
                                child: vm.isLoading
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
                                              color: context
                                                  .theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                          if (vm.globalExpenses.isEmpty &&
                                              !vm.isReadOnly) ...[
                                            const SizedBox(height: 16),
                                            NeuButton(
                                              onPressed: () =>
                                                  _showExpenseDialog(),
                                              accent: context
                                                  .theme
                                                  .colorScheme
                                                  .primary,
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
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                          itemCount: expenses.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final expense = expenses[index];
                            return ChickenListTileCard(
                              onTap: vm.isReadOnly
                                  ? null
                                  : () => _showExpenseDialog(expense),
                              leading: _expenseSvg(expense.type),
                              title: Row(
                                children: [
                                  ChickenChangeBadge(
                                    vm.changeBadgeOf(expense.id),
                                    leading: true,
                                  ),
                                  Flexible(
                                    child: Text(
                                      expense.note ??
                                          _expenseLabel(expense.type),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                "${_fmt(expense.date)} · ${_expenseLabel(expense.type)}",
                              ),
                              trailing: Text(
                                "${expense.amount.toCurrency()}đ",
                                style: DoTextTheme.listAmount.copyWith(
                                  color: context.colors.money,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ).contentConstrainedBox();
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
      noteSuggestions: vm.expenseNoteSuggestions,
      onDelete: () => _confirmDeleteExpense(expense!),
      onSubmit: (updatedExpense) async {
        try {
          if (expense != null) {
            await vm.updateGlobalExpense(updatedExpense);
          } else {
            await vm.addGlobalExpense(updatedExpense);
            _scrollToTop();
          }
          return true;
        } catch (error) {
          if (mounted) {
            context.showToast(
              l10n.saveCommonExpenseFailed(error.toString()),
              isError: true,
            );
          }
          return false;
        }
      },
    );
  }

  Future<void> _confirmDeleteExpense(Expense expense) async {
    final l10n = AppLocalizations.of(context);
    final shouldDelete = await showAppModal<bool>(
      context,
      builder: (context) => CuteDialog(
        icon: Assets.images.feedCute,
        title: l10n.deleteCommonExpense,
        accent: context.colors.danger,
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
        context.showToast(
          l10n.deleteCommonExpenseFailed(error.toString()),
          isError: true,
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
