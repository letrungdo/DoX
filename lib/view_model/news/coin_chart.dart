import 'dart:async';
import 'dart:math';

import 'package:do_x/constants/chart.dart';
import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/model/rate_push_model.dart';
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/services/web_socket/web_socket_service.dart';
import 'package:do_x/theme/chart_theme.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:financial_chart/financial_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChartData {
  double? price;
  Color? color;
  final GChart chart;
  ChartData({
    required this.price, //
    required this.chart,
    this.color,
  });
}

mixin CoinChartMixin on CoreViewModel {
  FxRateService get fxRateService => context.read<FxRateService>();
  WebSocketService get socketService => context.read<WebSocketService>();

  late StreamSubscription<RatePushModel> _rateSubscription;

  @override
  void initState() {
    super.initState();
    _rateSubscription = socketService.rateStream.listen(onRateReceived);
  }

  @override
  void dispose() {
    super.dispose();
    _rateSubscription.cancel();
  }

  void onRateReceived(RatePushModel data) {
    final code = data.code;
    if (code == null) return;
    final price = data.price;
    final chartData = coinChartMap[code];
    if (chartData != null && price != null) {
      // _liveUpdate(chartData.chart, price);
      final prevPrice = chartData.price ?? 0;
      coinChartMap[code] = ChartData(
        chart: chartData.chart,
        price: price,
        color:
            price > prevPrice
                ? Colors.green
                : price < prevPrice
                ? Colors.red
                : null,
      );
      notifyListenersSafe();
    }
  }

  Map<MarketCode, ChartData> coinChartMap = {};

  GChart _initCoinChart(GDataSource dataSource) {
    return GChart(
      dataSource: dataSource,
      theme: ChartThemeLight(),
      minSize: Size(100, 50),
      // area: Rect.fromLTWH(0, 0, 100, 50),
      pointViewPort: GPointViewPort(
        initialStartPoint: dataSource.dataList.length - 30, //
        initialEndPoint: dataSource.dataList.length.toDouble(),
      ),
      panels: [
        GPanel(
          valueViewPorts: [
            GValueViewPort(valuePrecision: 2, autoScaleStrategy: GValueViewPortAutoScaleStrategyMinMax(dataKeys: ["high", "low"])),
          ],
          valueAxes: [],
          pointAxes: [],
          graphs: [
            GGraphOhlc(ohlcValueKeys: const ["open", "high", "low", "close"]),
          ],
        ),
      ],
    );
  }

  void _liveUpdate(GChart? chart, double price) {
    if (chart == null) {
      return;
    }
    final dataSource = chart.dataSource;
    if (dataSource.length == 0) {
      return;
    }
    var lastData = dataSource.dataList.last;
    final latestPrice = lastData.seriesValues[3] + price;
    // if (t.tick % 10 == 0) {
    // append new data every 10 ticks
    dataSource.dataList.add(
      GData<int>(
        pointValue: lastData.pointValue + 86400000,
        seriesValues: [
          ...[latestPrice, latestPrice, latestPrice, latestPrice], // ohlc
          ...lastData.seriesValues.sublist(
            4,
          ), // here we just copy the rest, in real case we need to set correct volume and indicator values
        ],
      ),
    );
    // }
    // update last data high, low, close
    lastData = dataSource.dataList.last;
    lastData.seriesValues[dataSource.seriesKeyToIndex(keyClose)] = latestPrice; // close
    final ohlcValues = [
      lastData.seriesValues[dataSource.seriesKeyToIndex(keyOpen)],
      lastData.seriesValues[dataSource.seriesKeyToIndex(keyHigh)],
      lastData.seriesValues[dataSource.seriesKeyToIndex(keyLow)],
      lastData.seriesValues[dataSource.seriesKeyToIndex(keyClose)],
    ];
    lastData.seriesValues[dataSource.seriesKeyToIndex(keyHigh)] = ohlcValues.reduce(max); // high
    lastData.seriesValues[dataSource.seriesKeyToIndex(keyLow)] = ohlcValues.reduce(min); // low
    // update axis marker and line marker
    // lineMarker!.keyCoordinates[0] = (lineMarker!.keyCoordinates[0] as GCustomCoord).copyWith(y: latestPrice);
    // lineMarker!.keyCoordinates[1] = (lineMarker!.keyCoordinates[1] as GCustomCoord).copyWith(y: latestPrice);
    // valueAxisMarker!.labelValue = latestPrice;
    // pointAxisMarker!.labelPoint = dataSource.lastPoint;
    // reset viewport if allowed and redraw chart
    chart.autoScaleViewports();
    chart.repaint();
  }

  Future<void> getMarket() async {
    coinChartMap = {};
    notifyInInitState();
    final res = await fxRateService.getMarket(cancelToken: cancelToken);
    if (res.isCancelByUser) {
      return;
    }
    if (res.isError) {
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        res.error, //
        onRetry: getMarket,
      );
      return;
    }
    final data = res.data ?? [];
    for (final e in data) {
      final code = e.code;
      if (code == null) continue;

      final dataSource = GDataSource<int, GData<int>>(
        dataList:
            e.bars.map((candle) {
              return GData<int>(
                pointValue: candle.date.millisecondsSinceEpoch,
                seriesValues: [candle.open, candle.high, candle.low, candle.close, candle.volume],
              );
            }).toList(),
        seriesProperties: const [
          GDataSeriesProperty(key: keyOpen, label: 'Open', precision: 2),
          GDataSeriesProperty(key: keyHigh, label: 'High', precision: 2),
          GDataSeriesProperty(key: keyLow, label: 'Low', precision: 2),
          GDataSeriesProperty(key: keyClose, label: 'Close', precision: 2),
          GDataSeriesProperty(key: keyVolume, label: 'Volume', precision: 0),
        ],
      );
      coinChartMap[code] = ChartData(
        chart: _initCoinChart(dataSource), //
        price: e.bars.firstOrNull?.close,
      );
    }
    notifyListenersSafe();
  }
}
