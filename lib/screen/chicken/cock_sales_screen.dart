import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/chicken_add_icon.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/widgets/input/cute_date_field.dart';
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

class _CockSalesScreenState
    extends ScreenState<CockSalesScreen, ChickenViewModel> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  SaleCategory? _filter;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.sellRoosterMeat,
        actions: [
          IconButton(
            icon: ChickenAddIcon(icon: Assets.images.roosterCute),
            onPressed: () => _showSaleDialog(),
          ),
        ],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final years = {
            DateTime.now().year,
            ...vm.globalCockSales.map((sale) => sale.date.year),
          }.toList()..sort((a, b) => b.compareTo(a));
          final sortedSales =
              vm.globalCockSales
                  .where(
                    (sale) =>
                        _selectedYear == 0 || sale.date.year == _selectedYear,
                  )
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
                    Text(
                      l10n.yearLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _selectedYear,
                      items: [
                        DropdownMenuItem(value: 0, child: Text(l10n.all)),
                        ...years.map(
                          (year) => DropdownMenuItem(
                            value: year,
                            child: Text("$year"),
                          ),
                        ),
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
                      label: Text(l10n.all),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(l10n.fightingChicken),
                      selected: _filter == SaleCategory.fighting,
                      onSelected: (_) =>
                          setState(() => _filter = SaleCategory.fighting),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(l10n.meatChicken),
                      selected: _filter == SaleCategory.meat,
                      onSelected: (_) =>
                          setState(() => _filter = SaleCategory.meat),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.saleCount(sortedSales.length),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    Text(
                      l10n.totalAmount("${total.toCurrency()}đ"),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
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
                                    Assets.images.roosterCute.svg(
                                      width: 72,
                                      height: 72,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      vm.globalCockSales.isEmpty
                                          ? l10n.noCockSalesData
                                          : _selectedYear == 0
                                          ? l10n.noMatchingSales
                                          : l10n.noSalesInYear(_selectedYear),
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    if (vm.globalCockSales.isEmpty) ...[
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () => _showSaleDialog(),
                                        child: Text(l10n.enterFirstSale),
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
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final sale = sortedSales[index];
                            final isMeat = sale.category == SaleCategory.meat;
                            final color = isMeat ? Colors.brown : Colors.red;
                            return ChickenListTileCard(
                              onTap: () => _showSaleDialog(sale),
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundColor: color.withValues(alpha: 0.12),
                                child:
                                    (isMeat
                                            ? Assets.images.drumstickCute
                                            : Assets.images.roosterCute)
                                        .svg(width: 28, height: 28),
                              ),
                              title: Text(
                                sale.note,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                "${_dateFormat.format(sale.date)} · ${isMeat ? l10n.meatChicken : l10n.fightingChicken}",
                              ),
                              trailing: Text(
                                "${sale.amount.toCurrency()}đ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: color,
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

  Future<void> _showSaleDialog([CockSale? sale]) async {
    final l10n = AppLocalizations.of(context);
    final isEditing = sale != null;
    final amountController = TextEditingController(
      text: sale == null ? '' : sale.amount.toCurrency(),
    );
    final noteController = TextEditingController(text: sale?.note ?? '');
    DateTime saleDate = sale?.date ?? DateTime.now();
    SaleCategory category = sale?.category ?? SaleCategory.fighting;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: category == SaleCategory.meat
              ? Assets.images.drumstickCute
              : Assets.images.roosterCute,
          title: isEditing ? l10n.editSale : l10n.enterCockSale,
          accent: category == SaleCategory.meat ? Colors.brown : Colors.red,
          confirmText: isEditing ? l10n.update : l10n.save,
          destructiveText: isEditing ? l10n.delete : null,
          onDestructive: isEditing
              ? () {
                  Navigator.pop(context);
                  _confirmDeleteSale(sale);
                }
              : null,
          onConfirm: () async {
            final amount = amountController.text.toMoney() ?? 0;
            if (amount > 0) {
              final updatedSale = CockSale(
                id: sale?.id ?? const Uuid().v4(),
                amount: amount,
                date: saleDate,
                note: noteController.text.trim().isEmpty
                    ? (category == SaleCategory.meat
                          ? l10n.soldMeatChickenNote
                          : l10n.soldFightingChickenNote)
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
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(l10n.saveFailed(error.toString()))),
                  );
                }
              }
            }
          },
          children: [
            SegmentedButton<SaleCategory>(
              segments: [
                ButtonSegment(
                  value: SaleCategory.fighting,
                  label: Text(l10n.fightingChickenFull),
                ),
                ButtonSegment(
                  value: SaleCategory.meat,
                  label: Text(l10n.meatChicken),
                ),
              ],
              selected: {category},
              onSelectionChanged: (selection) =>
                  setState(() => category = selection.first),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            CuteMoneyField(controller: amountController, label: l10n.salePrice),
            CuteTextField(
              controller: noteController,
              label: l10n.cockSaleNoteHint,
            ),
            CuteDateField(
              label: l10n.saleDate,
              value: saleDate,
              onChanged: (d) => setState(() => saleDate = d),
            ),
          ],
        ),
      ),
    );
    // showDialog completes as soon as the route is popped, while its closing
    // animation may still build the TextFields with these controllers.
  }

  Future<void> _confirmDeleteSale(CockSale sale) async {
    final l10n = AppLocalizations.of(context);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => CuteDialog(
        icon: sale.category == SaleCategory.meat
            ? Assets.images.drumstickCute
            : Assets.images.roosterCute,
        title: l10n.deleteSaleRecord,
        accent: Colors.red,
        confirmText: l10n.delete,
        isDestructive: true,
        onConfirm: () => Navigator.pop(context, true),
        children: [
          Text(
            l10n.confirmDeleteSaleRecord(
              _dateFormat.format(sale.date),
              "${sale.amount.toCurrency()}đ",
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await vm.deleteGlobalCockSale(sale.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deleteFailed(error.toString()))),
        );
      }
    }
  }
}
