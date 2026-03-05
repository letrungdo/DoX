import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
    return Scaffold(
      appBar: DoAppBar(
        title: "Quản lý gà",
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              vm.setCurrentContext(context);
              vm.syncToGoogle();
            },
            tooltip: "Đồng bộ Google Tasks",
          ),
          IconButton(
            icon: const Icon(Icons.ads_click, color: Colors.red),
            onPressed: () => context.router.push(const CockSalesRoute()),
            tooltip: "Bán gà đá",
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => context.router.push(const ChickenStatisticsRoute()),
            tooltip: "Thống kê lợi nhuận",
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: _showAddBatchDialog),
        ],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          if (vm.isBusy) {
            return const Center(child: CircularProgressIndicator());
          }
          if (vm.batches.isEmpty) {
            return const Center(child: Text("Chưa có lứa gà nào. Nhấn + để thêm."));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.batches.length,
            itemBuilder: (context, index) {
              final batch = vm.batches[index];
              return _buildBatchCard(batch);
            },
          );
        },
      ).webConstrainedBox(),
    );
  }

  Widget _buildBatchCard(ChickenBatch batch) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isHatched = batch.actualHatchDate != null || DateTime.now().isAfter(batch.expectedHatchDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        title: Text(batch.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Số lượng: ${batch.quantity}"),
            Text("Ngày ấp: ${dateFormat.format(batch.incubationDate)}"),
            Text("Dự kiến nở: ${dateFormat.format(batch.expectedHatchDate)}"),
            if (isHatched) Text("Tuổi: ${batch.ageInDays} ngày", style: TextStyle(color: Colors.green[700])),
            Text(
              "Lợi nhuận tạm tính: ${batch.profit.toCurrency()}đ",
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

  void _showAddBatchDialog() {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Thêm lứa gà mới"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Tên lứa gà"),
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: "Số lượng"),
                keyboardType: TextInputType.number,
              ),
              ListTile(
                title: const Text("Ngày ấp trứng"),
                subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
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
                  vm.addBatch(name: name, incubationDate: selectedDate, quantity: qty);
                  Navigator.pop(context);
                }
              },
              child: const Text("Thêm"),
            ),
          ],
        ),
      ),
    );
  }
}
