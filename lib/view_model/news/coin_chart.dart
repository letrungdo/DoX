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
  ChartData({
    required this.price, //
    required this.chartData,
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
    realTimeSymbols.clear();
  }

  void onRateReceived(RatePushModel data) {
    final code = data.code;
    if (code == null) return;
    final price = data.price;
    final chartData = coinChartMap[code];
    if (chartData != null && price != null) {
      final prevPrice = chartData.price ?? 0;
      
      List<double> updatedChartData;
      
      // Check if this is the first real-time update for this symbol
      if (!realTimeSymbols.contains(code)) {
        // Clear historical data and start fresh with real-time data
        realTimeSymbols.add(code);
        updatedChartData = [price];
      } else {
        // Continue adding real-time data
        updatedChartData = List<double>.from(chartData.chartData);
        updatedChartData.add(price);
        
        // Maintain sliding window of 30 points
        if (updatedChartData.length > 30) {
          updatedChartData.removeAt(0);
        }
      }
      
      coinChartMap[code] = ChartData(
        chartData: updatedChartData,
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
  Set<MarketCode> realTimeSymbols = {}; // Track symbols that have switched to real-time mode



  Future<void> getMarket() async {
    coinChartMap = {};
    realTimeSymbols.clear(); // Clear real-time tracking when refreshing data
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

      // Extract last 30 close prices for chart
      final bars = e.bars;
      final startIndex = math.max(0, bars.length - 30);
      final chartData = bars
          .sublist(startIndex)
          .map((candle) => candle.close)
          .toList();
      
      coinChartMap[code] = ChartData(
        chartData: chartData,
        price: bars.lastOrNull?.close,
      );
    }
    notifyListenersSafe();
  }
}
