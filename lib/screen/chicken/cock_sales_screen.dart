import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

@RoutePage()
class CockSalesScreen extends StatefulScreen implements AutoRouteWrapper {
  const CockSalesScreen({super.key});

  @override
  State<CockSalesScreen> createState() => _CockSalesScreenState();

  @override
  Widget wrappedRoute(BuildContext context) => this;
}

class _CockSalesScreenState extends ScreenState<CockSalesScreen, ChickenViewModel> {
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DoAppBar(
        title: "Bán gà đá",
        actions: [IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _showAddSaleDialog)],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          if (vm.globalCockSales.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.ads_click, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("Chưa có dữ liệu bán gà đá", style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _showAddSaleDialog, child: const Text("Nhập bán con đầu tiên")),
                ],
              ),
            );
          }

          final sortedSales = List<CockSale>.from(vm.globalCockSales)..sort((a, b) => b.date.compareTo(a.date));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sortedSales.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final sale = sortedSales[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.red,
                    child: Icon(Icons.ads_click, color: Colors.white),
                  ),
                  title: Text(sale.note, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(_dateFormat.format(sale.date)),
                  trailing: Text(
                    "${sale.amount.toCurrency()}đ",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                  ),
                ),
              );
            },
          ).webConstrainedBox();
        },
      ),
    );
  }

  void _showAddSaleDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime saleDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Nhập bán gà đá"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: "Giá bán (VNĐ)", prefixText: "đ "),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: "Ghi chú (con gà số mấy, trạng gà...)"),
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
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0) {
                  vm.addGlobalCockSale(
                    CockSale(
                      id: const Uuid().v4(),
                      amount: amount,
                      date: saleDate,
                      note: noteController.text.isEmpty ? "Bán gà đá" : noteController.text,
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
}
