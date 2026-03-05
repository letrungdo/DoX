import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/model/chicken/expense.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
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
            _buildRowInfo("Ngày ấp", _dateFormat.format(batch.incubationDate)),
            _buildRowInfo("Dự kiến nở", _dateFormat.format(batch.expectedHatchDate)),
            if (batch.actualHatchDate != null) _buildRowInfo("Ngày nở thực tế", _dateFormat.format(batch.actualHatchDate!)),
            _buildRowInfo("Tuổi", "${batch.ageInDays} ngày"),
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
            leading: Icon(_getExpenseIcon(e.type)),
            title: Text(_getExpenseLabel(e.type)),
            subtitle: Text("${_dateFormat.format(e.date)}${e.note != null ? ' - ${e.note}' : ''}"),
            trailing: Text("${e.amount.toCurrency()}đ", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleSection(ChickenBatch batch) {
    final hasSold = batch.saleDate != null;
    final isDark = context.theme.brightness == Brightness.dark;

    // Theme-aware colors
    final soldColor = isDark ? Colors.green[900]?.withOpacity(0.3) : Colors.green[50];
    final pendingColor = isDark ? Colors.amber[900]?.withOpacity(0.3) : Colors.amber[50];

    return Card(
      color: hasSold ? soldColor : pendingColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Thanh toán & Lợi nhuận", style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (hasSold) IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showSaleDialog(batch)),
              ],
            ),
            const Divider(),
            if (hasSold) ...[
              _buildRowInfo("Ngày bán", _dateFormat.format(batch.saleDate!)),
              _buildRowInfo("Số lượng bán", "${batch.saleQuantity ?? batch.quantity} con"),
              _buildRowInfo("Doanh thu", "${batch.totalSaleAmount?.toCurrency()}đ"),
              _buildRowInfo("Tổng chi phí", "-${batch.totalExpenses.toCurrency()}đ"),
              const Divider(),
              _buildRowInfo(
                "LỢI NHUẬN",
                "${batch.profit.toCurrency()}đ",
                color: batch.profit >= 0 ? Colors.green : Colors.red,
                isBold: true,
              ),
            ] else ...[
              const Text("Gà chưa bán. Nhập thông tin khi bán để tính lợi nhuận."),
              const SizedBox(height: 8),
              _buildRowInfo("Giá gợi ý", "${vm.suggestPrice(batch.ageInDays).toCurrency()}đ/con"),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: () => _showSaleDialog(batch), child: const Text("Ghi nhận bán gà")),
              ),
            ],
          ],
        ),
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
        builder: (context, setState) => AlertDialog(
          title: const Text("Thêm chi phí"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ExpenseType>(
                initialValue: selectedType,
                items: ExpenseType.values.map((t) => DropdownMenuItem(value: t, child: Text(_getExpenseLabel(t)))).toList(),
                onChanged: (val) => setState(() => selectedType = val!),
                decoration: const InputDecoration(labelText: "Loại chi phí"),
              ),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: "Số tiền"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: "Ghi chú"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
            ElevatedButton(
              onPressed: () {
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
              child: const Text("Lưu"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaleDialog(ChickenBatch batch) {
    final isEditing = batch.saleDate != null;
    final quantity = batch.saleQuantity ?? batch.quantity;
    final totalAmount = batch.totalSaleAmount ?? (vm.suggestPrice(batch.ageInDays) * quantity);
    final unitPrice = quantity > 0 ? (totalAmount / quantity) : vm.suggestPrice(batch.ageInDays);

    final unitPriceController = TextEditingController(text: unitPrice.toStringAsFixed(0));
    final qtyController = TextEditingController(text: quantity.toString());
    final totalAmountController = TextEditingController(text: totalAmount.toStringAsFixed(0));
    DateTime saleDate = batch.saleDate ?? DateTime.now();

    void updateTotal() {
      final unitPrice = double.tryParse(unitPriceController.text) ?? 0;
      final qty = int.tryParse(qtyController.text) ?? 0;
      totalAmountController.text = (unitPrice * qty).toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? "Sửa thông tin bán" : "Ghi nhận bán gà"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: "Số lượng bán"),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(updateTotal),
              ),
              TextField(
                controller: unitPriceController,
                decoration: const InputDecoration(labelText: "Giá bán 1 con (VNĐ)"),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(updateTotal),
              ),
              TextField(
                controller: totalAmountController,
                decoration: const InputDecoration(labelText: "Tổng tiền thu được (tự tính)"),
                keyboardType: TextInputType.number,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Ngày bán"),
                subtitle: Text(_dateFormat.format(saleDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: saleDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => saleDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(totalAmountController.text) ?? 0;
                final qty = int.tryParse(qtyController.text) ?? 0;
                if (amount > 0 && qty > 0) {
                  vm.updateBatch(batch.copyWith(saleDate: saleDate, totalSaleAmount: amount, saleQuantity: qty));
                  Navigator.pop(context);
                }
              },
              child: const Text("Xác nhận"),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ChickenBatch batch) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xóa lứa gà"),
        content: Text("Bạn có chắc chắn muốn xóa lứa '${batch.name}'? Hành động này không thể hoàn tác."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          TextButton(
            onPressed: () {
              vm.deleteBatch(batch.id);
              Navigator.pop(context);
              context.router.back();
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditInfoDialog(ChickenBatch batch) {
    final nameController = TextEditingController(text: batch.name);
    final quantityController = TextEditingController(text: batch.quantity.toString());
    DateTime incubationDate = batch.incubationDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Sửa thông tin lứa gà"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Tên lứa gà"),
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: "Số lượng ban đầu"),
                keyboardType: TextInputType.number,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Ngày ấp trứng"),
                subtitle: Text(_dateFormat.format(incubationDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: incubationDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => incubationDate = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text;
                final qty = int.tryParse(quantityController.text) ?? 0;
                if (name.isNotEmpty && qty > 0) {
                  vm.updateBatch(batch.copyWith(name: name, quantity: qty, incubationDate: incubationDate));
                  Navigator.pop(context);
                }
              },
              child: const Text("Lưu"),
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

  IconData _getExpenseIcon(ExpenseType type) {
    return switch (type) {
      ExpenseType.feed => Icons.grass,
      ExpenseType.medicine => Icons.medical_services,
      ExpenseType.electricity => Icons.wb_incandescent,
      ExpenseType.water => Icons.water_drop,
      ExpenseType.other => Icons.more_horiz,
    };
  }
}
