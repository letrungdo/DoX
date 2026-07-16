import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/cute_dialog.dart';
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
  SaleCategory? _filter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DoAppBar(
        title: "Bán gà đá / gà thịt",
        actions: [IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _showAddSaleDialog)],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          if (vm.globalCockSales.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Assets.images.roosterCute.svg(width: 72, height: 72),
                  const SizedBox(height: 16),
                  Text("Chưa có dữ liệu bán gà", style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _showAddSaleDialog, child: const Text("Nhập bán con đầu tiên")),
                ],
              ),
            );
          }

          final sortedSales = vm.globalCockSales.where((s) => _filter == null || s.category == _filter).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          final total = sortedSales.fold<double>(0, (sum, s) => sum + s.amount);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text("Tất cả"),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("Gà đá"),
                      selected: _filter == SaleCategory.fighting,
                      onSelected: (_) => setState(() => _filter = SaleCategory.fighting),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("Gà thịt"),
                      selected: _filter == SaleCategory.meat,
                      onSelected: (_) => setState(() => _filter = SaleCategory.meat),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${sortedSales.length} lượt bán", style: TextStyle(color: Colors.grey[600])),
                    Text(
                      "Tổng: ${total.toCurrency()}đ",
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedSales.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final sale = sortedSales[index];
                    final isMeat = sale.category == SaleCategory.meat;
                    final color = isMeat ? Colors.brown : Colors.red;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: color.withValues(alpha: 0.12),
                          child: (isMeat ? Assets.images.drumstickCute : Assets.images.roosterCute).svg(
                            width: 28,
                            height: 28,
                          ),
                        ),
                        title: Text(sale.note, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${_dateFormat.format(sale.date)} · ${isMeat ? 'Gà thịt' : 'Gà đá'}"),
                        trailing: Text(
                          "${sale.amount.toCurrency()}đ",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ).webConstrainedBox();
        },
      ),
    );
  }

  void _showAddSaleDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime saleDate = DateTime.now();
    SaleCategory category = SaleCategory.fighting;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: category == SaleCategory.meat ? Assets.images.drumstickCute : Assets.images.roosterCute,
          title: "Nhập bán gà",
          accent: category == SaleCategory.meat ? Colors.brown : Colors.red,
          confirmText: "Lưu",
          onConfirm: () {
            final amount = double.tryParse(amountController.text) ?? 0;
            if (amount > 0) {
              vm.addGlobalCockSale(
                CockSale(
                  id: const Uuid().v4(),
                  amount: amount,
                  date: saleDate,
                  note: noteController.text.isEmpty
                      ? (category == SaleCategory.meat ? "Bán gà thịt" : "Bán gà đá")
                      : noteController.text,
                  category: category,
                ),
              );
              Navigator.pop(context);
            }
          },
          children: [
            DropdownButtonFormField<SaleCategory>(
              initialValue: category,
              decoration: cuteInputDecoration(context, "Loại gà"),
              borderRadius: BorderRadius.circular(14),
              items: const [
                DropdownMenuItem(value: SaleCategory.fighting, child: Text("Gà đá / gà nòi")),
                DropdownMenuItem(value: SaleCategory.meat, child: Text("Gà thịt")),
              ],
              onChanged: (val) => setState(() => category = val!),
            ),
            CuteTextField(
              controller: amountController,
              label: "Giá bán",
              prefixText: "đ ",
              keyboardType: TextInputType.number,
            ),
            CuteTextField(controller: noteController, label: "Ghi chú (con gà số mấy, trạng gà...)"),
            CuteDateField(label: "Ngày bán", value: saleDate, onChanged: (d) => setState(() => saleDate = d)),
          ],
        ),
      ),
    );
  }
}
