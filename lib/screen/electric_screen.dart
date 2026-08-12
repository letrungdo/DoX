import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/num_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/electric/electric_account.dart';
import 'package:do_x/model/electric/electric_merged.dart';
import 'package:do_x/model/electric/electric_models.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/core/tab_reselect.mixin.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/electric_view_model.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/chart/cute_bar_chart.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:do_x/widgets/input/cute_input_decoration.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:do_x/widgets/neu/neu_surface.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Series colors validated for CVD + contrast on both surfaces
/// (current vs same-period-last-year).
class _ChartColors {
  static const currentLight = Color(0xFF00897B);
  static const compareLight = Color(0xFFC77800);
  static const currentDark = Color(0xFF1FA695);
  static const compareDark = Color(0xFFC07B28);

  static Color current(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? currentDark
      : currentLight;

  static Color compare(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? compareDark
      : compareLight;
}

/// Asks before dropping stored credentials; true when they were removed.
///
/// Top level rather than a method on the screen: the settings page runs the
/// same flow, and both reach the view model through the provider.
Future<bool> confirmForgetElectricAccount(
  BuildContext context,
  ElectricAccount account,
) async {
  final l10n = AppLocalizations.of(context);
  final vm = context.read<ElectricViewModel>();
  final confirmed = await showAppConfirmDialog(
    context,
    title: l10n.logout,
    message: l10n.forgetAccountConfirm(account.displayName),
    confirmText: l10n.delete,
    isDestructive: true,
  );
  if (!confirmed) return false;
  await vm.forgetSavedAccount(account);
  return true;
}

/// Signs a second meter's account in alongside the ones already added.
Future<void> showElectricAddAccountDialog(BuildContext context) async {
  final vm = context.read<ElectricViewModel>();
  final credentials = await showAppModal<({String username, String password})>(
    context,
    // The dialog sits above the screen's provider, so the saved accounts are
    // passed in instead of read from the view model.
    builder: (dialogContext) => _AddAccountDialog(
      savedAccounts: vm.availableSavedAccounts,
      onForgetSavedAccount: (account) =>
          confirmForgetElectricAccount(context, account),
    ),
  );
  if (credentials == null) return;
  vm.addAccount(username: credentials.username, password: credentials.password);
}

@RoutePage()
class ElectricScreen extends StatefulScreen implements AutoRouteWrapper {
  const ElectricScreen({super.key});

  @override
  State<ElectricScreen> createState() => _ElectricScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ElectricViewModel(), //
      child: this,
    );
  }
}

