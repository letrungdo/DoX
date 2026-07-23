import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/chicken_date.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_loading_bar.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/expense_dialog.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/widgets/input/lunar_date_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

@RoutePage()
class ChickenBatchDetailScreen extends StatefulScreen
    implements AutoRouteWrapper {
  final String batchId;
  const ChickenBatchDetailScreen({super.key, required this.batchId});

  @override
  State<ChickenBatchDetailScreen> createState() =>
      _ChickenBatchDetailScreenState();

  @override
  Widget wrappedRoute(BuildContext context) => this;
}

class _ChickenBatchDetailScreenState
    extends ScreenState<ChickenBatchDetailScreen, ChickenViewModel> {
  String _fmt(DateTime date) =>
      ChickenDate.format(date, useLunar: vm.useLunarCalendar);

  @override
  void initData() {
    super.initData();
    vm.ensureBatchesLoaded();
  }

  @override
  void onResume() {
    super.onResume();
    vm.ensureBatchesLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.batchDetailTitle,
        bottom: AppBarLoadingBar<ChickenViewModel>(
          selector: (vm) => vm.isBatchesLoading,
        ),
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final batch = vm.batches.firstWhereOrNull(
            (e) => e.id == widget.batchId,
          );
          if (batch == null) {
            return Center(child: Text(l10n.batchNotFound));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(batch),
                const SizedBox(height: 24),
                _buildSaleSection(batch),
                const SizedBox(height: 24),
                _buildExpenseSection(batch),
                const SizedBox(height: 24),
                _buildVaccinationSection(batch),
                const SizedBox(height: 40),
                Center(
                  child: TextButton(
                    onPressed: () => _confirmDelete(batch),
                    child: Text(
                      l10n.deleteThisBatch,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ).webConstrainedBox();
        },
      ),
    );
  }

  Widget _buildInfoSection(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    batch.name,
                    style: context.theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditInfoDialog(batch),
                ),
              ],
            ),
            const Divider(),
            _buildRowInfo(l10n.initialQuantity, "${batch.quantity}"),
            if (batch.sales.isNotEmpty)
              _buildRowInfo(
                l10n.soldRemainingLabel,
                l10n.soldRemainingValue(
                  batch.soldQuantity,
                  batch.remainingQuantity,
                ),
              ),
            _buildRowInfo(
              l10n.incubationDay,
              _fmt(batch.incubationDate),
            ),
            if (batch.actualHatchDate == null)
              _buildRowInfo(
                l10n.expectedHatch,
                _fmt(batch.expectedHatchDate),
              )
            else
              _buildRowInfo(
                l10n.actualHatchDateLabel,
                _fmt(batch.actualHatchDate!),
              ),
            if (batch.ageInDays >= 0)
              _buildRowInfo(l10n.ageLabel, l10n.daysCount(batch.ageInDays))
            else
              _buildRowInfo(
                l10n.statusLabel,
                l10n.notHatchedYet(-batch.ageInDays),
                color: Colors.orange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccinationSection(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.vaccinationSchedule,
          style: context.theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...batch.vaccinations.map(
          (v) => CheckboxListTile(
            title: Text(v.title),
            subtitle: Text(l10n.dateValue(_fmt(v.scheduledDate))),
            value: v.isCompleted,
            onChanged: (val) {
              vm.setCurrentContext(context);
              vm.toggleVaccination(batch.id, v.id);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseSection(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.expensesSectionTitle("${batch.totalExpenses.toCurrency()}đ"),
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showExpenseDialog(batch),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (batch.expenses.isEmpty) Text(l10n.noExpensesYet),
        ...batch.expenses.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _showExpenseDialog(batch, expense: e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: context.theme.colorScheme.outlineVariant,
                ),
              ),
              leading: _getExpenseSvg(e.type),
              title: Text(_getExpenseLabel(e.type)),
              subtitle: Text(
                "${_fmt(e.date)}${e.note != null ? ' - ${e.note}' : ''}",
              ),
              trailing: Text(
                "${e.amount.toCurrency()}đ",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.colors.money,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleSection(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    final hasSold = batch.sales.isNotEmpty;
    final soldOut = hasSold && batch.remainingQuantity <= 0;
    final isDark = context.theme.brightness == Brightness.dark;

    // Theme-aware colors
    final soldColor = isDark
        ? Colors.green[900]?.withValues(alpha: 0.3)
        : Colors.green[50];
    final pendingColor = isDark
        ? Colors.amber[900]?.withValues(alpha: 0.3)
        : Colors.amber[50];

    return Card(
      color: soldOut ? soldColor : pendingColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.saleAndProfit,
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            if (!hasSold) ...[
              Text(l10n.notSoldHint),
              const SizedBox(height: 8),
              _buildRowInfo(
                l10n.suggestedPrice,
                l10n.pricePerChicken(
                  "${vm.suggestPrice(batch.ageInDays).toCurrency()}đ",
                ),
              ),
            ] else ...[
              ...batch.sales.map(
                (sale) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showSaleDialog(batch, sale: sale),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: context.theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            "${sale.quantity > 0 ? l10n.chickenQuantity(sale.quantity) : l10n.chickenSale}${sale.note != null ? ' - ${sale.note}' : ''}",
                                      ),
                                      TextSpan(
                                        text:
                                            " (${l10n.statusDaysOld(batch.ageInDaysAt(sale.date))})",
                                        style: TextStyle(
                                          fontWeight: FontWeight.normal,
                                          color: batch.ageInDaysAt(sale.date) < 0
                                              ? Colors.red
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: _fmt(sale.date),
                                        style: TextStyle(
                                          color: context
                                              .theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      if (sale.quantity > 0) ...[
                                        TextSpan(
                                          text: " · ",
                                          style: TextStyle(
                                            color: context
                                                .theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                        TextSpan(
                                          text: l10n.pricePerChicken(
                                            "${(sale.amount / sale.quantity).toCurrency()}đ",
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: context.colors.money,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Assets.images.coinCute.svg(width: 24, height: 24),
                              const SizedBox(height: 2),
                              Text(
                                "${sale.amount.toCurrency()}đ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.money,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(),
              _buildRowInfo(
                l10n.soldLabel,
                l10n.soldAndRemaining(
                  batch.soldQuantity,
                  batch.remainingQuantity,
                ),
              ),
              _buildRowInfo(
                l10n.totalRevenueLabel,
                "${batch.totalSaleAmount.toCurrency()}đ",
              ),
              _buildRowInfo(
                l10n.totalExpensesLabel,
                "-${batch.totalExpenses.toCurrency()}đ",
              ),
              const Divider(),
              _buildRowInfo(
                l10n.profitUpper,
                "${batch.profit.toCurrency()}đ",
                color: batch.profit >= 0 ? context.colors.money : Colors.red,
                isBold: true,
              ),
            ],
            // Sold out: nothing left to sell, so hide the record button.
            if (!soldOut) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _showSaleDialog(batch),
                  child: Text(l10n.recordNewSale),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSale(ChickenBatch batch, BatchSale sale) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => CuteDialog(
        icon: Assets.images.coinCute,
        title: l10n.deleteSaleRound,
        accent: Colors.red,
        confirmText: l10n.delete,
        isDestructive: true,
        onConfirm: () {
          vm.deleteBatchSale(batch.id, sale.id);
          Navigator.pop(context);
        },
        children: [
          Text(
            l10n.confirmDeleteSaleRound(
              _fmt(sale.date),
              "${sale.amount.toCurrency()}đ",
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _confirmDeleteExpense(ChickenBatch batch, Expense expense) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => CuteDialog(
        icon: Assets.images.feedCute,
        title: l10n.deleteExpense,
        accent: Colors.red,
        confirmText: l10n.delete,
        isDestructive: true,
        onConfirm: () {
          vm.deleteExpense(batch.id, expense.id);
          Navigator.pop(context);
        },
        children: [
          Text(
            l10n.confirmDeleteExpense(
              _getExpenseLabel(expense.type),
              "${expense.amount.toCurrency()}đ",
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRowInfo(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.theme.colorScheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseDialog(ChickenBatch batch, {Expense? expense}) {
    final l10n = AppLocalizations.of(context);
    showExpenseDialog(
      context,
      expense: expense,
      useLunar: vm.useLunarCalendar,
      addTitle: l10n.addExpense,
      editTitle: l10n.editExpense,
      onDelete: () async => _confirmDeleteExpense(batch, expense!),
      onSubmit: (updatedExpense) async {
        if (expense != null) {
          await vm.updateExpense(batch.id, updatedExpense);
        } else {
          await vm.addExpense(batch.id, updatedExpense);
        }
        return true;
      },
    );
  }

  void _showSaleDialog(ChickenBatch batch, {BatchSale? sale}) {
    final l10n = AppLocalizations.of(context);
    final isEditing = sale != null;
    final quantity =
        sale?.quantity ??
        (batch.remainingQuantity > 0
            ? batch.remainingQuantity
            : batch.quantity);
    final unitPrice = isEditing && sale.quantity > 0
        ? sale.amount / sale.quantity
        : vm.suggestPrice(batch.ageInDays);
    final totalAmount = sale?.amount ?? unitPrice * quantity;
    // Available to sell = remaining, plus this sale's own quantity when editing
    // (it is already counted in the remaining figure).
    final maxQuantity = batch.remainingQuantity + (sale?.quantity ?? 0);

    final unitPriceController = TextEditingController(
      text: unitPrice.toCurrency(),
    );
    final qtyController = TextEditingController(text: quantity.toString());
    final totalAmountController = TextEditingController(
      text: totalAmount.toCurrency(),
    );
    final noteController = TextEditingController(text: sale?.note ?? '');
    DateTime saleDate =
        sale?.date ?? LunarCalendar.solarToLunarDateTime(DateTime.now());
    String? qtyError;
    String? amountError;

    void updateTotal() {
      final unitPrice = unitPriceController.text.toMoney() ?? 0;
      final qty = int.tryParse(qtyController.text) ?? 0;
      totalAmountController.text = (unitPrice * qty).toCurrency();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.coinCute,
          title: isEditing ? l10n.editSaleRound : l10n.recordSale,
          accent: Colors.green,
          confirmText: isEditing ? l10n.update : l10n.confirm,
          destructiveText: isEditing ? l10n.delete : null,
          onDestructive: isEditing
              ? () {
                  Navigator.pop(context);
                  _confirmDeleteSale(batch, sale);
                }
              : null,
          onConfirm: () {
            final amount = totalAmountController.text.toMoney() ?? 0;
            final qty = int.tryParse(qtyController.text) ?? 0;
            if (qty <= 0 || qty > maxQuantity || amount <= 0) {
              setState(() {
                qtyError = qty <= 0
                    ? l10n.errorEnterQuantity
                    : qty > maxQuantity
                    ? l10n.errorQuantityExceedsRemaining(maxQuantity)
                    : null;
                amountError = amount <= 0 ? l10n.errorEnterAmount : null;
              });
              return;
            }
            final newSale = BatchSale(
              id: sale?.id ?? const Uuid().v4(),
              date: saleDate,
              quantity: qty,
              amount: amount,
              note: noteController.text.isEmpty ? null : noteController.text,
            );
            if (isEditing) {
              vm.updateBatchSale(batch.id, newSale);
            } else {
              vm.addBatchSale(batch.id, newSale);
            }
            Navigator.pop(context);
          },
          children: [
            Row(
              children: [
                Expanded(
                  child: CuteTextField(
                    controller: qtyController,
                    label: l10n.quantityLabel,
                    autofocus: !isEditing,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    errorText: qtyError,
                    onChanged: (_) => setState(() {
                      qtyError = null;
                      updateTotal();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CuteMoneyField(
                    controller: unitPriceController,
                    label: l10n.pricePerUnit,
                    onChanged: (_) => setState(() {
                      amountError = null;
                      updateTotal();
                    }),
                  ),
                ),
              ],
            ),
            CuteMoneyField(
              controller: totalAmountController,
              label: l10n.totalAutoCalculated,
              errorText: amountError,
              onChanged: (_) {
                if (amountError != null) setState(() => amountError = null);
              },
            ),
            CuteTextField(controller: noteController, label: l10n.saleNoteHint),
            LunarDateField(
              label: l10n.saleDate,
              value: saleDate,
              useLunar: vm.useLunarCalendar,
              onChanged: (d) => setState(() => saleDate = d),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => CuteDialog(
        icon: Assets.images.henCute,
        title: l10n.deleteBatch,
        accent: Colors.red,
        confirmText: l10n.delete,
        isDestructive: true,
        onConfirm: () {
          vm.deleteBatch(batch.id);
          Navigator.pop(context);
          context.router.back();
        },
        children: [
          Text(
            l10n.confirmDeleteBatch(batch.name),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showEditInfoDialog(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: batch.name);
    final quantityController = TextEditingController(
      text: batch.quantity.toString(),
    );
    DateTime incubationDate = batch.incubationDate;
    DateTime? actualHatchDate = batch.actualHatchDate;
    String? nameError;
    String? qtyError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.chickCute,
          title: l10n.editBatchInfo,
          confirmText: l10n.save,
          onConfirm: () {
            final name = nameController.text.trim();
            final qty = int.tryParse(quantityController.text);
            if (name.isEmpty || qty == null || qty < 0) {
              setState(() {
                nameError = name.isEmpty ? l10n.errorEnterBatchName : null;
                qtyError = (qty == null || qty < 0)
                    ? l10n.errorEnterQuantity
                    : null;
              });
              return;
            }
            vm.updateBatch(
              batch.copyWith(
                name: name,
                quantity: qty,
                incubationDate: incubationDate,
                actualHatchDate: actualHatchDate,
              ),
            );
            Navigator.pop(context);
          },
          children: [
            CuteTextField(
              controller: nameController,
              label: l10n.batchName,
              errorText: nameError,
              onChanged: (_) {
                if (nameError != null) setState(() => nameError = null);
              },
            ),
            CuteTextField(
              controller: quantityController,
              label: l10n.initialQuantity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              errorText: qtyError,
              onChanged: (_) {
                if (qtyError != null) setState(() => qtyError = null);
              },
            ),
            LunarDateField(
              label: l10n.incubationDate,
              value: incubationDate,
              useLunar: vm.useLunarCalendar,
              onChanged: (d) => setState(() => incubationDate = d),
            ),
            LunarDateField(
              label: l10n.actualHatchDateLabel,
              value: actualHatchDate,
              useLunar: vm.useLunarCalendar,
              onChanged: (d) => setState(() => actualHatchDate = d),
            ),
          ],
        ),
      ),
    );
  }

  String _getExpenseLabel(ExpenseType type) {
    final l10n = AppLocalizations.of(context);
    return switch (type) {
      ExpenseType.feed => l10n.expenseFeed,
      ExpenseType.medicine => l10n.expenseMedicine,
      ExpenseType.electricity => l10n.expenseElectricity,
      ExpenseType.water => l10n.expenseWater,
      ExpenseType.other => l10n.expenseOther,
    };
  }

  Widget _getExpenseSvg(ExpenseType type) {
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
