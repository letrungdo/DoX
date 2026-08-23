import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/screen/chicken/chicken_sharing_dialog.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/core/tab_reselect.mixin.dart';
import 'package:do_x/theme/text_theme.dart';
import 'package:do_x/utils/chicken_date.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/chicken_add_icon.dart';
import 'package:do_x/widgets/chicken_list_tile_card.dart';
import 'package:do_x/widgets/chicken_change_badge.dart';
import 'package:do_x/widgets/chicken_stale_banner.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/input/cute_money_field.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:do_x/widgets/input/lunar_date_field.dart';
import 'package:do_x/widgets/input/year_filter.dart';
import 'package:do_x/widgets/total_amount_text.dart';
import 'package:flutter/services.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:do_x/widgets/neu/neu_surface.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Everything the app bar's overflow menu can do. Statistics and add sit in the
/// bar itself; the rest is filed here so it stays readable in landscape too.
enum _ChickenMenuAction { sharing, settings }

@RoutePage()
class ChickenScreen extends StatefulScreen implements AutoRouteWrapper {
  const ChickenScreen({super.key});

  @override
  State<ChickenScreen> createState() => _ChickenScreenState();

  @override
  Widget wrappedRoute(BuildContext context) => this;
}

class _ChickenScreenState extends ScreenState<ChickenScreen, ChickenViewModel>
    with TabReselect {
  late int _selectedYear;

  /// The year to ask the server for; null when the picker is on "all", which
  /// is the one case that needs every year.
  int? get _yearFilter => _selectedYear == 0 ? null : _selectedYear;
  final _scrollController = ScrollController();
  final _menuButtonKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    _selectedYear = vm.currentDisplayYear();
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
  void dispose() {
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

  @override
  String get tabRouteName => ChickenRoute.name;

  @override
  ScrollController get tabScrollController => _scrollController;

  @override
  Future<void> onTabRefresh() =>
      vm.loadData(sections: {ChickenSection.batches});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Watched narrowly: the app bar sits outside the body's Consumer, and only
    // this one flag decides whether the title is a picker.
    final hasOtherDataSources = context.select<ChickenViewModel, bool>(
      (vm) => vm.dataSources.length > 1,
    );
    return AppScaffold(
      appBar: DoAppBar(
        title: l10n.chickenManagement,
        // With someone else's data shared in, the title doubles as the source
        // picker — the same idea as the movie screen's server picker.
        onTitleTap: hasOtherDataSources ? _showDataSourcePicker : null,
        // The caret belongs to the title, so it sits right against it; the sync
        // icon is its own thing and keeps the usual gap.
        titleSuffixSpacing: hasOtherDataSources ? 2 : 8,
        titleSuffix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasOtherDataSources) ...[
              Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
            ],
            AppBarSyncIcon<ChickenViewModel>(selector: (vm) => vm.isFetching),
          ],
        ),
        actions: [
          NeuIconButton(
            size: Dimens.appBarActionSize,
            iconSize: 18,
            depth: Dimens.appBarActionDepth,
            icon: Icons.bar_chart_rounded,
            tooltip: l10n.profitStatistics,
            onPressed: () =>
                context.router.push(const ChickenStatisticsRoute()),
          ),
          const SizedBox(width: 8),
          Consumer<ChickenViewModel>(
            builder: (context, vm, child) => ChickenAddButton(
              icon: Assets.images.chickCute,
              onPressed: vm.isReadOnly ? null : _showAddBatchDialog,
            ),
          ),
          const SizedBox(width: 8),
          NeuIconButton(
            key: _menuButtonKey,
            size: Dimens.appBarActionSize,
            iconSize: 18,
            depth: Dimens.appBarActionDepth,
            icon: Icons.more_vert_rounded,
            onPressed: _showOverflowMenu,
          ),
        ],
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final years = {
            vm.currentDisplayYear(),
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
                      const SizedBox(width: 14),
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

          // Landscape leaves so little height that a pinned header would take
          // most of it, so there the header rides the list instead.
          final isLandscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;

          final header = <Widget>[
            if (vm.isReadOnly)
              Material(
                color: context.theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.sharedReadOnly(vm.activeOwnerEmail ?? ''),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildFeatureCard(
                      icon: Assets.images.roosterCute.svg(
                        width: 32,
                        height: 32,
                      ),
                      title: l10n.sellGrownChicken,
                      accent: context.colors.danger,
                      accentSoft: context.colors.dangerSoft,
                      onTap: () => context.router.push(const CockSalesRoute()),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                  Expanded(child: TotalAmountText(totalRevenue)),
                ],
              ),
            ),
          ];

          final emptyState = vm.isLoading
              ? const SizedBox.shrink()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Assets.images.chickCute.svg(width: 72, height: 72),
                    const SizedBox(height: 12),
                    Text(
                      _selectedYear == 0
                          ? l10n.noBatchesYet
                          : l10n.noBatchesInYear(_selectedYear),
                    ),
                  ],
                );

          return Column(
            children: [
              if (!isLandscape) ...header,
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
                              if (isLandscape) ...header,
                              isLandscape
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 32,
                                      ),
                                      child: emptyState,
                                    )
                                  : SizedBox(
                                      height: constraints.maxHeight,
                                      child: emptyState,
                                    ),
                            ],
                          ),
                        )
                      : ListView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            if (isLandscape) ...header,
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: items,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ).contentConstrainedBox(),
    );
  }

  PopupMenuItem<_ChickenMenuAction> _menuItem(
    _ChickenMenuAction action,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  /// Anchored under the button by hand, the way the movie screen does it: a
  /// `PopupMenuButton` would draw its own plain icon in place of the neu one.
  Future<void> _showOverflowMenu() async {
    final l10n = AppLocalizations.of(context);
    final button =
        _menuButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromPoints(topLeft, topLeft + button.size.bottomRight(Offset.zero)),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<_ChickenMenuAction>(
      context: context,
      position: position,
      items: [
        _menuItem(
          _ChickenMenuAction.sharing,
          Icons.group_outlined,
          l10n.chickenSharing,
        ),
        _menuItem(
          _ChickenMenuAction.settings,
          Icons.settings_outlined,
          l10n.settings,
        ),
      ],
    );
    if (selected == null || !mounted) return;
    _onMenuAction(selected);
  }

  void _onMenuAction(_ChickenMenuAction action) {
    switch (action) {
      case _ChickenMenuAction.sharing:
        unawaited(showChickenSharingDialog(context));
      case _ChickenMenuAction.settings:
        context.router.push(const ChickenSettingsRoute());
    }
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
              borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
            ),
            child: icon,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
        DateTime.now().isAfter(batch.expectedHatchDate);
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
            l10n.statusWaitingHatch(
              ChickenDate.format(batch.expectedHatchDate, useLunar: useLunar),
            ),
            colors.warning,
          )
        : isSoldOut
        ? (l10n.statusSoldOut, context.theme.colorScheme.onSurfaceVariant)
        : (ChickenDate.formatAge(l10n, batch.ageInDays), colors.success);

    return ChickenListTileCard(
      margin: const EdgeInsets.only(bottom: 14),
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
              if (vm.changeBadgeOf(batch.id) != null) const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  // Tinted fill instead of an outline: the pill carries its
                  // colour the same way every other chip in the app does.
                  color: context.neuTint(statusColor),
                  borderRadius: BorderRadius.circular(
                    Dimens.radiusControlSmall,
                  ),
                ),
                child: Text(
                  statusText,
                  style: DoTextTheme.pill.copyWith(
                    fontSize: 12,
                    color: statusColor,
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
                        l10n.hatchedOnDate(
                          ChickenDate.format(hatchDate, useLunar: useLunar),
                        ),
                        alignment: MainAxisAlignment.end,
                      ),
                      if (batch.lastSaleDate != null) ...[
                        const SizedBox(height: 4),
                        _buildBatchInfo(
                          Icons.sell_rounded,
                          l10n.soldOnDate(
                            ChickenDate.format(
                              batch.lastSaleDate!,
                              useLunar: useLunar,
                            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        // Opaque tint of the badge's own colour, blended onto whatever card it
        // sits on — a translucent fill turns muddy on the tinted rows.
        color: context.neuTint(color),
        borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
      ),
      child: Text(
        "$label ${amount.toCurrency()}đ",
        style: DoTextTheme.pill.copyWith(fontSize: 12, color: color),
      ),
    );
  }

  /// Adds a batch. If the insert fails the view model has already removed it
  /// again locally, so the user is told it wasn't saved.
  Future<void> _addBatch(
    String name,
    DateTime incubationDate,
    int qty, {
    DateTime? actualHatchDate,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      await vm.addBatch(
        name: name,
        incubationDate: incubationDate,
        quantity: qty,
        actualHatchDate: actualHatchDate,
      );
    } catch (error) {
      if (!mounted) return;
      context.showToast(l10n.saveFailed(error.toString()), isError: true);
    }
  }

  Future<void> _showDataSourcePicker() async {
    final l10n = AppLocalizations.of(context);
    await vm.loadSharing();
    if (!mounted) return;
    await showAppBottomSheet<void>(
      context,
      title: l10n.viewChickenDataFrom,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          for (final source in vm.dataSources)
            ListTile(
              leading: Icon(
                source.isOwner
                    ? Icons.person_outline
                    : Icons.visibility_outlined,
              ),
              title: Text(source.isOwner ? l10n.myChickenData : source.email),
              subtitle: source.isOwner
                  ? Text(source.email)
                  : Text(l10n.readOnly),
              trailing: source.ownerId == vm.activeOwnerId
                  ? const Icon(Icons.check)
                  : null,
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  await vm.selectDataSource(source);
                } catch (error) {
                  if (!mounted) return;
                  context.showToast(error.toString(), isError: true);
                }
              },
            ),
        ],
      ),
    );
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
    // The two dates are one value seen from either end: both start empty, the
    // user fills in whichever they know and the other follows, 21 incubation
    // days apart. Whichever one was typed is the real one — a typed hatch date
    // means the chicks are already out, so it is recorded as the actual hatch
    // date; a typed incubation date leaves the hatch date a mere expectation.
    DateTime? incubationDate;
    DateTime? hatchDate;
    bool hatchDateIsActual = false;
    String? nameError;
    String? qtyError;
    String? dateError;

    showAppModal(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => CuteDialog(
          icon: Assets.images.eggCute,
          title: l10n.addNewBatch,
          confirmText: l10n.add,
          onConfirm: () {
            final name = nameController.text.trim();
            final qty = int.tryParse(quantityController.text) ?? 0;
            final incubation = incubationDate;
            if (name.isEmpty || qty <= 0 || incubation == null) {
              setState(() {
                nameError = name.isEmpty ? l10n.errorEnterBatchName : null;
                qtyError = qty <= 0 ? l10n.errorEnterQuantity : null;
                dateError = incubation == null
                    ? l10n.errorEnterIncubationOrHatchDate
                    : null;
              });
              return;
            }
            unawaited(
              _addBatch(
                name,
                incubation,
                qty,
                actualHatchDate: hatchDateIsActual ? hatchDate : null,
              ),
            );
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
              value: incubationDate,
              useLunar: vm.useLunarCalendar,
              errorText: dateError,
              onChanged: (d) => setState(() {
                incubationDate = d;
                hatchDate = d.add(ChickenBatch.incubationDuration);
                hatchDateIsActual = false;
                dateError = null;
              }),
            ),
            LunarDateField(
              // Plain "hatch date" until one of the two is filled in — only
              // then is it known to be an expectation or the real thing.
              label: hatchDate == null
                  ? l10n.hatchDate
                  : hatchDateIsActual
                  ? l10n.actualHatchDateLabel
                  : l10n.expectedHatchDateLabel,
              value: hatchDate,
              useLunar: vm.useLunarCalendar,
              onChanged: (d) => setState(() {
                hatchDate = d;
                incubationDate = d.subtract(ChickenBatch.incubationDuration);
                hatchDateIsActual = true;
                dateError = null;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