class _ElectricScreenState
    extends ScreenState<ElectricScreen, ElectricViewModel>
    with TabReselect {
  final _scrollController = ScrollController();
  final _monthlySectionKey = GlobalKey();
  final _highlightedMonthlyItemKey = GlobalKey();
  DateTime? _lastFocusedMonth;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  String get tabRouteName => ElectricRoute.name;

  @override
  ScrollController get tabScrollController => _scrollController;

  @override
  Future<void> onTabRefresh() async {
    if (vm.status == ElectricStatus.loggedIn) await vm.onRefresh();
  }

  @override
  void onResume() {
    super.onResume();
    if (vm.status == ElectricStatus.loggedIn) vm.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsButton = NeuIconButton(
      size: Dimens.appBarActionSize,
      iconSize: 18,
      depth: Dimens.appBarActionDepth,
      tooltip: l10n.settings,
      icon: Icons.settings_outlined,
      onPressed: () =>
          context.router.push(ElectricSettingsRoute(electricVm: vm)),
    );
    return AppScaffold(
      appBar: DoAppBar(
        title: l10n.electricityTitle,
        titleSuffix: AppBarSyncIcon<ElectricViewModel>(
          selector: (vm) => vm.isFetching,
        ),
        actions: [settingsButton],
      ),
      body: Selector<ElectricViewModel, ElectricStatus>(
        selector: (_, vm) => vm.status,
        builder: (context, status, _) {
          return switch (status) {
            ElectricStatus.loading => const Center(child: Loading()),
            ElectricStatus.loggedOut => _LoginForm(
              onSubmit: _login,
              onForgetSavedAccount: (account) =>
                  confirmForgetElectricAccount(context, account),
            ),
            ElectricStatus.loggedIn => RefreshIndicator.adaptive(
              onRefresh: () => vm.onRefresh(showLoading: true), //
              child: _buildContent(l10n),
            ),
          };
        },
      ),
    );
  }

  void _login(String username, String password) {
    vm.addAccount(username: username, password: password);
  }

  Widget _buildContent(AppLocalizations l10n) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            // The page padding sits inside the shared content cap, exactly as
            // `contentConstrainedBox()` puts it on the other pages — so a card
            // here is the same width as a card anywhere else.
            final overflow =
                constraints.crossAxisExtent - Dimens.contentMaxWidth;
            final horizontalPadding =
                Dimens.pagePadding + (overflow > 0 ? overflow / 2 : 0);
            return SliverPadding(
              // 16, not 15: a card's shadow reaches ~17px, so a tighter page padding
              // lets the scroll viewport clip the rim of the first and last card.
              padding: EdgeInsets.symmetric(
                vertical: 16,
                horizontal: horizontalPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildAccountTabs(l10n),
                  const SizedBox(height: 14),
                  Selector<ElectricViewModel, bool>(
                    selector: (_, vm) => vm.isMergedView,
                    builder: (context, mergedView, _) {
                      if (mergedView) return _buildMergedContent(l10n);
                      return _buildAccountContent(l10n);
                    },
                  ),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAccountContent(AppLocalizations l10n) {
    return Selector<ElectricViewModel, bool>(
      // Skeleton while the account is loading for the first time.
      selector: (_, vm) => vm.customer == null && vm.isFetching,
      builder: (context, showSkeleton, _) {
        if (showSkeleton) return _buildSkeleton();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCustomerCard(l10n),
            const SizedBox(height: 20),
            _buildUsageSection(l10n),
            const SizedBox(height: 24),
            _buildDailyChart(l10n),
            const SizedBox(height: 24),
            _buildMonthlySection(l10n),
            const SizedBox(height: 24),
            _buildSpiderSection(l10n),
          ],
        );
      },
    );
  }

  /// Gray placeholders mirroring the real sections while the first fetch of
  /// an account is running (the progress bar on top provides the motion).
  Widget _buildSkeleton() {
    // Flat sunken fill, so the placeholders read as holes rather than as the
    // raised panels they are standing in for.
    final color = context.neu.sunken;

    Widget box({required double height, double? width}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
        ),
      );
    }

    Widget tileRow() {
      return Row(
        spacing: 14,
        children: [
          Expanded(child: box(height: 56)),
          Expanded(child: box(height: 56)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        box(height: 72),
        box(height: 18, width: 160),
        tileRow(),
        tileRow(),
        const SizedBox(height: 8),
        box(height: 18, width: 190),
        box(height: 150),
      ],
    );
  }

  Widget _buildAccountTabs(AppLocalizations l10n) {
    // Consumer, not Selector: the account list keeps its identity while
    // display names and contract types stream in after login.
    return Consumer<ElectricViewModel>(
      builder: (context, vm, _) {
        final accounts = vm.accounts;
        final activeIndex = vm.activeIndex;
        final scheme = context.theme.colorScheme;
        return Wrap(
          // 10, not 5: these are raised chips, and their shadows need room
          // between them or each chip's lit rim lands on its neighbour's shade.
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < accounts.length; i++)
              _accountChip(
                scheme,
                label: accounts[i].shortDisplayName,
                subtitle: accounts[i].contractTypeDisplay,
                selected: !vm.isMergedView && i == activeIndex,
                onTap: () => vm.switchAccount(i),
              ),
            if (vm.canMerge)
              _accountChip(
                scheme,
                label: l10n.mergedTab,
                subtitle: l10n.mergedTabSubtitle,
                selected: vm.isMergedView,
                onTap: vm.switchToMergedView,
              ),
          ],
        );
      },
    );
  }

  Widget _accountChip(
    ColorScheme scheme, {
    required String label,
    String? subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final foreground = selected ? scheme.onTertiary : scheme.onSurface;
    // Selection is carried by the fill, the way it is on the neumorphic cards:
    // an outline next to the shadow pair reads as a competing border.
    return NeuCard(
      radius: 14,
      depth: 0.5,
      color: selected ? scheme.tertiary : null,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(
              subtitle,
              style: TextStyle(
                color: foreground.withValues(alpha: 0.75),
                fontSize: 10.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(AppLocalizations l10n) {
    return Selector<ElectricViewModel, ElectricCustomer?>(
      selector: (_, vm) => vm.customer,
      builder: (context, customer, _) {
        return NeuCard(
          radius: 14,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _ChartColors.current(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(
                    Dimens.radiusControlSmall,
                  ),
                ),
                child: Icon(
                  Icons.electric_meter_rounded,
                  color: _ChartColors.current(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer?.customerName.toDashIfNull ?? "",
                      style: context.textTheme.primary.bold,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${customer?.customerCode.toDashIfNull} · ${l10n.meterId} ${customer?.meterId.toDashIfNull}",
                      style: context.textTheme.secondary.size13,
                    ),
                    Text(
                      customer?.address.toDashIfNull ?? "",
                      style: context.textTheme.secondary.size13,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsageSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.electricUsage, style: context.textTheme.primary.size16.bold),
        const SizedBox(height: 8),
        Selector<ElectricViewModel, (num?, num?, num?, num?)>(
          selector: (_, vm) => (
            vm.usageToday,
            vm.usageYesterday,
            vm.usageThisMonth,
            vm.usageLastMonth,
          ),
          builder: (context, usage, _) {
            final (today, yesterday, thisMonth, lastMonth) = usage;
            return Column(
              spacing: 8,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    _buildUsageTile(l10n.today, today),
                    _buildUsageTile(l10n.yesterday, yesterday),
                  ],
                ),
                Row(
                  spacing: 8,
                  children: [
                    _buildUsageTile(l10n.thisMonth, thisMonth),
                    _buildUsageTile(l10n.lastMonth, lastMonth),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Selector<ElectricViewModel, ElectricMeterReading?>(
          selector: (_, vm) => vm.latestReading,
          builder: (context, reading, _) {
            if (reading == null) return const SizedBox.shrink();
            final readAt = reading.readAt;
            final time = readAt == null
                ? ""
                : DateFormat("HH:mm dd/MM/yyyy").format(readAt);
            return Text(
              "${l10n.latestMeterReading}: ${reading.meterIndex.formatUnit()} kWh ($time)",
              style: context.textTheme.secondary.size13,
            );
          },
        ),
      ],
    );
  }

  Widget _buildUsageTile(String label, num? kwh) {
    final accent = _ChartColors.current(context);
    return Expanded(
      // Opaque blend rather than a translucent tint: a raised panel's shadows
      // would otherwise show through its own fill.
      child: NeuCard(
        radius: 12,
        depth: 0.6,
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.08),
          context.neu.base,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: [
            Text(
              label,
              style: context.textTheme.secondary.size13,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                text: kwh.formatUnit(digit: 1),
                style: context.textTheme.primary.bold,
                children: [
                  TextSpan(
                    text: " kWh",
                    style: context.textTheme.secondary.size13,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChart(AppLocalizations l10n) {
    return Selector<ElectricViewModel, List<({DateTime day, double kwh})>>(
      selector: (_, vm) => vm.dailyUsages,
      builder: (context, usages, _) {
        if (usages.isEmpty) return const SizedBox.shrink();
        final items = usages
            .skip(usages.length <= 14 ? 0 : usages.length - 14)
            .map(
              (e) => CuteBarChartItem(
                label: DateFormat("d/M").format(e.day),
                value: e.kwh,
              ),
            )
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.dailyUsage, style: context.textTheme.primary.size16.bold),
            const SizedBox(height: 8),
            CuteBarChart(
              items: items,
              primaryColor: _ChartColors.current(context),
              formatValue: (v) => "${v.formatUnit(digit: 2)} kWh",
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthlySection(AppLocalizations l10n) {
    return Selector<ElectricViewModel, List<ElectricMonthlyUsage>>(
      selector: (_, vm) => vm.monthlyUsages,
      builder: (context, items, _) {
        if (items.isEmpty) return const SizedBox.shrink();
        final highlightedMonth = context
            .watch<AppViewModel>()
            .electricMonthToHighlight;
        _focusMonthlySectionWhenReady(items, highlightedMonth);
        // Chart reads left→right in time; the list keeps newest first.
        final chartItems = items.reversed
            .map(
              (e) => CuteBarChartItem(
                label: "${e.month}/${(e.year ?? 0) % 100}",
                value: e.usageKwh?.toDouble(),
                compareValue: e.lastYearUsageKwh?.toDouble(),
              ),
            )
            .toList();
        return Column(
          key: _monthlySectionKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.billingHistory,
              style: context.textTheme.primary.size16.bold,
            ),
            const SizedBox(height: 8),
            _buildChartLegend(l10n),
            const SizedBox(height: 6),
            CuteBarChart(
              items: chartItems,
              primaryColor: _ChartColors.current(context),
              compareColor: _ChartColors.compare(context),
              formatValue: (v) => "${v.formatUnit()} kWh",
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => _buildMonthlyItem(
                l10n,
                item,
                highlighted: _isSameMonth(item, highlightedMonth),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isSameMonth(ElectricMonthlyUsage item, DateTime? month) {
    return month != null &&
        item.year == month.year &&
        item.month == month.month;
  }

  void _focusMonthlySectionWhenReady(
    List<ElectricMonthlyUsage> items,
    DateTime? month,
  ) {
    if (month == null || identical(_lastFocusedMonth, month)) return;
    if (!items.any((item) => _isSameMonth(item, month))) return;
    _lastFocusedMonth = month;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext =
          _highlightedMonthlyItemKey.currentContext ??
          _monthlySectionKey.currentContext;
      if (!mounted || targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  Widget _buildChartLegend(AppLocalizations l10n) {
    Widget entry(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: context.textTheme.secondary.size13),
        ],
      );
    }

    // Same order as the bars: last year on the left, this year on the right.
    return Wrap(
      spacing: 14,
      children: [
        entry(_ChartColors.compare(context), l10n.seriesLastYear),
        entry(_ChartColors.current(context), l10n.seriesThisYear),
      ],
    );
  }

  Widget _buildMonthlyItem(
    AppLocalizations l10n,
    ElectricMonthlyUsage item, {
    required bool highlighted,
  }) {
    final highlightColor = _ChartColors.current(context);
    return AnimatedContainer(
      key: highlighted ? _highlightedMonthlyItemKey : null,
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      // The focused month lifts off the list as a tinted raised panel; the old
      // outline competed with the shadow pair around it.
      decoration: highlighted
          ? context.neuRaised(
              radius: 12,
              depth: 0.6,
              color: Color.alphaBlend(
                highlightColor.withValues(alpha: 0.16),
                context.neu.base,
              ),
            )
          : const BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.circular(Dimens.radiusControlSmall),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.monthLabel("${item.month}", "${item.year}"),
                  style: context.textTheme.primary.bold.copyWith(
                    color: highlighted ? highlightColor : null,
                  ),
                ),
                Text(
                  l10n.sameMonthLastYear(
                    "${item.lastYearUsageKwh.formatUnit()} kWh · ${item.lastYearTotalAmount.formatUnit()} đ",
                  ),
                  style: context.textTheme.secondary.size13,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${item.totalAmount.formatUnit()} đ",
                style: context.textTheme.primary.bold.copyWith(
                  color: context.colors.money,
                ),
              ),
              Text(
                "${item.usageKwh.formatUnit()} kWh",
                style: context.textTheme.secondary.size13,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Merged tab: the meters of one customer added together, plus what the same
  // consumption would have cost on a single household meter. Meters are grouped
  // by customer name, so a relative's account signed in here stays out of the
  // household's own total.
  // ---------------------------------------------------------------------------

  Widget _buildMergedContent(AppLocalizations l10n) {
    // Consumer, not Selector: the groups are rebuilt on every read, so there is
    // nothing stable to compare against.
    return Consumer<ElectricViewModel>(
      builder: (context, vm, _) {
        final groups = vm.mergedGroups;
        if (groups.isEmpty) {
          if (vm.isFetching) return _buildSkeleton();
          return _buildMergedNotice(l10n.mergedNoGroups);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in groups) ...[
              _buildMergedGroup(l10n, vm, group),
              if (group != groups.last) const SizedBox(height: 32),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMergedGroup(
    AppLocalizations l10n,
    ElectricViewModel vm,
    ElectricMergedGroup group,
  ) {
    final merged = group.usage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Named first: the totals below are meaningless until it is clear whose
        // meters, and which of them, went into the sum.
        _buildMergedMetersCard(l10n, group),
        const SizedBox(height: 20),
        if (!merged.isComparable)
          _buildMergedNotice(l10n.mergedNeedsBothMeters)
        else if (merged.isEmpty)
          _buildMergedNotice(l10n.mergedNoOverlap)
        else
          _buildSavingsCard(l10n, merged),
        const SizedBox(height: 20),
        _buildMergedUsageSection(l10n, vm, group.accounts),
        const SizedBox(height: 24),
        _buildMergedDailyChart(l10n, vm.mergedDailyUsages(group.accounts)),
        if (merged.months.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildMergedMonthlySection(l10n, merged),
        ],
      ],
    );
  }

  /// Who the total belongs to and exactly which meters were added into it.
  Widget _buildMergedMetersCard(
    AppLocalizations l10n,
    ElectricMergedGroup group,
  ) {
    final accent = _ChartColors.current(context);
    return NeuCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.merge_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.ownerName,
                  style: context.textTheme.primary.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.mergedMeters("${group.accounts.length}"),
            style: context.textTheme.secondary.size13,
          ),
          const SizedBox(height: 10),
          ...group.accounts.map(
            (account) => _buildMergedMeterRow(l10n, account),
          ),
        ],
      ),
    );
  }

  Widget _buildMergedMeterRow(AppLocalizations l10n, ElectricAccount account) {
    final customer = account.customer;
    // Contract type is what tells the two meters apart; the customer code and
    // meter id are there for the times both are "Sinh hoạt".
    final title = account.contractTypeDisplay?.isNotEmpty == true
        ? account.contractTypeDisplay!
        : account.username;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            Icons.electric_meter_rounded,
            size: 16,
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textTheme.primary.size13),
                Text(
                  "${customer?.customerCode.toDashIfNull} · ${l10n.meterId} ${customer?.meterId.toDashIfNull}",
                  style: context.textTheme.secondary.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMergedNotice(String message) {
    // Sunken fill: a notice is a hole in the page, not another raised panel
    // competing with the cards below it.
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.neu.sunken,
        borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
      ),
      child: Text(message, style: context.textTheme.secondary.size13),
    );
  }

  Widget _buildSavingsCard(AppLocalizations l10n, ElectricMergedUsage merged) {
    final saved = merged.totalSavings;
    // Splitting the load is the whole point of the second meter, so savings are
    // the expected sign; a negative total is worth flagging in red.
    final accent = saved >= 0 ? context.colors.success : context.colors.danger;
    final months = merged.months.length;
    return NeuCard(
      radius: 14,
      padding: const EdgeInsets.all(16),
      color: Color.alphaBlend(accent.withValues(alpha: 0.10), context.neu.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_rounded, color: accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.mergedSavingsTitle,
                  style: context.textTheme.primary.size16.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.mergedSavingsTotal,
            style: context.textTheme.secondary.size13,
          ),
          Text.rich(
            TextSpan(
              text: saved.formatUnit(digit: 0, hasPlus: true),
              style: context.textTheme.primary.bold.copyWith(
                color: accent,
                fontSize: 26,
              ),
              children: [
                TextSpan(text: " đ", style: context.textTheme.secondary.size13),
              ],
            ),
          ),
          Text(
            l10n.mergedMonthsCounted("$months"),
            style: context.textTheme.secondary.size13,
          ),
          const SizedBox(height: 12),
          _savingsRow(
            l10n.mergedSingleMeterCost,
            merged.totalSingleMeterAmount,
            emphasized: false,
          ),
          const SizedBox(height: 4),
          _savingsRow(l10n.mergedActualCost, merged.totalActualAmount),
          const SizedBox(height: 4),
          _savingsRow(
            l10n.mergedAveragePerMonth,
            months == 0 ? 0 : saved / months,
            color: accent,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.mergedEstimateNote,
            style: context.textTheme.secondary.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _savingsRow(
    String label,
    num amount, {
    bool emphasized = true,
    Color? color,
  }) {
    return Row(
      children: [
        Expanded(child: Text(label, style: context.textTheme.secondary.size13)),
        Text(
          "${amount.formatUnit(digit: 0)} đ",
          style: emphasized
              ? context.textTheme.primary.bold.copyWith(
                  color: color ?? context.colors.money,
                )
              : context.textTheme.secondary.size13,
        ),
      ],
    );
  }

  Widget _buildMergedUsageSection(
    AppLocalizations l10n,
    ElectricViewModel vm,
    List<ElectricAccount> accounts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.electricUsage, style: context.textTheme.primary.size16.bold),
        const SizedBox(height: 8),
        Column(
          spacing: 8,
          children: [
            Row(
              spacing: 8,
              children: [
                _buildUsageTile(l10n.today, vm.mergedUsageToday(accounts)),
                _buildUsageTile(
                  l10n.yesterday,
                  vm.mergedUsageYesterday(accounts),
                ),
              ],
            ),
            Row(
              spacing: 8,
              children: [
                _buildUsageTile(
                  l10n.thisMonth,
                  vm.mergedUsageThisMonth(accounts),
                ),
                _buildUsageTile(
                  l10n.lastMonth,
                  vm.mergedUsageLastMonth(accounts),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMergedDailyChart(
    AppLocalizations l10n,
    List<({DateTime day, double kwh})> usages,
  ) {
    if (usages.isEmpty) return const SizedBox.shrink();
    final items = usages
        .skip(usages.length <= 14 ? 0 : usages.length - 14)
        .map(
          (e) => CuteBarChartItem(
            label: DateFormat("d/M").format(e.day),
            value: e.kwh,
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.dailyUsage, style: context.textTheme.primary.size16.bold),
        const SizedBox(height: 8),
        CuteBarChart(
          items: items,
          primaryColor: _ChartColors.current(context),
          formatValue: (v) => "${v.formatUnit(digit: 2)} kWh",
        ),
      ],
    );
  }

  Widget _buildMergedMonthlySection(
    AppLocalizations l10n,
    ElectricMergedUsage merged,
  ) {
    // Chart reads left→right in time; the list keeps newest first. The pair of
    // bars is the same comparison as the card above: one meter vs. what was
    // really paid.
    final chartItems = merged.months.reversed
        .map(
          (m) => CuteBarChartItem(
            label: "${m.month}/${m.year % 100}",
            value: m.actualAmount.toDouble(),
            compareValue: m.singleMeterAmount.toDouble(),
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.mergedMonthlyTitle,
          style: context.textTheme.primary.size16.bold,
        ),
        const SizedBox(height: 8),
        _buildMergedLegend(l10n),
        const SizedBox(height: 6),
        CuteBarChart(
          items: chartItems,
          primaryColor: _ChartColors.current(context),
          compareColor: _ChartColors.compare(context),
          formatValue: (v) => "${v.formatUnit(digit: 0)} đ",
        ),
        const SizedBox(height: 10),
        ...merged.months.map((m) => _buildMergedMonthlyItem(l10n, m)),
      ],
    );
  }

  Widget _buildMergedLegend(AppLocalizations l10n) {
    Widget entry(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: context.textTheme.secondary.size13),
        ],
      );
    }

    // Same order as the bars: the estimate on the left, reality on the right.
    return Wrap(
      spacing: 14,
      children: [
        entry(_ChartColors.compare(context), l10n.mergedSingleMeterCost),
        entry(_ChartColors.current(context), l10n.mergedActualCost),
      ],
    );
  }

  Widget _buildMergedMonthlyItem(
    AppLocalizations l10n,
    ElectricMergedMonth item,
  ) {
    final accent = item.savings >= 0
        ? context.colors.success
        : context.colors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.monthLabel("${item.month}", "${item.year}"),
                  style: context.textTheme.primary.bold,
                ),
                Text(
                  l10n.mergedSplitLabel(
                    "${item.residentialKwh.formatUnit()} kWh",
                    "${item.otherKwh.formatUnit()} kWh",
                  ),
                  style: context.textTheme.secondary.size13,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${item.actualAmount.formatUnit(digit: 0)} đ",
                style: context.textTheme.primary.bold.copyWith(
                  color: context.colors.money,
                ),
              ),
              Text(
                "${l10n.mergedSavingsLabel} ${item.savings.formatUnit(digit: 0, hasPlus: true)} đ",
                style: context.textTheme.secondary.size13.copyWith(
                  color: accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static const _spiderReadingsLimit = 8;

  Widget _buildSpiderSection(AppLocalizations l10n) {
    return Selector<ElectricViewModel, List<ElectricMeterReading>>(
      selector: (_, vm) => vm.spiderReadings,
      builder: (context, readings, _) {
        if (readings.isEmpty) return const SizedBox.shrink();
        final items = readings.take(_spiderReadingsLimit).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.spiderReadings,
              style: context.textTheme.primary.size16.bold,
            ),
            const SizedBox(height: 8),
            ...List.generate(items.length, (index) {
              final reading = items[index];
              // The list is newest first, so the next item is the previous reading.
              final previous = index + 1 < readings.length
                  ? readings[index + 1]
                  : null;
              return _buildSpiderItem(reading, previous);
            }),
          ],
        );
      },
    );
  }

  Widget _buildSpiderItem(
    ElectricMeterReading reading,
    ElectricMeterReading? previous,
  ) {
    final readAt = reading.readAt;
    final time = readAt == null
        ? ""
        : DateFormat("HH:mm dd/MM/yyyy").format(readAt);
    final current = reading.meterIndex;
    final prior = previous?.meterIndex;
    final delta = (current != null && prior != null) ? current - prior : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(time, style: context.textTheme.secondary.size13),
          ),
          Expanded(
            flex: 3,
            child: Text(
              delta == null ? "" : "+${delta.formatUnit(digit: 2)} kWh",
              textAlign: TextAlign.right,
              style: context.textTheme.secondary.size13,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "${current.formatUnit(digit: 2)} kWh",
              textAlign: TextAlign.right,
              style: context.textTheme.primary.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen form shown when no account is logged in yet.
class _LoginForm extends StatefulWidget {
  const _LoginForm({
    required this.onSubmit,
    required this.onForgetSavedAccount,
  });

  final void Function(String username, String password) onSubmit;
  final Future<bool> Function(ElectricAccount account) onForgetSavedAccount;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;
    widget.onSubmit(username, password);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.electric_bolt_rounded,
                size: 56,
                color: _ChartColors.compare(context),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.electricLoginTitle,
                style: context.textTheme.primary.size16.bold,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Consumer, not Selector: the getter builds a fresh list every
              // call, so there is nothing stable to compare against.
              Consumer<ElectricViewModel>(
                builder: (context, vm, _) {
                  final savedAccounts = vm.availableSavedAccounts;
                  if (savedAccounts.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _SavedAccountPicker(
                      accounts: savedAccounts,
                      onSelect: (account) =>
                          widget.onSubmit(account.username, account.password),
                      onForget: widget.onForgetSavedAccount,
                    ),
                  );
                },
              ),
              TextField(
                controller: _usernameController,
                autocorrect: false,
                decoration: cuteInputDecoration(context, l10n.username),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autocorrect: false,
                onSubmitted: (_) => _submit(),
                decoration: cuteInputDecoration(context, l10n.password)
                    .copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                      ),
                    ),
              ),
              const SizedBox(height: 24),
              NeuButton(
                onPressed: _submit, //
                accent: context.theme.colorScheme.primary,
                expand: true,
                radius: 14,
                child: Center(child: Text(l10n.login)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small username/password dialog used to add another account tab.
class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog({
    required this.savedAccounts,
    required this.onForgetSavedAccount,
  });

  final List<ElectricAccount> savedAccounts;
  final Future<bool> Function(ElectricAccount account) onForgetSavedAccount;

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// Local copy so forgetting an account updates the dialog right away.
  late List<ElectricAccount> _savedAccounts = widget.savedAccounts;

  Future<void> _forget(ElectricAccount account) async {
    final removed = await widget.onForgetSavedAccount(account);
    if (!removed || !mounted) return;
    setState(
      () => _savedAccounts = _savedAccounts
          .where((a) => a.username != account.username)
          .toList(),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) return;
    Navigator.pop(context, (username: username, password: password));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      title: l10n.addAccount,
      scrollable: true,
      // AlertDialog sizes itself to the content's intrinsic width, so without a
      // width here the dialog stays narrow and the inset padding has no visible
      // effect. Narrow screens clamp this down to the available width.
      content: SizedBox(
        width: Dimens.dialogMaxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_savedAccounts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _SavedAccountPicker(
                  accounts: _savedAccounts,
                  onSelect: (account) => Navigator.pop(context, (
                    username: account.username,
                    password: account.password,
                  )),
                  onForget: _forget,
                ),
              ),
            TextField(
              controller: _usernameController,
              autocorrect: false,
              decoration: cuteInputDecoration(context, l10n.username),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autocorrect: false,
              onSubmitted: (_) => _submit(),
              decoration: cuteInputDecoration(context, l10n.password).copyWith(
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        DialogActions(
          children: [
            DialogActionButton(
              text: l10n.cancel,
              kind: DialogActionKind.cancel,
              onPressed: () => Navigator.pop(context),
            ),
            DialogActionButton(text: l10n.login, onPressed: _submit),
          ],
        ),
      ],
    );
  }
}

/// Chips for accounts logged in before, so signing back in is one tap instead
/// of retyping the credentials. The trailing ✕ forgets the stored password.
class _SavedAccountPicker extends StatelessWidget {
  const _SavedAccountPicker({
    required this.accounts,
    required this.onSelect,
    required this.onForget,
  });

  final List<ElectricAccount> accounts;
  final void Function(ElectricAccount account) onSelect;
  final Future<void> Function(ElectricAccount account) onForget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.savedAccounts, style: context.textTheme.secondary.size13),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: accounts
              .map((account) => _chip(context, scheme, account))
              .toList(),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    ColorScheme scheme,
    ElectricAccount account,
  ) {
    return NeuCard(
      radius: 14,
      depth: 0.5,
      onTap: () => onSelect(account),
      padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_circle_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.displayName,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                account.username,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => onForget(account),
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            color: scheme.onSurfaceVariant,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
