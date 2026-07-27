import 'package:do_x/model/candle.dart';
import 'package:financial_chart/financial_chart.dart';
import 'package:flutter/material.dart';

/// Candlestick chart backed by the `financial_chart` package. Provides
/// pan/zoom, crosshair and an OHLC tooltip out of the box, with the value axis
/// auto-scaling to the visible window. Feed it [candles]; it rebuilds the data
/// on change and repaints in place (so live last-candle updates are cheap).
class CandleChartView extends StatefulWidget {
  final List<Candle> candles;
  final int precision;

  const CandleChartView({super.key, required this.candles, this.precision = 3});

  @override
  State<CandleChartView> createState() => _CandleChartViewState();
}

class _CandleChartViewState extends State<CandleChartView>
    with TickerProviderStateMixin {
  static const _kOpen = 'open';
  static const _kHigh = 'high';
  static const _kLow = 'low';
  static const _kClose = 'close';

  GChart? _chart;
  Brightness? _brightness;

  List<GData<int>> _toData() {
    return widget.candles
        .map(
          (c) => GData<int>(
            pointValue: c.time.millisecondsSinceEpoch,
            seriesValues: [c.open, c.high, c.low, c.close],
          ),
        )
        .toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_chart == null || brightness != _brightness) {
      _brightness = brightness;
      _buildChart();
    }
  }

  @override
  void didUpdateWidget(covariant CandleChartView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.candles, oldWidget.candles)) {
      _syncData(oldWidget.candles.length);
    }
  }

  @override
  void dispose() {
    _chart?.dispose();
    super.dispose();
  }

  /// Transparent background (so the page shows through), no outer border, and
  /// faint axis/grid lines.
  GTheme _buildTheme() {
    final base = _brightness == Brightness.dark ? GThemeDark() : GThemeLight();
    final faint = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.12);

    PaintStyle dim(PaintStyle s) =>
        s.copyWith(strokeColor: faint, strokeWidth: 0.5);

    final pointAxis = base.pointAxisTheme.copyWith(
      lineStyle: dim(base.pointAxisTheme.lineStyle),
      tickerStyle: dim(base.pointAxisTheme.tickerStyle),
    );
    final valueAxis = base.valueAxisTheme.copyWith(
      lineStyle: dim(base.valueAxisTheme.lineStyle),
      tickerStyle: dim(base.valueAxisTheme.tickerStyle),
    );
    final gridsBase = base.graphTheme(GGraphGrids.typeName) as GGraphGridsTheme;
    final grids = gridsBase.copyWith(lineStyle: dim(gridsBase.lineStyle));

    return base.extend(
      // Empty paint = no fill and no stroke → removes the chart bg and border.
      backgroundTheme: base.backgroundTheme.copyWith(style: PaintStyle()),
      panelTheme: base.panelTheme.copyWith(style: PaintStyle()),
      pointAxisTheme: pointAxis,
      valueAxisTheme: valueAxis,
      graphThemes: {GGraphGrids.typeName: grids},
    );
  }

  void _buildChart() {
    final dataSource = GDataSource<int, GData<int>>(
      dataList: _toData(),
      seriesProperties: [
        GDataSeriesProperty(
          key: _kOpen,
          label: 'O',
          precision: widget.precision,
        ),
        GDataSeriesProperty(
          key: _kHigh,
          label: 'H',
          precision: widget.precision,
        ),
        GDataSeriesProperty(
          key: _kLow,
          label: 'L',
          precision: widget.precision,
        ),
        GDataSeriesProperty(
          key: _kClose,
          label: 'C',
          precision: widget.precision,
        ),
      ],
    );

    _chart = GChart(
      dataSource: dataSource,
      theme: _buildTheme(),
      pointViewPort: GPointViewPort(
        autoScaleStrategy: const GPointViewPortAutoScaleStrategyLatest(
          endSpacingPoints: 5,
        ),
      ),
      panels: [
        GPanel(
          valueViewPorts: [
            GValueViewPort(
              id: 'price',
              valuePrecision: widget.precision,
              autoScaleStrategy: GValueViewPortAutoScaleStrategyMinMax(
                dataKeys: const [_kHigh, _kLow],
                marginStart: GSize.viewHeightRatio(0.1),
                marginEnd: GSize.viewHeightRatio(0.1),
              ),
            ),
          ],
          valueAxes: [
            GValueAxis(viewPortId: 'price', position: GAxisPosition.end),
          ],
          pointAxes: [GPointAxis()],
          graphs: [
            GGraphGrids(valueViewPortId: 'price'),
            GGraphOhlc(
              valueViewPortId: 'price',
              drawAsCandle: true,
              ohlcValueKeys: const [_kOpen, _kHigh, _kLow, _kClose],
            ),
          ],
          tooltip: GTooltip(
            position: GTooltipPosition.topLeft,
            dataKeys: const [_kOpen, _kHigh, _kLow, _kClose],
            followValueKey: _kClose,
            followValueViewPortId: 'price',
          ),
        ),
      ],
    );
  }

  /// Replace the data in place and repaint. Only re-run auto-scale when the
  /// number of candles changed (interval switch / more history); a live tick
  /// only mutates the last candle, so we keep the user's pan/zoom.
  void _syncData(int oldLength) {
    final chart = _chart;
    if (chart == null) return;
    final data = _toData();
    chart.dataSource.dataList
      ..clear()
      ..addAll(data);
    if (data.length != oldLength) {
      chart.autoScaleViewports();
    }
    chart.repaint();
  }

  @override
  Widget build(BuildContext context) {
    final chart = _chart;
    if (chart == null) return const SizedBox.shrink();
    return GChartWidget(chart: chart, tickerProvider: this);
  }
}
