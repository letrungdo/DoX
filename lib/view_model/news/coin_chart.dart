import 'dart:async';
import 'dart:math' as math;

import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/model/rate_push_model.dart';
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/services/web_socket/web_socket_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ChartData {
  double? price;
  Color? color;
  final List<double> chartData;

  /// Timestamps aligned 1:1 with [chartData]. Used to plot the x-axis
  /// proportionally to real time instead of evenly by index.
  final List<DateTime> times;

  ChartData({
    required this.price, //
    required this.chartData,
    this.times = const [],
    this.color,
  });
}

mixin CoinChartMixin on CoreViewModel {
  late FxRateService fxRateService;
  late WebSocketService socketService;

  late StreamSubscription<RatePushModel> _rateSubscription;

  @override
  void initState() {
    fxRateService = context.read<FxRateService>();
    socketService = context.read<WebSocketService>();
    super.initState();
    _rateSubscription = socketService.rateStream.listen(onRateReceived);
  }

  @override
  void dispose() {
    _rateSubscription.cancel();
    super.dispose();
  }

  /// Max number of points kept on screen (historical + real-time sliding window).
  static const int _maxChartPoints = 40;

  /// Chart timeframe in ms — must match the REST `timeframe=1m` param so the
  /// real-time ticks fold into the same candle buckets as the historical bars.
  static const int _bucketMs = 1 * 60 * 1000;

  void onRateReceived(RatePushModel data) {
    final code = data.code;
    if (code == null) return;
    final price = data.price;
    final chartData = coinChartMap[code];
    if (chartData == null || price == null) return;

    // Real-time ticks arrive every few seconds, but the chart is a 5m series.
    // Fold each tick into its 5m bucket: update the current (live) candle in
    // place, and only append a new point when crossing into the next bucket.
    final tickTime = data.time ?? DateTime.now();
    final bucketMs = (tickTime.millisecondsSinceEpoch ~/ _bucketMs) * _bucketMs;

    final points = List<double>.from(chartData.chartData);
    final times = List<DateTime>.from(chartData.times);

    final inCurrentBucket = points.isNotEmpty &&
        times.isNotEmpty &&
        times.last.millisecondsSinceEpoch == bucketMs;

    if (inCurrentBucket) {
      // Same 5m candle → let the last point breathe with the live price.
      if (points.last == price) return; // no visible change
      points[points.length - 1] = price;
    } else {
      // New 5m candle → append a point aligned to the bucket start, then keep
      // only the most recent window.
      points.add(price);
      times.add(DateTime.fromMillisecondsSinceEpoch(bucketMs));
      if (points.length > _maxChartPoints) {
        points.removeRange(0, points.length - _maxChartPoints);
        times.removeRange(0, times.length - _maxChartPoints);
      }
    }

    coinChartMap[code] = ChartData(
      chartData: points,
      times: times,
      price: price,
      color: _trendColor(points),
    );
    notifyListenersSafe();
  }

  /// Color reflects the trend of the visible window (matches what the line
  /// shows): green when it ends higher than it started, red when lower.
  Color? _trendColor(List<double> points) {
    if (points.length < 2) return null;
    final diff = points.last - points.first;
    if (diff > 0) return Colors.green;
    if (diff < 0) return Colors.red;
    return null;
  }

  Map<MarketCode, ChartData> coinChartMap = {};

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

      // Sort by time ascending so the x-axis is chronological even if the API
      // returns bars out of order, then keep the most recent window.
      final bars = List.of(e.bars)..sort((a, b) => a.date.compareTo(b.date));
      final startIndex = math.max(0, bars.length - _maxChartPoints);
      final window = bars.sublist(startIndex);
      final chartData = window.map((candle) => candle.close).toList();
      final times = window.map((candle) => candle.date).toList();

      coinChartMap[code] = ChartData(
        chartData: chartData,
        times: times,
        price: window.lastOrNull?.close,
        color: _trendColor(chartData),
      );
    }
    notifyListenersSafe();
  }
}
