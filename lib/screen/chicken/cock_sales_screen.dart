import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/chicken_add_icon.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
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
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DoAppBar(
        title: "Bán gà đá / gà thịt",
        actions: [
          IconButton(
            icon: ChickenAddIcon(icon: Assets.images.roosterCute),
            onPressed: () => _showSaleDialog(),
          ),
        ],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final years = {DateTime.now().year, ...vm.globalCockSales.map((sale) => sale.date.year)}.toList()
            ..sort((a, b) => b.compareTo(a));
          final sortedSales =
              vm.globalCockSales
                  .where((sale) => _selectedYear == 0 || sale.date.year == _selectedYear)
                  .where((sale) => _filter == null || sale.category == _filter)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));
          final total = sortedSales.fold<double>(0, (sum, s) => sum + s.amount);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 20),
                    const SizedBox(width: 8),
                    const Text("Năm:", style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _selectedYear,
                      items: [
                        const DropdownMenuItem(value: 0, child: Text("Tất cả")),
                        ...years.map((year) => DropdownMenuItem(value: year, child: Text("$year"))),
                      ],
                      onChanged: (year) {
                        if (year != null) setState(() => _selectedYear = year);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                child: RefreshIndicator(
                  onRefresh: vm.refreshData,
                  child: sortedSales.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: constraints.maxHeight,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Assets.images.roosterCute.svg(width: 72, height: 72),
                                    const SizedBox(height: 16),
                                    Text(
                                      vm.globalCockSales.isEmpty
                                          ? "Chưa có dữ liệu bán gà"
                                          : _selectedYear == 0
                                          ? "Không có lượt bán phù hợp."
                                          : "Không có lượt bán trong năm $_selectedYear.",
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    if (vm.globalCockSales.isEmpty) ...[
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () => _showSaleDialog(),
                                        child: const Text("Nhập bán con đầu tiên"),
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
                          padding: const EdgeInsets.all(16),
                          itemCount: sortedSales.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final sale = sortedSales[index];
                            final isMeat = sale.category == SaleCategory.meat;
                            final color = isMeat ? Colors.brown : Colors.red;
                            return ChickenListTileCard(
                              onTap: () => _showSaleDialog(sale),
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

  Future<void> _showSaleDialog([CockSale? sale]) async {
    final isEditing = sale != null;
    final amountController = TextEditingController(
      text: sale == null
          ? ''
          : sale.amount == sale.amount.truncateToDouble()
          ? sale.amount.toStringAsFixed(0)
          : sale.amount.toString(),
    );
    final noteController = TextEditingController(text: sale?.note ?? '');
    DateTime saleDate = sale?.date ?? DateTime.now();
    SaleCategory category = sale?.category ?? SaleCategory.fighting;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: category == SaleCategory.meat ? Assets.images.drumstickCute : Assets.images.roosterCute,
          title: isEditing ? "Chỉnh sửa lượt bán" : "Nhập bán gà",
          accent: category == SaleCategory.meat ? Colors.brown : Colors.red,
          confirmText: isEditing ? "Cập nhật" : "Lưu",
          onConfirm: () async {
            final amount = double.tryParse(amountController.text) ?? 0;
            if (amount > 0) {
              final updatedSale = CockSale(
                id: sale?.id ?? const Uuid().v4(),
                amount: amount,
                date: saleDate,
                note: noteController.text.trim().isEmpty
                    ? (category == SaleCategory.meat ? "Bán gà thịt" : "Bán gà đá")
                    : noteController.text.trim(),
                category: category,
              );
              try {
                if (isEditing) {
                  await vm.updateGlobalCockSale(updatedSale);
                } else {
                  await vm.addGlobalCockSale(updatedSale);
                }
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text("Lưu thất bại: $error")));
                }
              }
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
            if (isEditing)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDeleteSale(sale);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text("Xóa lượt bán"),
              ),
          ],
        ),
      ),
    );
    // showDialog completes as soon as the route is popped, while its closing
    // animation may still build the TextFields with these controllers.
  }

  Future<void> _confirmDeleteSale(CockSale sale) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => CuteDialog(
        icon: sale.category == SaleCategory.meat ? Assets.images.drumstickCute : Assets.images.roosterCute,
        title: "Xóa lượt bán",
        accent: Colors.red,
        confirmText: "Xóa",
        onConfirm: () => Navigator.pop(context, true),
        children: [
          Text(
            "Xóa lượt bán ngày ${_dateFormat.format(sale.date)} (${sale.amount.toCurrency()}đ)?",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await vm.deleteGlobalCockSale(sale.id);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xóa thất bại: $error")));
    }
  }
}
