import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class ChickenStatisticsScreen extends StatefulScreen
    implements AutoRouteWrapper {
  const ChickenStatisticsScreen({super.key});

  @override
  State<ChickenStatisticsScreen> createState() =>
      _ChickenStatisticsScreenState();

  @override
  Widget wrappedRoute(BuildContext context) => this;
}

class _ChickenStatisticsScreenState
    extends ScreenState<ChickenStatisticsScreen, ChickenViewModel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void initData() {
    super.initData();
    vm.ensureBatchesLoaded();
    vm.ensureCockSalesLoaded();
    vm.ensureExpensesLoaded();
  }

  @override
  void onResume() {
    super.onResume();
    vm.ensureBatchesLoaded();
    vm.ensureCockSalesLoaded();
    vm.ensureExpensesLoaded();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.profitStatistics,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.byMonth),
            Tab(text: l10n.byYear),
          ],
        ),
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          final isFetching =
              vm.isBatchesFetching ||
              vm.isCockSalesFetching ||
              vm.isExpensesFetching;
          return Column(
            children: [
              isFetching
                  ? const LinearProgressIndicator(minHeight: 2)
                  : const SizedBox(height: 2),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildMonthlyStats(vm), _buildYearlyStats(vm)],
                ),
              ),
            ],
          );
        },
      ).webConstrainedBox(),
    );
  }

  Widget _buildMonthlyStats(ChickenViewModel vm) {
    final l10n = AppLocalizations.of(context);
    final stats = vm.getMonthlyStats(_selectedYear);
    final years = vm.getYearlyStats().keys.toList();
    if (!years.contains(_selectedYear)) years.add(_selectedYear);
    years.sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                l10n.yearLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _selectedYear,
                items: years
                    .map((y) => DropdownMenuItem(value: y, child: Text("$y")))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedYear = val);
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final visibleMonths =
                  stats.entries
                      .where(
                        (e) =>
                            e.value.batchRevenue != 0 ||
                            e.value.cockRevenue != 0 ||
                            e.value.meatRevenue != 0 ||
                            e.value.expense != 0,
                      )
                      .toList()
                    ..sort((a, b) => b.key.compareTo(a.key));
              if (visibleMonths.isEmpty) {
                return Center(child: Text(l10n.noDataInYear(_selectedYear)));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: visibleMonths.length,
                itemBuilder: (context, index) {
                  final entry = visibleMonths[index];
                  return _buildStatCard(
                    "${l10n.monthPrefix} ${entry.key}",
                    entry.value,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYearlyStats(ChickenViewModel vm) {
    final l10n = AppLocalizations.of(context);
    final stats = vm.getYearlyStats();
    final sortedYears = stats.keys.toList()..sort((a, b) => b.compareTo(a));

    if (sortedYears.isEmpty) {
      return Center(child: Text(l10n.noStatsData));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedYears.length,
      itemBuilder: (context, index) {
        final year = sortedYears[index];
        final data = stats[year]!;
        return _buildStatCard("${l10n.yearPrefix} $year", data);
      },
    );
  }

  Widget _buildStatCard(String title, ChickenStats data) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            if (data.batchRevenue != 0)
              _buildStatRow(l10n.batchRevenue, data.batchRevenue),
            if (data.cockRevenue != 0)
              _buildStatRow(l10n.cockRevenue, data.cockRevenue),
            if (data.meatRevenue != 0)
              _buildStatRow(l10n.meatRevenue, data.meatRevenue),
            const Divider(height: 8),
            _buildStatRow(
              l10n.totalRevenueLabel,
              data.batchRevenue + data.cockRevenue + data.meatRevenue,
            ),
            _buildStatRow(l10n.totalExpensesLabel, data.expense),
            const SizedBox(height: 4),
            _buildStatRow(
              l10n.profitLabel,
              data.profit,
              color: data.profit >= 0 ? context.colors.money : Colors.red,
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    double value, {
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.theme.colorScheme.onSurfaceVariant),
          ),
          Text(
            "${value.toCurrency()}đ",
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
