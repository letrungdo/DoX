import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/chicken_date.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_loading_bar.dart';
import 'package:do_x/widgets/chicken_add_icon.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/input/cute_segmented_button.dart';
import 'package:do_x/widgets/input/note_field.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/widgets/input/lunar_date_field.dart';
import 'package:do_x/widgets/input/year_filter.dart';
import 'package:flutter/material.dart';
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
  String _fmt(DateTime date) =>
      ChickenDate.format(date, useLunar: vm.useLunarCalendar);
  SaleCategory? _filter;
  int _selectedYear = DateTime.now().year;
  final _scrollController = ScrollController();

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
    vm.ensureCockSalesLoaded();
  }

  @override
  void onResume() {
    super.onResume();
    vm.ensureCockSalesLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.sellRoosterMeat,
        bottom: AppBarLoadingBar<ChickenViewModel>(
          selector: (vm) => vm.isCockSalesLoading,
        ),
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
            ...vm.globalCockSales.map((sale) => vm.displayYear(sale.date)),
          }.toList()..sort((a, b) => b.compareTo(a));
          final sortedSales = vm.globalCockSales
              .where(
                (sale) =>
                    _selectedYear == 0 ||
                    vm.displayYear(sale.date) == _selectedYear,
              )
              .where((sale) => _filter == null || sale.category == _filter)
              .toList();
          // Stable sort by date desc so a same-date sale added last stays on top.
          mergeSort(sortedSales, compare: (a, b) => b.date.compareTo(a.date));
          final total = sortedSales.fold<double>(0, (sum, s) => sum + s.amount);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    YearFilter(
                      selectedYear: _selectedYear,
                      years: years,
                      includeAll: true,
                      onChanged: (year) =>
                          setState(() => _selectedYear = year),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CuteSegmentedButton<SaleCategory?>(
                    segments: [
                      ButtonSegment(value: null, label: Text(l10n.all)),
                      ButtonSegment(
                        value: SaleCategory.fighting,
                        label: Text(l10n.fightingChicken),
                      ),
                      ButtonSegment(
                        value: SaleCategory.meat,
                        label: Text(l10n.meatChicken),
                      ),
                    ],
                    value: _filter,
                    onChanged: (val) => setState(() => _filter = val),
                  ),
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
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "${l10n.totalLabel}: ",
                            style: TextStyle(
                              color: context.theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextSpan(
                            text: "${total.toCurrency()}đ",
                            style: TextStyle(color: context.colors.money),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => vm.loadCockSales(showLoading: true),
                  child: sortedSales.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: constraints.maxHeight,
                                child: vm.isCockSalesLoading
                                    ? const SizedBox.shrink()
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                                : l10n.noSalesInYear(
                                                    _selectedYear,
                                                  ),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                            ),
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
                          controller: _scrollController,
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
                              color: sale.id == vm.highlightedId
                                  ? context.theme.colorScheme.primary
                                        .withValues(alpha: 0.18)
                                  : null,
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
                                "${_fmt(sale.date)} · ${isMeat ? l10n.meatChicken : l10n.fightingChicken}",
                              ),
                              trailing: Text(
                                "${sale.amount.toCurrency()}đ",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: context.colors.money,
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
    DateTime saleDate = sale?.date ?? LunarCalendar.solarToLunarDateTime(DateTime.now());
    SaleCategory category = sale?.category ?? SaleCategory.fighting;
    String? amountError;

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
            if (amount <= 0) {
              setState(() => amountError = l10n.errorEnterAmount);
              return;
            }
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
                vm.flashHighlight(updatedSale.id);
                _scrollToTop();
              }
              if (context.mounted) Navigator.pop(context);
            } catch (error) {
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(l10n.saveFailed(error.toString()))),
                );
              }
            }
          },
          children: [
            CuteSegmentedButton<SaleCategory>(
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
              value: category,
              onChanged: (val) => setState(() => category = val),
            ),
            CuteMoneyField(
              controller: amountController,
              label: l10n.salePrice,
              autofocus: !isEditing,
              presetSuggestions: const [
                250000,
                500000,
                1000000,
                1500000,
                2000000,
                3000000,
                5000000,
                10000000,
              ],
              errorText: amountError,
              onChanged: (_) {
                if (amountError != null) setState(() => amountError = null);
              },
            ),
            NoteField(
              controller: noteController,
              label: l10n.cockSaleNoteHint,
              suggestions: vm.cockSaleNoteSuggestions,
            ),
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
              _fmt(sale.date),
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
