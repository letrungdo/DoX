import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/constants/enum/chart_interval.dart';
import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/double_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/services/web_socket/web_socket_service.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/view_model/news/market_detail_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/chart/candle_chart_view.dart';
import 'package:do_x/widgets/app_bar/app_bar_sync_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class MarketDetailScreen extends StatefulScreen implements AutoRouteWrapper {
  final MarketCode code;

  const MarketDetailScreen({super.key, required this.code});

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => FxRateService()),
        Provider<WebSocketService>(create: (_) => WebSocketService()),
        ChangeNotifierProvider(
          create: (_) => MarketDetailViewModel(code: code),
        ),
      ],
      child: this,
    );
  }
}

class _MarketDetailScreenState
    extends ScreenState<MarketDetailScreen, MarketDetailViewModel> {
  @override
  void onResume() {
    super.onResume();
    vm.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: DoAppBar(
        title: widget.code.getName(),
        titleSuffix: AppBarSyncIcon<MarketDetailViewModel>(
          selector: (vm) => vm.isFetching,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: Dimens.screenPadding,
          child: Consumer<MarketDetailViewModel>(
            builder: (context, vm, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(vm),
                  const SizedBox(height: 16),
                  _IntervalSelector(
                    value: vm.interval,
                    onChanged: vm.changeInterval,
                  ),
                  const SizedBox(height: 16),
                  _buildChart(vm),
                  const SizedBox(height: 24),
                  _buildStats(vm),
                ],
              );
            },
          ),
        ).contentConstrainedBox(),
      ),
    );
  }

  Widget _buildHeader(MarketDetailViewModel vm) {
    final changeColor = (vm.dayChange ?? 0).getColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (vm.price).formatUnit(digit: 3),
          style: context.textTheme.primary.size24.bold.copyWith(
            color: vm.color,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              (vm.dayChange).formatUnit(hasPlus: true, digit: 3),
              style: context.textTheme.primary.copyWith(color: changeColor),
            ),
            const SizedBox(width: 8),
            Text(
              "(${(vm.dayChangePercent).formatUnit(hasPlus: true)}%)",
              style: context.textTheme.primary.copyWith(color: changeColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChart(MarketDetailViewModel vm) {
    return SizedBox(
      height: 280,
      child: vm.candles.isEmpty
          ? const Center(child: Loading())
          : CandleChartView(candles: vm.candles, precision: 3),
    );
  }

  /// The session's numbers, then the longer-range ones. Rows whose value the
  /// market doesn't publish are dropped rather than shown as dashes: the
  /// Vietnamese indices carry no 52-week band, only crypto has a market cap.
  Widget _buildStats(MarketDetailViewModel vm) {
    final l10n = AppLocalizations.of(context);
    final overview = vm.overview;
    final yearChange = overview?.yearChangePercent;
    final rows = <(String, double?, String)>[
      (l10n.priceOpen, overview?.open, ''),
      (l10n.priceHigh, overview?.high, ''),
      (l10n.priceLow, overview?.low, ''),
      (l10n.priceRef, overview?.refPrice, ''),
      (l10n.high52Week, vm.high52, ''),
      (l10n.low52Week, vm.low52, ''),
      if (yearChange != null) (l10n.changeYear, yearChange, '%'),
      (l10n.marketCap, overview?.marketCap, 'compact'),
      (l10n.volume24h, overview?.volume24h, 'compact'),
      (l10n.tradeVolume, overview?.dayVolume, 'compact'),
      (l10n.tradeValue, overview?.dayValue, 'compact'),
    ].where((row) => row.$2 != null).toList();

    return Column(
      children: [
        for (final (label, value, format) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: context.textTheme.secondary),
                Text(
                  switch (format) {
                    'compact' => value.formatCompact(),
                    '%' => "${value.formatUnit(hasPlus: true)}%",
                    _ => value.formatUnit(digit: 3),
                  },
                  style: context.textTheme.primary.bold.copyWith(
                    color: format == '%' ? value.getColor() : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Interval selector: a fixed set of primary chips shown inline plus a "more"
/// button. The bottom sheet lists only the intervals that aren't shown inline.
/// When a hidden interval is selected, the button shows its label.
class _IntervalSelector extends StatelessWidget {
  final ChartInterval value;
  final ValueChanged<ChartInterval> onChanged;

  const _IntervalSelector({required this.value, required this.onChanged});

  /// Intervals shown inline (fixed 5).
  static const _primaryCount = 5;

  List<ChartInterval> get _primary =>
      ChartInterval.values.take(_primaryCount).toList();

  List<ChartInterval> get _extra =>
      ChartInterval.values.skip(_primaryCount).toList();

  Future<void> _openSheet(BuildContext context) async {
    final selected = await showAppOptionSheet<ChartInterval>(
      context,
      options: _extra,
      selected: value,
      labelBuilder: (item) => item.label,
    );
    if (selected != null) onChanged(selected);
  }

  /// A segment that fills its [Expanded] cell so every option has the exact
  /// same width and the gaps stay even.
  Widget _cell(
    BuildContext context, {
    required Widget child,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    return Material(
      // Unselected segments are a sunken well rather than an outlined pill —
      // the neumorphic way to show "not active".
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 34,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: IconTheme(
                  data: IconThemeData(color: fg, size: 18),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: fg,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extraSelected = _extra.contains(value);
    return Row(
      spacing: 6,
      children: [
        for (final item in _primary)
          Expanded(
            child: _cell(
              context,
              selected: item == value,
              onTap: () => onChanged(item),
              child: Text(item.label),
            ),
          ),
        Expanded(
          child: _cell(
            context,
            selected: extraSelected,
            onTap: () => _openSheet(context),
            child: extraSelected
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(value.label),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  )
                : const Icon(Icons.more_horiz),
          ),
        ),
      ],
    );
  }
}
