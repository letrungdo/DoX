import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/extensions/number_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/repository/chicken_repository.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/chart/cute_bar_chart.dart';
import 'package:do_x/widgets/chicken_stale_banner.dart';
import 'package:do_x/widgets/input/year_filter.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// One bucket of the statistics screen: a period (a month or a year) and the
/// figures accumulated in it.
typedef _Period = ({
  int key,
  String label,
  String shortLabel,
  ChickenStats data,
});

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

  /// Only the monthly tab is year-filtered, so only it needs to be scrolled
  /// back to the top when the year changes.
  final _monthlyScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  /// Waits a frame so the newly selected year is laid out before scrolling.
  void _scrollMonthlyToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_monthlyScrollController.hasClients) {
        _monthlyScrollController.animateTo(
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
    vm.ensureLoaded(ChickenSection.values.toSet());
  }

  @override
  void onResume() {
    super.onResume();
    vm.ensureLoaded(ChickenSection.values.toSet());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _monthlyScrollController.dispose();
    super.dispose();
  }

  ColorScheme get _scheme => context.theme.colorScheme;

  /// Revenue sources always keep the same color across the screen, so a slice
  /// of the stacked bar, its legend dot and its detail row all read as one.
  Color get _chickColor => _scheme.primary;
  Color get _cockColor => context.colors.danger;
  Color get _meatColor => context.colors.meat;

  String _compact(double value) => value.toCompactCurrency(
    locale: Localizations.localeOf(context).toString(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(
        title: l10n.profitStatistics,
        titleSuffix: AppBarSyncIcon<ChickenViewModel>(
          selector: (vm) => vm.isFetching,
        ),
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
          return Column(
            children: [
              ChickenStaleBanner(sections: ChickenSection.values.toSet()),
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

  // ---------------------------------------------------------------- monthly

  Widget _buildMonthlyStats(ChickenViewModel vm) {
    final l10n = AppLocalizations.of(context);
    final cal = vm.useLunarCalendar ? l10n.lunarShort : l10n.solarShort;
    final stats = vm.getMonthlyStats(_selectedYear);
    final years = vm.getYearlyStats().keys.toList();
    if (!years.contains(_selectedYear)) years.add(_selectedYear);
    years.sort((a, b) => b.compareTo(a));

    // Every month feeds the chart (an empty month is a meaningful gap there),
    // but only months with figures get a detail card.
    final allMonths = [
      for (var m = 1; m <= 12; m++)
        (
          key: m,
          label: "${l10n.monthPrefix} $m",
          shortLabel: l10n.monthShort(m),
          data: stats[m]!,
        ),
    ];
    final active = allMonths.where(_hasData).toList();
    // Months after the last recorded one are dropped: the chart highlights its
    // rightmost group by default, and an empty December is a useless highlight.
    // Gaps between recorded months are kept — those are real.
    final chartMonths = active.isEmpty
        ? allMonths
        : allMonths.sublist(0, active.last.key);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              YearFilter(
                selectedYear: _selectedYear,
                years: years,
                onChanged: (val) {
                  setState(() => _selectedYear = val);
                  // A different year is a different list — start it from the
                  // top instead of keeping the old scroll offset.
                  _scrollMonthlyToTop();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: active.isEmpty
              ? _buildEmpty(l10n.noDataInYear(_selectedYear))
              : _buildStatsList(
                  controller: _monthlyScrollController,
                  periods: active.reversed.toList(),
                  chartPeriods: chartMonths,
                  headline: "${l10n.yearPrefix} $_selectedYear ($cal)",
                  subhead: l10n.activeMonths(active.length),
                  averageLabel: l10n.averagePerMonth,
                  bestLabel: l10n.bestMonth,
                  detailsLabel: l10n.monthlyDetails,
                ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- yearly

  Widget _buildYearlyStats(ChickenViewModel vm) {
    final l10n = AppLocalizations.of(context);
    final cal = vm.useLunarCalendar ? l10n.lunarShort : l10n.solarShort;
    final stats = vm.getYearlyStats();
    final sortedYears = stats.keys.toList()..sort();

    final periods = [
      for (final year in sortedYears)
        (
          key: year,
          label: "${l10n.yearPrefix} $year",
          shortLabel: "$year",
          data: stats[year]!,
        ),
    ];
    final active = periods.where(_hasData).toList();
    if (active.isEmpty) return _buildEmpty(l10n.noStatsData);

    return _buildStatsList(
      periods: active.reversed.toList(),
      chartPeriods: active,
      headline: "${l10n.allYearsLabel} ($cal)",
      subhead: l10n.activeYears(active.length),
      averageLabel: l10n.averagePerYear,
      bestLabel: l10n.bestYear,
      detailsLabel: l10n.yearlyDetails,
    );
  }

  // ------------------------------------------------------------- shared UI

  bool _hasData(_Period p) =>
      p.data.batchRevenue != 0 ||
      p.data.cockRevenue != 0 ||
      p.data.meatRevenue != 0 ||
      p.data.expense != 0;

  double _revenueOf(ChickenStats s) =>
      s.batchRevenue + s.cockRevenue + s.meatRevenue;

  ChickenStats _totalOf(Iterable<ChickenStats> all) {
    var batch = 0.0, cock = 0.0, meat = 0.0, expense = 0.0;
    for (final s in all) {
      batch += s.batchRevenue;
      cock += s.cockRevenue;
      meat += s.meatRevenue;
      expense += s.expense;
    }
    return (
      batchRevenue: batch,
      cockRevenue: cock,
      meatRevenue: meat,
      expense: expense,
      profit: batch + cock + meat - expense,
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_chart_outlined_rounded,
              size: 56,
              color: _scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: _scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  /// The whole tab body: headline summary, the chart, then one card per period.
  /// [periods] is newest-first (reading order); [chartPeriods] is oldest-first
  /// so the chart's x-axis runs forward in time.
  Widget _buildStatsList({
    ScrollController? controller,
    required List<_Period> periods,
    required List<_Period> chartPeriods,
    required String headline,
    required String subhead,
    required String averageLabel,
    required String bestLabel,
    required String detailsLabel,
  }) {
    final total = _totalOf(periods.map((p) => p.data));
    final best = periods.reduce(
      (a, b) => b.data.profit > a.data.profit ? b : a,
    );

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildSummaryCard(
          headline: headline,
          subhead: subhead,
          total: total,
          averageLabel: averageLabel,
          average: total.profit / periods.length,
          bestLabel: bestLabel,
          best: best,
        ),
        const SizedBox(height: 14),
        _buildChartCard(chartPeriods),
        const SizedBox(height: 18),
        _buildSectionLabel(detailsLabel),
        const SizedBox(height: 8),
        for (final period in periods) ...[
          _buildPeriodCard(period),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: _scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(height: 1, color: _scheme.outlineVariant)),
      ],
    );
  }

  /// Headline card: the profit for the whole range as the one big number, with
  /// the revenue/expense pair and the split that produced it underneath.
  Widget _buildSummaryCard({
    required String headline,
    required String subhead,
    required ChickenStats total,
    required String averageLabel,
    required double average,
    required String bestLabel,
    required _Period best,
  }) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final revenue = _revenueOf(total);
    final isUp = total.profit >= 0;
    final accent = isUp ? colors.money : colors.danger;
    final margin = revenue > 0 ? total.profit / revenue * 100 : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: _scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: _scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: context.theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subhead,
                      style: TextStyle(
                        fontSize: 13,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (margin != null)
                _buildTag(
                  "${l10n.profitMargin} ${margin.toStringAsFixed(0)}%",
                  accent,
                  icon: isUp
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Label and figure share one line; the figure shrinks to fit instead
          // of wrapping when the number gets long.
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                l10n.profitLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "${total.profit.toCurrency()}đ",
                    maxLines: 1,
                    style: context.theme.textTheme.headlineMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  Icons.arrow_downward_rounded,
                  l10n.totalRevenueLabel,
                  revenue,
                  colors.money,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  Icons.arrow_upward_rounded,
                  l10n.totalExpensesLabel,
                  total.expense,
                  colors.warning,
                ),
              ),
            ],
          ),
          if (revenue > 0) ...[
            const SizedBox(height: 14),
            Text(
              l10n.revenueBreakdown,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _buildStackedBar(total, height: 12),
            const SizedBox(height: 10),
            _buildLegendList(total, revenue, spacing: 6),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: _scheme.outlineVariant),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildFooterStat(
                  averageLabel,
                  "${average.toCurrency()}đ",
                  average >= 0 ? colors.money : colors.danger,
                ),
              ),
              Expanded(
                child: _buildFooterStat(
                  bestLabel,
                  "${best.label} · ${_compact(best.data.profit)}đ",
                  best.data.profit >= 0 ? colors.success : colors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Revenue against expense, period by period. Tapping a group moves the
  /// chart's own header onto it, which is where the exact figures show up.
  Widget _buildChartCard(List<_Period> periods) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.revenueVsExpense,
              style: context.theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // The revenue bar is stacked by source, so the same four colors as
            // the cards explain what each bar is made of.
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildChartLegend(_chickColor, l10n.batchRevenue),
                _buildChartLegend(_cockColor, l10n.cockRevenue),
                _buildChartLegend(_meatColor, l10n.meatRevenue),
                _buildChartLegend(colors.warning, l10n.expensesTitle),
              ],
            ),
            const SizedBox(height: 10),
            CuteBarChart(
              items: [
                for (final period in periods)
                  CuteBarChartItem(
                    label: period.shortLabel,
                    value: _revenueOf(period.data),
                    compareValue: period.data.expense,
                    segments: [
                      CuteBarSegment(_chickColor, period.data.batchRevenue),
                      CuteBarSegment(_cockColor, period.data.cockRevenue),
                      CuteBarSegment(_meatColor, period.data.meatRevenue),
                    ],
                  ),
              ],
              // The compare series is drawn first, so expense sits to the left
              // of the revenue bar it belongs to.
              primaryColor: colors.money,
              compareColor: colors.warning,
              height: 160,
              formatValue: (value) => "${_compact(value)}đ",
            ),
          ],
        ),
      ),
    );
  }

  /// One period: its profit as a colored pill, then the revenue split, then the
  /// three figures behind it.
  Widget _buildPeriodCard(_Period period) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final data = period.data;
    final revenue = _revenueOf(data);
    final isUp = data.profit >= 0;
    final accent = isUp ? colors.success : colors.danger;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    period.shortLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    period.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildTag(
                  "${data.profit.toCurrency()}đ",
                  accent,
                  icon: isUp
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                ),
              ],
            ),
            if (revenue > 0) ...[
              const SizedBox(height: 12),
              _buildStackedBar(data),
              const SizedBox(height: 8),
              _buildLegendList(data, revenue, spacing: 4),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildInlineStat(
                    l10n.badgeRevenue,
                    revenue,
                    colors.money,
                  ),
                ),
                Expanded(
                  child: _buildInlineStat(
                    l10n.badgeExpense,
                    data.expense,
                    colors.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ small parts

  Widget _buildDot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  /// Name-only legend for the chart, where the figures live in the chart's own
  /// header instead of next to the swatch.
  Widget _buildChartLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: _scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color accent, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: accent),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  /// Revenue split as one bar. Widths are proportional, so the dominant source
  /// is obvious before any number is read.
  Widget _buildStackedBar(ChickenStats data, {double height = 10}) {
    final parts = <(Color, double)>[
      (_chickColor, data.batchRevenue),
      (_cockColor, data.cockRevenue),
      (_meatColor, data.meatRevenue),
    ].where((p) => p.$2 > 0).toList();
    final total = parts.fold<double>(0, (sum, p) => sum + p.$2);
    if (total <= 0) {
      return Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          // Without stretch the childless ColoredBoxes collapse to zero height
          // and the bar paints nothing.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final part in parts)
              Expanded(
                // Integer flex: a hair of rounding is invisible at bar scale.
                flex: (part.$2 / total * 1000).round().clamp(1, 1000),
                child: ColoredBox(color: part.$1),
              ),
          ],
        ),
      ),
    );
  }

  /// One revenue source: swatch, name, then its amount and its share. Both
  /// figures are shown — the share says how it compares, the amount is what the
  /// user actually books.
  /// The revenue split as one legend per line, every label padded to the widest
  /// name so the figures start at the same x.
  Widget _buildLegendList(
    ChickenStats data,
    double revenue, {
    required double spacing,
  }) {
    final l10n = AppLocalizations.of(context);
    final sources = <(Color, String, double)>[
      if (data.batchRevenue != 0)
        (_chickColor, l10n.batchRevenue, data.batchRevenue),
      if (data.cockRevenue != 0)
        (_cockColor, l10n.cockRevenue, data.cockRevenue),
      if (data.meatRevenue != 0)
        (_meatColor, l10n.meatRevenue, data.meatRevenue),
    ];
    // Measured over all three names, not just the ones this card shows, so the
    // figures start at the same x on every card.
    final labelWidth = _legendLabelWidth([
      l10n.batchRevenue,
      l10n.cockRevenue,
      l10n.meatRevenue,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, source) in sources.indexed) ...[
          if (index > 0) SizedBox(height: spacing),
          _buildLegend(
            source.$1,
            source.$2,
            source.$3,
            revenue,
            labelWidth: labelWidth,
          ),
        ],
      ],
    );
  }

  static const _legendLabelStyle = TextStyle(fontSize: 13);

  /// The widest of the revenue-source names, so every legend reserves the same
  /// room for its label and the figures line up in a column.
  double _legendLabelWidth(List<String> labels) {
    final scaler = MediaQuery.textScalerOf(context);
    // The Text widgets merge the ambient default style (font family, height),
    // so measuring with the bare style would come out narrow and clip the
    // longest name to an ellipsis.
    final style = DefaultTextStyle.of(context).style.merge(_legendLabelStyle);
    var widest = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        maxLines: 1,
        textScaler: scaler,
      )..layout();
      if (painter.width > widest) widest = painter.width;
    }
    // Round up: a fractional shortfall is enough to trigger the ellipsis.
    return widest.ceilToDouble();
  }

  Widget _buildLegend(
    Color color,
    String label,
    double value,
    double total, {
    double? labelWidth,
  }) {
    final percent = total > 0 ? (value / total * 100).round() : 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(color),
        const SizedBox(width: 5),
        // The source names are long ("Doanh thu gà đá"); the label gives way
        // before the figure does.
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _legendLabelStyle.copyWith(color: _scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              "${value.toCurrency()}đ · $percent%",
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    IconData icon,
    String label,
    double value,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: _scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              "${value.toCurrency()}đ",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterStat(String label, String value, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: _scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineStat(String label, double value, Color accent) {
    return Row(
      children: [
        Text(
          "$label ",
          style: TextStyle(fontSize: 13, color: _scheme.onSurfaceVariant),
        ),
        Flexible(
          child: Text(
            "${value.toCurrency()}đ",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
      ],
    );
  }
}
