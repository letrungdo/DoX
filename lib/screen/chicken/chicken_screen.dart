import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

@RoutePage()
class ChickenScreen extends StatefulScreen implements AutoRouteWrapper {
  const ChickenScreen({super.key});

  @override
  State<ChickenScreen> createState() => _ChickenScreenState();

  @override
  Widget wrappedRoute(BuildContext context) => this;
}

class _ChickenScreenState extends ScreenState<ChickenScreen, ChickenViewModel> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.chickenManagement,
        actions: [
          IconButton(
            icon: Assets.images.roosterCute.svg(width: 26, height: 26),
            onPressed: () => context.router.push(const CockSalesRoute()),
            tooltip: l10n.sellRoosterMeat,
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.router.push(const ChickenStatisticsRoute()),
            tooltip: l10n.profitStatistics,
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddBatchDialog),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _showImportDialog(l10n);
                case 'expenses':
                  _showGlobalExpensesSheet(l10n);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'expenses', child: Text(l10n.commonExpenses)),
              PopupMenuItem(value: 'import', child: Text(l10n.importData)),
            ],
          ),
        ],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          if (vm.isBusy) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.batches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Assets.images.chickCute.svg(width: 72, height: 72),
                  const SizedBox(height: 12),
                  Text(l10n.noBatchesYet),
                ],
              ),
            );
          }
          // Batches are sorted by incubation date desc -> insert a year header on change.
          final items = <Widget>[];
          int? currentYear;
          for (final batch in vm.batches) {
            final year = (batch.actualHatchDate ?? batch.expectedHatchDate).year;
            if (year != currentYear) {
              currentYear = year;
              items.add(
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    "${l10n.yearPrefix} $year",
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
                  ),
                ),
              );
            }
            items.add(_buildBatchCard(batch));
          }
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: items);
        },
      ).webConstrainedBox(),
    );
  }

  Widget _buildBatchCard(ChickenBatch batch) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final hatchDate = batch.actualHatchDate ?? batch.expectedHatchDate;
    final isHatched = batch.actualHatchDate != null || DateTime.now().isAfter(batch.expectedHatchDate);
    final isSoldOut = batch.sales.isNotEmpty && batch.remainingQuantity <= 0;
    final hasMoney = batch.sales.isNotEmpty || batch.expenses.isNotEmpty || batch.cockSales.isNotEmpty;

    final (statusText, statusColor) = !isHatched
        ? ("Chờ nở - ${dateFormat.format(batch.expectedHatchDate)}", Colors.orange)
        : isSoldOut
        ? ("Đã bán hết", Colors.grey)
        : ("${batch.ageInDays} ngày tuổi", Colors.green);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // Clip so tap/long-press ink follows the rounded corners.
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child:
              (!isHatched
                      ? Assets.images.eggCute
                      : isSoldOut
                      ? Assets.images.henCute
                      : Assets.images.chickCute)
                  .svg(width: 30, height: 30),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                batch.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              batch.sales.isEmpty
                  ? "Số lượng: ${batch.quantity} con · Nở: ${dateFormat.format(hatchDate)}"
                  : "Đã bán ${batch.soldQuantity}/${batch.quantity} con · Nở: ${dateFormat.format(hatchDate)}",
            ),
            if (hasMoney)
              Text(
                "Thu ${batch.totalSaleAmount + batch.totalCockSales > 0 ? (batch.totalSaleAmount + batch.totalCockSales).toCurrency() : 0}đ"
                "${batch.totalExpenses > 0 ? ' · Chi ${batch.totalExpenses.toCurrency()}đ' : ''}"
                " · Lãi ${batch.profit.toCurrency()}đ",
                style: TextStyle(color: batch.profit >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w600),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          context.router.push(ChickenBatchDetailRoute(batchId: batch.id));
        },
      ),
    );
  }

  void _showImportDialog(AppLocalizations l10n) {
    final jsonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => CuteDialog(
        icon: Assets.images.chickCute,
        title: l10n.importData,
        accent: Colors.teal,
        confirmText: l10n.login, // Reusing login as 'Import' if not localized, but I should add 'import' string
        onConfirm: () async {
          final text = jsonController.text.trim();
          if (text.isEmpty) return;
          Navigator.pop(dialogContext);
          final messenger = ScaffoldMessenger.of(context);
          try {
            final count = await vm.importFromJson(text);
            messenger.showSnackBar(SnackBar(content: Text("Đã nhập $count bản ghi.")));
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text("Nhập thất bại: $e"), backgroundColor: Colors.red));
          }
        },
        children: [
          Text(
            "Dán nội dung file JSON (batches, cockSales, expenses). Dữ liệu sẽ được thêm vào, không ghi đè.",
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          CuteTextField(
            controller: jsonController,
            label: "Nội dung JSON",
            hint: '{"batches": [...], ...}',
            maxLines: 8,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  void _showGlobalExpensesSheet(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final expenses = vm.globalExpenses;
          final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${l10n.commonExpenses} (${total.toCurrency()}đ)",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _showAddGlobalExpenseDialog),
                      ],
                    ),
                  ),
                  Expanded(
                    child: expenses.isEmpty
                        ? const Center(child: Text("Chưa có chi phí chung nào."))
                        : ListView.builder(
                            itemCount: expenses.length,
                            itemBuilder: (context, index) {
                              final e = expenses[index];
                              return ListTile(
                                leading: _expenseSvg(e.type),
                                title: Text(e.note ?? _expenseLabel(e.type)),
                                subtitle: Text(DateFormat('dd/MM/yyyy').format(e.date)),
                                trailing: Text(
                                  "${e.amount.toCurrency()}đ",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddGlobalExpenseDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    ExpenseType selectedType = ExpenseType.feed;
    DateTime expenseDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.feedCute,
          title: "Thêm chi phí chung",
          accent: Colors.orange,
          confirmText: "Lưu",
          onConfirm: () {
            final amount = double.tryParse(amountController.text) ?? 0;
            if (amount > 0) {
              vm.addGlobalExpense(
                Expense(
                  id: const Uuid().v4(),
                  type: selectedType,
                  amount: amount,
                  date: expenseDate,
                  note: noteController.text.isEmpty ? null : noteController.text,
                ),
              );
              Navigator.pop(context);
            }
          },
          children: [
            DropdownButtonFormField<ExpenseType>(
              initialValue: selectedType,
              items: ExpenseType.values.map((t) => DropdownMenuItem(value: t, child: Text(_expenseLabel(t)))).toList(),
              onChanged: (val) => setState(() => selectedType = val!),
              decoration: cuteInputDecoration(context, "Loại chi phí"),
              borderRadius: BorderRadius.circular(14),
            ),
            CuteTextField(
              controller: amountController,
              label: "Số tiền",
              prefixText: "đ ",
              keyboardType: TextInputType.number,
            ),
            CuteTextField(controller: noteController, label: "Ghi chú"),
            CuteDateField(label: "Ngày chi", value: expenseDate, onChanged: (d) => setState(() => expenseDate = d)),
          ],
        ),
      ),
    );
  }

  String _expenseLabel(ExpenseType type) {
    return switch (type) {
      ExpenseType.feed => "Cám / thức ăn",
      ExpenseType.medicine => "Thuốc / vắc xin",
      ExpenseType.electricity => "Điện sưởi",
      ExpenseType.water => "Nước",
      ExpenseType.other => "Khác",
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

  void _showAddBatchDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.eggCute,
          title: "Thêm lứa gà mới",
          confirmText: "Thêm",
          onConfirm: () {
            final name = nameController.text;
            final qty = int.tryParse(quantityController.text) ?? 0;
            if (name.isNotEmpty && qty > 0) {
              vm.addBatch(name: name, incubationDate: selectedDate, quantity: qty);
              Navigator.pop(context);
            }
          },
          children: [
            CuteTextField(controller: nameController, label: "Tên lứa gà", hint: "VD: Bầy 31"),
            CuteTextField(
              controller: quantityController,
              label: "Số lượng trứng/con",
              keyboardType: TextInputType.number,
            ),
            CuteDateField(
              label: "Ngày ấp trứng",
              value: selectedDate,
              onChanged: (d) => setState(() => selectedDate = d),
            ),
          ],
        ),
      ),
    );
  }
}
