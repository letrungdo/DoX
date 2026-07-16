import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/model/chicken/batch_sale.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

@RoutePage()
class ChickenBatchDetailScreen extends StatefulScreen implements AutoRouteWrapper {
  final String batchId;
  const ChickenBatchDetailScreen({super.key, required this.batchId});

  @override
  State<ChickenBatchDetailScreen> createState() => _ChickenBatchDetailScreenState();

  @override
  Widget wrappedRoute(BuildContext context) => this;
}

class _ChickenBatchDetailScreenState extends ScreenState<ChickenBatchDetailScreen, ChickenViewModel> {
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DoAppBar(title: "Chi tiết lứa gà"),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final batch = vm.batches.firstWhereOrNull((e) => e.id == widget.batchId);
          if (batch == null) {
            return const Center(child: Text("Không tìm thấy thông tin lứa gà."));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(batch),
                const SizedBox(height: 24),
                _buildVaccinationSection(batch),
                const SizedBox(height: 24),
                _buildExpenseSection(batch),
                const SizedBox(height: 24),
                _buildSaleSection(batch),
                const SizedBox(height: 40),
                Center(
                  child: TextButton(
                    onPressed: () => _confirmDelete(batch),
                    child: const Text("Xóa lứa gà này", style: TextStyle(color: Colors.red)),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(batch.name, style: context.theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showEditInfoDialog(batch)),
              ],
            ),
            const Divider(),
            _buildRowInfo("Số lượng ban đầu", "${batch.quantity}"),
            if (batch.sales.isNotEmpty)
              _buildRowInfo("Đã bán / còn lại", "${batch.soldQuantity} / ${batch.remainingQuantity} con"),
            _buildRowInfo("Ngày ấp", _dateFormat.format(batch.incubationDate)),
            if (batch.actualHatchDate == null)
              _buildRowInfo("Dự kiến nở", _dateFormat.format(batch.expectedHatchDate))
            else
              _buildRowInfo("Ngày nở thực tế", _dateFormat.format(batch.actualHatchDate!)),
            if (batch.ageInDays >= 0)
              _buildRowInfo("Tuổi", "${batch.ageInDays} ngày")
            else
              _buildRowInfo("Trạng thái", "Chưa nở (còn ${-batch.ageInDays} ngày)", color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccinationSection(ChickenBatch batch) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Lịch tiêm phòng", style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...batch.vaccinations.map(
          (v) => CheckboxListTile(
            title: Text(v.title),
            subtitle: Text("Ngày: ${_dateFormat.format(v.scheduledDate)}"),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Chi phí (Tổng: ${batch.totalExpenses.toCurrency()}đ)",
              style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _showAddExpenseDialog(batch)),
          ],
        ),
        const SizedBox(height: 8),
        if (batch.expenses.isEmpty) const Text("Chưa có chi phí nào."),
        ...batch.expenses.map(
          (e) => ListTile(
            leading: _getExpenseSvg(e.type),
            title: Text(_getExpenseLabel(e.type)),
            subtitle: Text("${_dateFormat.format(e.date)}${e.note != null ? ' - ${e.note}' : ''}"),
            trailing: Text("${e.amount.toCurrency()}đ", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleSection(ChickenBatch batch) {
    final hasSold = batch.sales.isNotEmpty;
    final soldOut = hasSold && batch.remainingQuantity <= 0;
    final isDark = context.theme.brightness == Brightness.dark;

    // Theme-aware colors
    final soldColor = isDark ? Colors.green[900]?.withValues(alpha: 0.3) : Colors.green[50];
    final pendingColor = isDark ? Colors.amber[900]?.withValues(alpha: 0.3) : Colors.amber[50];

    return Card(
      color: soldOut ? soldColor : pendingColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bán gà & Lợi nhuận",
              style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (!hasSold) ...[
              const Text("Gà chưa bán. Có thể bán một lứa thành nhiều đợt."),
              const SizedBox(height: 8),
              _buildRowInfo("Giá gợi ý", "${vm.suggestPrice(batch.ageInDays).toCurrency()}đ/con"),
            ] else ...[
              ...batch.sales.map(
                (sale) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Assets.images.coinCute.svg(width: 26, height: 26),
                  title: Text(
                    "${sale.quantity > 0 ? '${sale.quantity} con' : 'Bán gà'}${sale.note != null ? ' - ${sale.note}' : ''}",
                  ),
                  subtitle: Text(_dateFormat.format(sale.date)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("${sale.amount.toCurrency()}đ", style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        onPressed: () => _confirmDeleteSale(batch, sale),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              _buildRowInfo("Đã bán", "${batch.soldQuantity} con, còn ${batch.remainingQuantity} con"),
              _buildRowInfo("Tổng doanh thu", "${batch.totalSaleAmount.toCurrency()}đ"),
              _buildRowInfo("Tổng chi phí", "-${batch.totalExpenses.toCurrency()}đ"),
              const Divider(),
              _buildRowInfo(
                "LỢI NHUẬN",
                "${batch.profit.toCurrency()}đ",
                color: batch.profit >= 0 ? Colors.green : Colors.red,
                isBold: true,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => _showSaleDialog(batch), child: const Text("Ghi nhận đợt bán mới")),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSale(ChickenBatch batch, BatchSale sale) {
    showDialog(
      context: context,
      builder: (context) => CuteDialog(
        icon: Assets.images.coinCute,
        title: "Xóa đợt bán",
        accent: Colors.red,
        confirmText: "Xóa",
        onConfirm: () {
          vm.deleteBatchSale(batch.id, sale.id);
          Navigator.pop(context);
        },
        children: [
          Text(
            "Xóa đợt bán ngày ${_dateFormat.format(sale.date)} (${sale.amount.toCurrency()}đ)?",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRowInfo(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(ChickenBatch batch) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    ExpenseType selectedType = ExpenseType.feed;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.feedCute,
          title: "Thêm chi phí",
          accent: Colors.orange,
          confirmText: "Lưu",
          onConfirm: () {
            final amount = double.tryParse(amountController.text) ?? 0;
            if (amount > 0) {
              vm.addExpense(
                batch.id,
                Expense(
                  id: const Uuid().v4(),
                  type: selectedType,
                  amount: amount,
                  date: DateTime.now(),
                  note: noteController.text.isEmpty ? null : noteController.text,
                ),
              );
              Navigator.pop(context);
            }
          },
          children: [
            DropdownButtonFormField<ExpenseType>(
              initialValue: selectedType,
              items: ExpenseType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(_getExpenseLabel(t))))
                  .toList(),
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
          ],
        ),
      ),
    );
  }

  void _showSaleDialog(ChickenBatch batch) {
    final quantity = batch.remainingQuantity > 0 ? batch.remainingQuantity : batch.quantity;
    final unitPrice = vm.suggestPrice(batch.ageInDays);
    final totalAmount = unitPrice * quantity;

    final unitPriceController = TextEditingController(text: unitPrice.toStringAsFixed(0));
    final qtyController = TextEditingController(text: quantity.toString());
    final totalAmountController = TextEditingController(text: totalAmount.toStringAsFixed(0));
    final noteController = TextEditingController();
    DateTime saleDate = DateTime.now();

    void updateTotal() {
      final unitPrice = double.tryParse(unitPriceController.text) ?? 0;
      final qty = int.tryParse(qtyController.text) ?? 0;
      totalAmountController.text = (unitPrice * qty).toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.coinCute,
          title: "Ghi nhận đợt bán",
          accent: Colors.green,
          confirmText: "Xác nhận",
          onConfirm: () {
            final amount = double.tryParse(totalAmountController.text) ?? 0;
            final qty = int.tryParse(qtyController.text) ?? 0;
            if (amount > 0 && qty > 0) {
              vm.addBatchSale(
                batch.id,
                BatchSale(
                  id: const Uuid().v4(),
                  date: saleDate,
                  quantity: qty,
                  amount: amount,
                  note: noteController.text.isEmpty ? null : noteController.text,
                ),
              );
              Navigator.pop(context);
            }
          },
          children: [
            Row(
              children: [
                Expanded(
                  child: CuteTextField(
                    controller: qtyController,
                    label: "Số lượng",
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(updateTotal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CuteTextField(
                    controller: unitPriceController,
                    label: "Giá 1 con",
                    prefixText: "đ ",
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(updateTotal),
                  ),
                ),
              ],
            ),
            CuteTextField(
              controller: totalAmountController,
              label: "Tổng tiền thu được (tự tính)",
              prefixText: "đ ",
              keyboardType: TextInputType.number,
            ),
            CuteTextField(controller: noteController, label: "Ghi chú (bán cho ai...)"),
            CuteDateField(label: "Ngày bán", value: saleDate, onChanged: (d) => setState(() => saleDate = d)),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ChickenBatch batch) {
    showDialog(
      context: context,
      builder: (context) => CuteDialog(
        icon: Assets.images.henCute,
        title: "Xóa lứa gà",
        accent: Colors.red,
        confirmText: "Xóa",
        onConfirm: () {
          vm.deleteBatch(batch.id);
          Navigator.pop(context);
          context.router.back();
        },
        children: [
          Text(
            "Bạn có chắc chắn muốn xóa lứa '${batch.name}'? Hành động này không thể hoàn tác.",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showEditInfoDialog(ChickenBatch batch) {
    final nameController = TextEditingController(text: batch.name);
    final quantityController = TextEditingController(text: batch.quantity.toString());
    DateTime incubationDate = batch.incubationDate;
    DateTime? actualHatchDate = batch.actualHatchDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.chickCute,
          title: "Sửa thông tin lứa gà",
          confirmText: "Lưu",
          onConfirm: () {
            final name = nameController.text;
            final qty = int.tryParse(quantityController.text) ?? 0;
            if (name.isNotEmpty && qty >= 0) {
              vm.updateBatch(
                batch.copyWith(
                  name: name,
                  quantity: qty,
                  incubationDate: incubationDate,
                  actualHatchDate: actualHatchDate,
                ),
              );
              Navigator.pop(context);
            }
          },
          children: [
            CuteTextField(controller: nameController, label: "Tên lứa gà"),
            CuteTextField(
              controller: quantityController,
              label: "Số lượng ban đầu",
              keyboardType: TextInputType.number,
            ),
            CuteDateField(
              label: "Ngày ấp trứng",
              value: incubationDate,
              onChanged: (d) => setState(() => incubationDate = d),
            ),
            CuteDateField(
              label: "Ngày nở thực tế",
              value: actualHatchDate,
              onChanged: (d) => setState(() => actualHatchDate = d),
            ),
          ],
        ),
      ),
    );
  }

  String _getExpenseLabel(ExpenseType type) {
    return switch (type) {
      ExpenseType.feed => "Cám",
      ExpenseType.medicine => "Thuốc",
      ExpenseType.electricity => "Điện sưởi",
      ExpenseType.water => "Nước",
      ExpenseType.other => "Khác",
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
