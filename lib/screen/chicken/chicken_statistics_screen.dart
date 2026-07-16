import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class ChickenStatisticsScreen extends StatefulScreen implements AutoRouteWrapper {
  const ChickenStatisticsScreen({super.key});

  @override
  State<ChickenStatisticsScreen> createState() => _ChickenStatisticsScreenState();

  @override
  Widget wrappedRoute(BuildContext context) => this;
}

class _ChickenStatisticsScreenState extends ScreenState<ChickenStatisticsScreen, ChickenViewModel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DoAppBar(
        title: "Thống kê lợi nhuận",
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Theo tháng"),
            Tab(text: "Theo năm"),
          ],
        ),
      ),
      body: Consumer<ChickenViewModel>(
        builder: (context, vm, child) {
          return TabBarView(controller: _tabController, children: [_buildMonthlyStats(vm), _buildYearlyStats(vm)]);
        },
      ).webConstrainedBox(),
    );
  }

  Widget _buildMonthlyStats(ChickenViewModel vm) {
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
              const Text("Năm: ", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _selectedYear,
                items: years.map((y) => DropdownMenuItem(value: y, child: Text("$y"))).toList(),
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
              final visibleMonths = stats.entries
                  .where(
                    (e) =>
                        e.value.batchRevenue != 0 ||
                        e.value.cockRevenue != 0 ||
                        e.value.meatRevenue != 0 ||
                        e.value.expense != 0,
                  )
                  .toList();
              if (visibleMonths.isEmpty) {
                return Center(child: Text("Không có dữ liệu trong năm $_selectedYear."));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: visibleMonths.length,
                itemBuilder: (context, index) {
                  final entry = visibleMonths[index];
                  return _buildStatCard("Tháng ${entry.key}", entry.value);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildYearlyStats(ChickenViewModel vm) {
    final stats = vm.getYearlyStats();
    final sortedYears = stats.keys.toList()..sort((a, b) => b.compareTo(a));

    if (sortedYears.isEmpty) {
      return const Center(child: Text("Chưa có dữ liệu thống kê."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedYears.length,
      itemBuilder: (context, index) {
        final year = sortedYears[index];
        final data = stats[year]!;
        return _buildStatCard("Năm $year", data);
      },
    );
  }

  Widget _buildStatCard(String title, ChickenStats data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            if (data.batchRevenue != 0) _buildStatRow("Doanh thu lứa gà", data.batchRevenue, Colors.green[700]!),
            if (data.cockRevenue != 0) _buildStatRow("Doanh thu gà đá", data.cockRevenue, Colors.red[700]!),
            if (data.meatRevenue != 0) _buildStatRow("Doanh thu gà thịt", data.meatRevenue, Colors.brown),
            const Divider(height: 8),
            _buildStatRow("Tổng doanh thu", data.batchRevenue + data.cockRevenue + data.meatRevenue, Colors.green),
            _buildStatRow("Tổng chi phí", data.expense, Colors.orange),
            const SizedBox(height: 4),
            _buildStatRow("Lợi nhuận", data.profit, data.profit >= 0 ? Colors.blue : Colors.red, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, double value, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
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
