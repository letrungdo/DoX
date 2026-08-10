import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/cock_sale.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/theme/text_theme.dart';
import 'package:do_x/utils/chicken_date.dart';
import 'package:do_x/extensions/date_extensions.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/chicken_add_icon.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:do_x/widgets/chicken_change_badge.dart';
import 'package:do_x/widgets/chicken_stale_banner.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/dialog/low_price_warning_dialog.dart';
import 'package:do_x/widgets/input/cute_segmented_button.dart';
import 'package:do_x/widgets/input/note_field.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/widgets/input/lunar_date_field.dart';
import 'package:do_x/widgets/input/year_filter.dart';
import 'package:do_x/widgets/total_amount_text.dart';
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
  late int _selectedYear;

  /// The year to ask the server for; null when the picker is on "all", which
  /// is the one case that needs every year.
  int? get _yearFilter => _selectedYear == 0 ? null : _selectedYear;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedYear = vm.currentDisplayYear();
  }

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
    vm.ensureLoaded({ChickenSection.globalCockSales}, year: _yearFilter);
  }

  @override
  void onResume() {
    super.onResume();
    vm.ensureLoaded({ChickenSection.globalCockSales}, year: _yearFilter);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      appBar: DoAppBar(
        title: l10n.sellRoosterMeat,
        titleSuffix: AppBarSyncIcon<ChickenViewModel>(
          selector: (vm) => vm.isFetching,
        ),
        actions: [
          ChickenAddButton(
            icon: Assets.images.roosterCute,
            onPressed: vm.isReadOnly ? null : () => _showSaleDialog(),
          ),
        ],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final years = {
            vm.currentDisplayYear(),
            ...vm.yearsFor({ChickenSection.globalCockSales}),
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
              const ChickenStaleBanner(
                sections: {ChickenSection.globalCockSales},
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    YearFilter(
                      selectedYear: _selectedYear,
                      years: years,
                      includeAll: true,
                      onChanged: (year) {
                        setState(() => _selectedYear = year);
                        // A different year is a different list — start it from
                        // the top instead of keeping the old scroll offset.
                        _scrollToTop();
                        // Another year means another read: the server only
                        // sent the one that was selected.
                        vm.ensureLoaded({
                          ChickenSection.globalCockSales,
                        }, year: _yearFilter);
                      },
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
                      style: TextStyle(
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Expanded(child: TotalAmountText(total)),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      vm.loadData(sections: {ChickenSection.globalCockSales}),
                  child: sortedSales.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: constraints.maxHeight,
                                child: vm.isLoading
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
                                              color: context
                                                  .theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                          if (vm.globalCockSales.isEmpty &&
                                              !vm.isReadOnly) ...[
                                            const SizedBox(height: 16),
                                            NeuButton(
                                              onPressed: () =>
                                                  _showSaleDialog(),
                                              accent: context
                                                  .theme
                                                  .colorScheme
                                                  .primary,
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
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                          itemCount: sortedSales.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final sale = sortedSales[index];
                            final isMeat = sale.category == SaleCategory.meat;
                            final accent = isMeat
                                ? context.colors.meat
                                : context.colors.danger;
                            final accentSoft = isMeat
                                ? context.colors.meatSoft
                                : context.colors.dangerSoft;
                            return ChickenListTileCard(
                              onTap: vm.isReadOnly
                                  ? null
                                  : () => _showSaleDialog(sale),
                              leading: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: accentSoft,
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    (isMeat
                                            ? Assets.images.drumstickCute
                                            : Assets.images.roosterCute)
                                        .svg(width: 28, height: 28),
                              ),
                              title: Row(
                                children: [
                                  ChickenChangeBadge(
                                    vm.changeBadgeOf(sale.id),
                                    leading: true,
                                  ),
                                  Flexible(
                                    child: Text(
                                      sale.note,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // Category as a colored tag rather than a word in
                              // the date line: the kind of sale is the thing
                              // being scanned for down the list.
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentSoft,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isMeat
                                            ? l10n.meatChicken
                                            : l10n.fightingChicken,
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.2,
                                          fontWeight: FontWeight.w700,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _fmt(sale.date),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context
                                              .theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Text(
                                "${sale.amount.toCurrency()}đ",
                                style: DoTextTheme.listAmount.copyWith(
                                  color: context.colors.money,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ).contentConstrainedBox();
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
    DateTime saleDate = sale?.date ?? DateTime.now().dateOnly;
    SaleCategory category = sale?.category ?? SaleCategory.fighting;
    String? amountError;

    await showAppModal<void>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: category == SaleCategory.meat
              ? Assets.images.drumstickCute
              : Assets.images.roosterCute,
          title: isEditing ? l10n.editSale : l10n.enterCockSale,
          accent: category == SaleCategory.meat
              ? context.colors.meat
              : context.colors.danger,
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
            // Likely a missing zero, not a real price: confirm before saving.
            if (amount < kSuspiciousPriceThreshold) {
              final saveAnyway = await confirmSuspiciousPrice(context, amount);
              if (!saveAnyway || !context.mounted) return;
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
                _scrollToTop();
              }
              if (context.mounted) Navigator.pop(context);
            } catch (error) {
              if (context.mounted) {
                context.showToast(
                  l10n.saveFailed(error.toString()),
                  isError: true,
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
    final shouldDelete = await showAppModal<bool>(
      context,
      builder: (context) => CuteDialog(
        icon: sale.category == SaleCategory.meat
            ? Assets.images.drumstickCute
            : Assets.images.roosterCute,
        title: l10n.deleteSaleRecord,
        accent: context.colors.danger,
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
        context.showToast(l10n.deleteFailed(error.toString()), isError: true);
      }
    }
  }
}
