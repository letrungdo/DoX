import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/num_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/electric/electric_models.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/electric_view_model.dart';
import 'package:do_x/view_model/main_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/chart/cute_bar_chart.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:do_x/widgets/input/cute_input_decoration.dart';
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
      Theme.of(context).brightness == Brightness.dark ? currentDark : currentLight;

  static Color compare(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? compareDark : compareLight;
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

class _ElectricScreenState extends ScreenState<ElectricScreen, ElectricViewModel> {
  final _scrollController = ScrollController();
  final _monthlySectionKey = GlobalKey();
  final _highlightedMonthlyItemKey = GlobalKey();
  DateTime? _lastFocusedMonth;

  MainViewModel? _mainViewModel;
  late final Future<void> Function() _tabReselectHandler;

  @override
  void initState() {
    _tabReselectHandler = _handleTabReselect;
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mainViewModel = context.read<MainViewModel>();
    if (identical(_mainViewModel, mainViewModel)) return;
    _mainViewModel?.unregisterTabReselectHandler(ElectricRoute.name, _tabReselectHandler);
    _mainViewModel = mainViewModel;
    mainViewModel.registerTabReselectHandler(ElectricRoute.name, _tabReselectHandler);
  }

  @override
  void dispose() {
    _mainViewModel?.unregisterTabReselectHandler(ElectricRoute.name, _tabReselectHandler);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleTabReselect() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    if (mounted && vm.status == ElectricStatus.loggedIn) await vm.onRefresh();
  }

  @override
  void onResume() {
    super.onResume();
    if (vm.status == ElectricStatus.loggedIn) vm.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.electricityTitle,
        actions: [
          Selector<ElectricViewModel, ElectricStatus>(
            selector: (_, vm) => vm.status,
            builder: (context, status, _) {
              if (status != ElectricStatus.loggedIn) return const SizedBox.shrink();
              return Row(
                children: [
                  IconButton(
                    onPressed: vm.onRefresh, //
                    icon: const Icon(Icons.refresh_rounded, size: 27),
                  ),
                  IconButton(
                    tooltip: l10n.logout,
                    onPressed: () => _confirmRemoveAccount(l10n),
                    icon: const Icon(Icons.logout_rounded, size: 24),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Selector<ElectricViewModel, ElectricStatus>(
        selector: (_, vm) => vm.status,
        builder: (context, status, _) {
          return switch (status) {
            ElectricStatus.loading => const Center(child: CircularProgressIndicator.adaptive()),
            ElectricStatus.loggedOut => _LoginForm(onSubmit: _login),
            ElectricStatus.loggedIn => Column(
              children: [
                Selector<ElectricViewModel, bool>(
                  selector: (_, vm) => vm.isFetching,
                  builder: (context, isFetching, _) {
                    return isFetching
                        ? const LinearProgressIndicator(minHeight: 2)
                        : const SizedBox(height: 2);
                  },
                ),
                Expanded(
                  child: RefreshIndicator.adaptive(
                    onRefresh: () => vm.onRefresh(), //
                    child: _buildContent(l10n),
                  ),
                ),
              ],
            ),
          };
        },
      ),
    );
  }

  void _login(String username, String password) {
    vm.addAccount(username: username, password: password);
  }

  Future<void> _confirmRemoveAccount(AppLocalizations l10n) async {
    final name = vm.activeAccount?.displayName ?? "";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logout),
        content: Text(l10n.removeAccountConfirm(name)),
        actions: [
          DialogActionButton(
            text: l10n.cancel,
            kind: DialogActionKind.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          DialogActionButton(
            text: l10n.logout,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed == true) await vm.removeActiveAccount();
  }

  Future<void> _showAddAccountDialog(AppLocalizations l10n) async {
    final credentials = await showDialog<({String username, String password})>(
      context: context,
      builder: (context) => const _AddAccountDialog(),
    );
    if (credentials == null) return;
    _login(credentials.username, credentials.password);
  }

  Widget _buildContent(AppLocalizations l10n) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverLayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.crossAxisExtent;
            const maxContentWidth = Dimens.webMaxWidth;
            double horizontalPadding = 15;
            if (screenWidth > maxContentWidth) {
              horizontalPadding = (screenWidth - maxContentWidth) / 2;
            }
            return SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 15, horizontal: horizontalPadding),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildAccountTabs(l10n),
                  const SizedBox(height: 14),
                  Selector<ElectricViewModel, bool>(
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
                  ),
                ]),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Gray placeholders mirroring the real sections while the first fetch of
  /// an account is running (the progress bar on top provides the motion).
  Widget _buildSkeleton() {
    final color = context.theme.colorScheme.surfaceContainerHigh;

    Widget box({required double height, double? width}) {
      return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      );
    }

    Widget tileRow() {
      return Row(
        spacing: 8,
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
          spacing: 5,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < accounts.length; i++)
              _accountChip(
                scheme,
                label: accounts[i].shortDisplayName,
                subtitle: accounts[i].contractTypeDisplay,
                selected: i == activeIndex,
                onTap: () => vm.switchAccount(i),
              ),
            Material(
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _showAddAccountDialog(l10n),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Icon(Icons.person_add_alt_1_rounded, size: 18, color: scheme.onSurface),
                ),
              ),
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
    return Material(
      color: selected ? scheme.tertiary : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: selected ? BorderSide.none : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
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
                  style: TextStyle(color: foreground.withValues(alpha: 0.75), fontSize: 10.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerCard(AppLocalizations l10n) {
    return Selector<ElectricViewModel, ElectricCustomer?>(
      selector: (_, vm) => vm.customer,
      builder: (context, customer, _) {
        final scheme = context.theme.colorScheme;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _ChartColors.current(context).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.electric_meter_rounded, color: _ChartColors.current(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer?.customerName.toDashIfNull ?? "", style: context.textTheme.primary.bold),
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
          selector: (_, vm) => (vm.usageToday, vm.usageYesterday, vm.usageThisMonth, vm.usageLastMonth),
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
            final time = readAt == null ? "" : DateFormat("HH:mm dd/MM/yyyy").format(readAt);
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: context.textTheme.secondary.size13, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                text: kwh.formatUnit(digit: 1),
                style: context.textTheme.primary.bold,
                children: [
                  TextSpan(text: " kWh", style: context.textTheme.secondary.size13),
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
            .map((e) => CuteBarChartItem(label: DateFormat("d/M").format(e.day), value: e.kwh))
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
        final highlightedMonth = context.watch<AppViewModel>().electricMonthToHighlight;
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
            Text(l10n.billingHistory, style: context.textTheme.primary.size16.bold),
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
    return month != null && item.year == month.year && item.month == month.month;
  }

  void _focusMonthlySectionWhenReady(List<ElectricMonthlyUsage> items, DateTime? month) {
    if (month == null || identical(_lastFocusedMonth, month)) return;
    if (!items.any((item) => _isSameMonth(item, month))) return;
    _lastFocusedMonth = month;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _highlightedMonthlyItemKey.currentContext ?? _monthlySectionKey.currentContext;
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
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
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
      decoration: BoxDecoration(
        color: highlighted ? highlightColor.withValues(alpha: 0.14) : Colors.transparent,
        border: highlighted ? Border.all(color: highlightColor, width: 1.5) : null,
        borderRadius: BorderRadius.circular(12),
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
                  style: context.textTheme.primary.bold.copyWith(color: highlighted ? highlightColor : null),
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
                style: context.textTheme.primary.bold.copyWith(color: context.colors.money),
              ),
              Text("${item.usageKwh.formatUnit()} kWh", style: context.textTheme.secondary.size13),
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
            Text(l10n.spiderReadings, style: context.textTheme.primary.size16.bold),
            const SizedBox(height: 8),
            ...List.generate(items.length, (index) {
              final reading = items[index];
              // The list is newest first, so the next item is the previous reading.
              final previous = index + 1 < readings.length ? readings[index + 1] : null;
              return _buildSpiderItem(reading, previous);
            }),
          ],
        );
      },
    );
  }

  Widget _buildSpiderItem(ElectricMeterReading reading, ElectricMeterReading? previous) {
    final readAt = reading.readAt;
    final time = readAt == null ? "" : DateFormat("HH:mm dd/MM/yyyy").format(readAt);
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
  const _LoginForm({required this.onSubmit});

  final void Function(String username, String password) onSubmit;

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
              Icon(Icons.electric_bolt_rounded, size: 56, color: _ChartColors.compare(context)),
              const SizedBox(height: 12),
              Text(
                l10n.electricLoginTitle,
                style: context.textTheme.primary.size16.bold,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
                decoration: cuteInputDecoration(context, l10n.password).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit, //
                child: Text(l10n.login),
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
  const _AddAccountDialog();

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
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
    Navigator.pop(context, (username: username, password: password));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addAccount),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              ),
            ),
          ),
        ],
      ),
      actions: [
        DialogActionButton(
          text: l10n.cancel,
          kind: DialogActionKind.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        DialogActionButton(
          text: l10n.login,
          onPressed: _submit,
        ),
      ],
    );
  }
}
