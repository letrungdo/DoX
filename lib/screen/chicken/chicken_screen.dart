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
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/utils/chicken_date.dart';
import 'package:do_x/utils/lunar_calendar.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/view_model/main_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_loading_bar.dart';
import 'package:do_x/widgets/chicken_add_icon.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:do_x/widgets/input/lunar_date_field.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    vm.ensureBatchesLoaded();
  }

  @override
  void onResume() {
    super.onResume();
    vm.ensureBatchesLoaded();
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
    if (mounted) await vm.loadBatches();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.chickenManagement,
        bottom: AppBarLoadingBar<ChickenViewModel>(
          selector: (vm) => vm.isBatchesLoading,
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
                    style: const TextStyle(color: Colors.red),
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
            ...vm.batches.map(
              (batch) => vm.displayYear(
                batch.actualHatchDate ?? batch.expectedHatchDate,
              ),
            ),
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
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    "${l10n.yearPrefix} $year",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              );
            }
            items.add(_buildBatchCard(batch));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        icon: Assets.images.feedCute.svg(width: 32, height: 32),
                        title: l10n.commonExpenses,
                        color: Colors.orange,
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
                        color: Colors.red,
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
                  onRefresh: () => vm.loadBatches(showLoading: true),
                  child: items.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: constraints.maxHeight,
                                child: vm.isBatchesLoading
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
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
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
            ],
          ),
        ),
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

    // Freshly added rows get a highlight; otherwise: sold out → red,
    // partially sold → green, not sold → default card color.
    final isDark = context.theme.brightness == Brightness.dark;
    final Color? cardColor = batch.id == vm.highlightedId
        ? context.theme.colorScheme.primary.withValues(alpha: 0.18)
        : isSoldOut
        ? (isDark ? Colors.red[900]?.withValues(alpha: 0.38) : Colors.red[100])
        : isPartiallySold
        ? (isDark ? Colors.green[900]?.withValues(alpha: 0.24) : Colors.green[50])
        : null;

    // Darker shades in light theme so the status text reads clearly against
    // its tinted background; brighter shades stay legible in dark theme.
    final (statusText, statusColor) = !isHatched
        ? (
            l10n.statusWaitingHatch(ChickenDate.format(batch.expectedHatchDate, useLunar: useLunar)),
            isDark ? Colors.orange : Colors.orange[900]!,
          )
        : isSoldOut
        ? (l10n.statusSoldOut, isDark ? Colors.grey : Colors.grey[700]!)
        : (
            ChickenDate.formatAge(l10n, batch.ageInDays),
            isDark ? Colors.green : Colors.green[800]!,
          );

    return ChickenListTileCard(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      title: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: statusColor.withValues(alpha: 0.12),
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
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
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
                    context.colors.money,
                  ),
                  if (batch.totalExpenses > 0)
                    _buildMoneyBadge(
                      l10n.badgeExpense,
                      batch.totalExpenses,
                      Colors.orange,
                    ),
                  _buildMoneyBadge(
                    l10n.badgeProfit,
                    batch.profit,
                    batch.profit >= 0 ? context.colors.money : Colors.red,
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
        ? Theme.of(context).colorScheme.primary
        : Colors.grey[600];
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
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
        SnackBar(
          content: Text(l10n.importFileFailed(e.toString())),
          backgroundColor: Colors.red,
        ),
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
        accent: Colors.red,
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
        SnackBar(
          content: Text(l10n.deleteDataFailed(e.toString())),
          backgroundColor: Colors.red,
        ),
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
            vm
                .addBatch(
                  name: name,
                  incubationDate: selectedDate,
                  quantity: qty,
                )
                .then((batch) => vm.flashHighlight(batch.id));
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
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
