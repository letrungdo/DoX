import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/chicken_date.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/view_model/main_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/chicken_add_icon.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:do_x/widgets/chicken_change_badge.dart';
import 'package:do_x/widgets/chicken_stale_banner.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:do_x/widgets/input/lunar_date_field.dart';
import 'package:do_x/widgets/input/year_filter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';
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
  int _selectedYear = DateTime.now().year;

  /// The year to ask the server for; null when the picker is on "all", which
  /// is the one case that needs every year.
  int? get _yearFilter => _selectedYear == 0 ? null : _selectedYear;
  final _scrollController = ScrollController();
  MainViewModel? _mainViewModel;
  late final Future<void> Function() _tabReselectHandler;

  @override
  void initState() {
    _tabReselectHandler = _handleTabReselect;
    super.initState();
  }

  @override
  void initData() {
    super.initData();
    vm.ensureLoaded({ChickenSection.batches}, year: _yearFilter);
  }

  @override
  void onResume() {
    super.onResume();
    vm.ensureLoaded({ChickenSection.batches}, year: _yearFilter);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mainViewModel = context.read<MainViewModel>();
    if (identical(_mainViewModel, mainViewModel)) return;
    _mainViewModel?.unregisterTabReselectHandler(
      ChickenRoute.name,
      _tabReselectHandler,
    );
    _mainViewModel = mainViewModel;
    mainViewModel.registerTabReselectHandler(
      ChickenRoute.name,
      _tabReselectHandler,
    );
  }

  @override
  void dispose() {
    _mainViewModel?.unregisterTabReselectHandler(
      ChickenRoute.name,
      _tabReselectHandler,
    );
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls the list back to the top (e.g. after a new record is added, which
  /// appears at the top). Waits a frame so the new item is laid out first.
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

  Future<void> _handleTabReselect() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    if (mounted) await vm.loadData(sections: {ChickenSection.batches});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.chickenManagement,
        titleSuffix: AppBarSyncIcon<ChickenViewModel>(
          selector: (vm) => vm.isFetching,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () =>
                context.router.push(const ChickenStatisticsRoute()),
            tooltip: l10n.profitStatistics,
          ),
          IconButton(
            icon: ChickenAddIcon(icon: Assets.images.chickCute),
            onPressed: _showAddBatchDialog,
          ),
          if (kDebugMode)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'import':
                    _importFromJsonFile();
                  case 'delete_all':
                    _showDeleteAllDataDialog();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'import', child: Text(l10n.importData)),
                PopupMenuItem(
                  value: 'delete_all',
                  child: Text(
                    l10n.deleteAllChickenData,
                    style: TextStyle(color: context.colors.danger),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final years = {
            DateTime.now().year,
            ...vm.yearsFor({ChickenSection.batches}),
          }.toList()..sort((a, b) => b.compareTo(a));
          final batches = _selectedYear == 0
              ? vm.batches
              : vm.batches
                    .where(
                      (batch) =>
                          vm.displayYear(
                            batch.actualHatchDate ?? batch.expectedHatchDate,
                          ) ==
                          _selectedYear,
                    )
                    .toList();
          final totalRevenue = batches.fold<double>(
            0,
            (sum, batch) => sum + batch.totalSaleAmount + batch.totalCockSales,
          );

          final items = <Widget>[];
          int? currentYear;
          for (final batch in batches) {
            final year = vm.displayYear(
              batch.actualHatchDate ?? batch.expectedHatchDate,
            );
            if (_selectedYear == 0 && year != currentYear) {
              currentYear = year;
              items.add(
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 6),
                  child: Row(
                    children: [
                      Text(
                        "${l10n.yearPrefix} $year",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Divider(
                          height: 1,
                          color: context.theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            items.add(_buildBatchCard(batch));
          }

          return Column(
            children: [
              const ChickenStaleBanner(sections: {ChickenSection.batches}),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        icon: Assets.images.feedCute.svg(width: 32, height: 32),
                        title: l10n.commonExpenses,
                        accent: context.colors.warning,
                        accentSoft: context.colors.warningSoft,
                        onTap: () =>
                            context.router.push(const GlobalExpensesRoute()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildFeatureCard(
                        icon: Assets.images.roosterCute.svg(
                          width: 32,
                          height: 32,
                        ),
                        title: l10n.sellGrownChicken,
                        accent: context.colors.danger,
                        accentSoft: context.colors.dangerSoft,
                        onTap: () =>
                            context.router.push(const CockSalesRoute()),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
                          ChickenSection.batches,
                        }, year: _yearFilter);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: "${l10n.totalLabel}: ",
                                style: TextStyle(
                                  color: context
                                      .theme
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              TextSpan(
                                text: "${totalRevenue.toCurrency()}đ",
                                style: TextStyle(color: context.colors.money),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      vm.loadData(sections: {ChickenSection.batches}),
                  child: items.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            controller: _scrollController,
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
                                          Assets.images.chickCute.svg(
                                            width: 72,
                                            height: 72,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _selectedYear == 0
                                                ? l10n.noBatchesYet
                                                : l10n.noBatchesInYear(
                                                    _selectedYear,
                                                  ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: items,
                        ),
                ),
              ),
            ],
          );
        },
      ).webConstrainedBox(),
    );
  }

  Widget _buildFeatureCard({
    required Widget icon,
    required String title,
    required Color accent,
    required Color accentSoft,
    required VoidCallback onTap,
  }) {
    // The tap belongs to the card, not to an inner InkWell: that way the whole
    // panel flattens while held and the ripple is clipped to its rounded shape.
    return NeuCard(
      margin: EdgeInsets.zero,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: icon,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.theme.colorScheme.onSurfaceVariant.withValues(
              alpha: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(ChickenBatch batch) {
    final l10n = AppLocalizations.of(context);
    final useLunar = vm.useLunarCalendar;
    final hatchDate = batch.actualHatchDate ?? batch.expectedHatchDate;
    final isHatched =
        batch.actualHatchDate != null ||
        DateTime.now().isAfter(batch.expectedHatchDateSolar);
    final isSoldOut = batch.sales.isNotEmpty && batch.remainingQuantity <= 0;
    final isPartiallySold = batch.sales.isNotEmpty && !isSoldOut;
    final hasMoney =
        batch.sales.isNotEmpty ||
        batch.expenses.isNotEmpty ||
        batch.cockSales.isNotEmpty;

    // Sold out → red, partially sold → green, not sold → default card color.
    // The tints come from the theme so they stay soft on a light background and
    // deep on a dark one, instead of a raw Material shade that only reads well
    // in one of the two.
    final colors = context.colors;
    final Color? cardColor = isSoldOut
        ? colors.dangerSoft
        : isPartiallySold
        ? colors.successSoft
        : null;

    final (statusText, statusColor) = !isHatched
        ? (
            l10n.statusWaitingHatch(ChickenDate.format(batch.expectedHatchDate, useLunar: useLunar)),
            colors.warning,
          )
        : isSoldOut
        ? (l10n.statusSoldOut, context.theme.colorScheme.onSurfaceVariant)
        : (ChickenDate.formatAge(l10n, batch.ageInDays), colors.success);

    return ChickenListTileCard(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: context.theme.colorScheme.surface,
            child:
                (!isHatched
                        ? Assets.images.eggCute
                        : isSoldOut
                        ? Assets.images.henCute
                        : Assets.images.chickCute)
                    .svg(width: 30, height: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              batch.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Badge sits above the age pill, in the same right-hand column.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ChickenChangeBadge(vm.changeBadgeOf(batch.id)),
              if (vm.changeBadgeOf(batch.id) != null)
                const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildBatchInfo(
                    null,
                    batch.sales.isEmpty
                        ? l10n.chickenQuantity(batch.quantity)
                        : l10n.soldOfTotal(batch.soldQuantity, batch.quantity),
                    highlighted: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildBatchInfo(
                        Icons.calendar_today_rounded,
                        l10n.hatchedOnDate(ChickenDate.format(hatchDate, useLunar: useLunar)),
                        alignment: MainAxisAlignment.end,
                      ),
                      if (batch.lastSaleDate != null) ...[
                        const SizedBox(height: 4),
                        _buildBatchInfo(
                          Icons.sell_rounded,
                          l10n.soldOnDate(
                            ChickenDate.format(batch.lastSaleDate!, useLunar: useLunar),
                          ),
                          alignment: MainAxisAlignment.end,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (hasMoney) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMoneyBadge(
                    l10n.badgeRevenue,
                    batch.totalSaleAmount + batch.totalCockSales,
                    colors.money,
                  ),
                  if (batch.totalExpenses > 0)
                    _buildMoneyBadge(
                      l10n.badgeExpense,
                      batch.totalExpenses,
                      colors.warning,
                    ),
                  _buildMoneyBadge(
                    l10n.badgeProfit,
                    batch.profit,
                    batch.profit >= 0 ? colors.money : colors.danger,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      onTap: () {
        context.router.push(ChickenBatchDetailRoute(batchId: batch.id));
      },
    );
  }

  Widget _buildBatchInfo(
    IconData? icon,
    String text, {
    MainAxisAlignment alignment = MainAxisAlignment.start,
    bool highlighted = false,
  }) {
    final color = highlighted
        ? context.theme.colorScheme.primary
        : context.theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: alignment,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoneyBadge(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        // Opaque surface rather than a translucent tint: these badges also sit
        // on tinted cards, where a translucent fill turns muddy.
        color: context.theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        "$label ${amount.toCurrency()}đ",
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _importFromJsonFile() async {
    final l10n = AppLocalizations.of(context);
    const jsonTypeGroup = XTypeGroup(
      label: 'JSON',
      extensions: ['json'],
      mimeTypes: ['application/json'],
      uniformTypeIdentifiers: ['public.json'],
    );

    BuildContext? progressDialogContext;
    try {
      final file = await openFile(acceptedTypeGroups: [jsonTypeGroup]);
      if (file == null) return;

      var jsonString = utf8.decode(await file.readAsBytes());
      if (jsonString.startsWith('\uFEFF')) {
        jsonString = jsonString.substring(1);
      }

      progressDialogContext = await _showImportProgressDialog();
      final count = await vm.importFromJson(jsonString);
      if (progressDialogContext.mounted) Navigator.pop(progressDialogContext);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importedRecords(count, file.name))),
      );
    } catch (e) {
      final dialogContext = progressDialogContext;
      if (dialogContext != null && dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        context.errorSnackBar(l10n.importFileFailed(e.toString())),
      );
    }
  }

  Future<BuildContext> _showImportProgressDialog() {
    final shown = Completer<BuildContext>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!shown.isCompleted) shown.complete(dialogContext);
        return PopScope(
          canPop: false,
          child: Consumer<ChickenViewModel>(
            builder: (context, vm, child) {
              final percent = (vm.importProgress * 100).round();
              return AlertDialog(
                title: Text(AppLocalizations.of(context).importingData),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(value: vm.importProgress),
                    const SizedBox(height: 12),
                    Text("$percent%"),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    return shown.future;
  }

  void _showDeleteAllDataDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => CuteDialog(
        title: l10n.confirmDeleteAllChickenData,
        accent: context.colors.danger,
        confirmText: l10n.deleteData,
        isDestructive: true,
        onConfirm: () {
          Navigator.pop(dialogContext);
          _deleteAllData();
        },
        children: [
          Text(l10n.deleteAllChickenDataWarning, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _deleteAllData() async {
    final l10n = AppLocalizations.of(context);
    final shown = Completer<BuildContext>();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (!shown.isCompleted) shown.complete(dialogContext);
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(l10n.deletingData),
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(l10n.pleaseWait)),
              ],
            ),
          ),
        );
      },
    );
    final dialogContext = await shown.future;

    try {
      final count = await vm.deleteAllData();
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (!mounted) return;
      final message = count == 0
          ? l10n.noDataToDelete
          : l10n.deletedAllData(count);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        context.errorSnackBar(l10n.deleteDataFailed(e.toString())),
      );
    }
  }

  /// Adds a batch. If the insert fails the view model has already removed it
  /// again locally, so the user is told it wasn't saved.
  Future<void> _addBatch(String name, DateTime incubationDate, int qty) async {
    final l10n = AppLocalizations.of(context);
    try {
      await vm.addBatch(
        name: name,
        incubationDate: incubationDate,
        quantity: qty,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveFailed(error.toString()))),
      );
    }
  }

  void _showAddBatchDialog() {
    final l10n = AppLocalizations.of(context);
    // Prefill "Bầy xx" continuing the latest batch's number (if its name ends with one).
    var suggestedName = '';
    if (vm.batches.isNotEmpty) {
      final match = RegExp(
        r'(\d+)\s*$',
      ).firstMatch(vm.batches.first.name.trim());
      if (match != null) {
        suggestedName = l10n.batchNamePrefill(int.parse(match.group(1)!) + 1);
      }
    }
    final nameController = TextEditingController(text: suggestedName);
    final quantityController = TextEditingController();
    DateTime selectedDate = LunarCalendar.solarToLunarDateTime(DateTime.now());
    String? nameError;
    String? qtyError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.eggCute,
          title: l10n.addNewBatch,
          confirmText: l10n.add,
          onConfirm: () {
            final name = nameController.text.trim();
            final qty = int.tryParse(quantityController.text) ?? 0;
            if (name.isEmpty || qty <= 0) {
              setState(() {
                nameError = name.isEmpty ? l10n.errorEnterBatchName : null;
                qtyError = qty <= 0 ? l10n.errorEnterQuantity : null;
              });
              return;
            }
            unawaited(_addBatch(name, selectedDate, qty));
            _scrollToTop();
            Navigator.pop(context);
          },
          children: [
            CuteTextField(
              controller: nameController,
              label: l10n.batchName,
              hint: l10n.batchNameHint,
              errorText: nameError,
              onChanged: (_) {
                if (nameError != null) setState(() => nameError = null);
              },
            ),
            CuteTextField(
              controller: quantityController,
              label: l10n.eggQuantity,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                NoLeadingZeroInputFormatter(),
              ],
              errorText: qtyError,
              onChanged: (_) {
                if (qtyError != null) setState(() => qtyError = null);
              },
            ),
            LunarDateField(
              label: l10n.incubationDate,
              value: selectedDate,
              useLunar: vm.useLunarCalendar,
              onChanged: (d) => setState(() => selectedDate = d),
            ),
          ],
        ),
      ),
    );
  }
}
