import 'dart:async';
import 'dart:math' as math;

import 'package:do_x/constants/enum/chart_interval.dart';
import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/model/candle.dart';
import 'package:do_x/model/rate_push_model.dart';
import 'package:do_x/services/fx_rate_service.dart';
import 'package:do_x/services/web_socket/web_socket_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MarketDetailViewModel extends CoreViewModel {
  MarketDetailViewModel({required this.code});

  final MarketCode code;

  /// Number of candles fetched per window. The API only supports `countBack`
  /// (most-recent N bars) with no timestamp pagination, so we load a generous
  /// window that the chart can pan/zoom across.
  static const int _countBack = 300;

  late FxRateService _fxRateService;
  late WebSocketService _socketService;
  StreamSubscription<RatePushModel>? _rateSubscription;

  ChartInterval _interval = ChartInterval.m1;
  ChartInterval get interval => _interval;

  List<Candle> _candles = [];
  List<Candle> get candles => _candles;

  double? _price;
  double? get price => _price;

  Color? _color;
  Color? get color => _color;

  double? _dayChange;
  double? get dayChange => _dayChange;
  double? _dayChangePercent;
  double? get dayChangePercent => _dayChangePercent;

  double? _high52;
  double? get high52 => _high52;
  double? _low52;
  double? get low52 => _low52;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Number of bars requests in flight. Counted rather than flagged so a stale
  /// request finishing (e.g. cancelled by an interval switch) can't clear the
  /// state of the one that replaced it.
  int _inFlight = 0;

  /// True while any bars request is running, whatever triggered it — this is
  /// what the app bar sync icon watches.
  bool get isFetching => _inFlight > 0;

  @override
  void initState() {
    _fxRateService = context.read<FxRateService>();
    _socketService = context.read<WebSocketService>();
    super.initState();
    _rateSubscription = _socketService.rateStream.listen(_onRateReceived);
    _socketService.connect(context);
  }

  @override
  void initData() {
    super.initData();
    fetchBars(showLoading: true);
  }

  @override
  void dispose() {
    _rateSubscription?.cancel();
    _socketService.disconnect();
    super.dispose();
  }

  Future<void> changeInterval(ChartInterval value) async {
    if (value == _interval) return;
    _interval = value;
    // Drop the old series so the chart doesn't blend two timeframes.
    _candles = [];
    notifyListenersSafe();
    renewCancelToken('changeInterval');
    await fetchBars(showLoading: true);
  }

  Future<void> onRefresh() {
    renewCancelToken('onRefresh');
    return fetchBars(showLoading: true);
  }

  Future<void> fetchBars({bool showLoading = false}) async {
    _inFlight++;
    if (showLoading) _isLoading = true;
    notifyListenersSafe();
    try {
      await _fetchBars();
    } finally {
      _inFlight--;
      notifyListenersSafe();
    }
  }

  Future<void> _fetchBars() async {
    final res = await _fxRateService.getBars(
      code: code,
      timeframe: _interval.timeframe,
      countBack: _countBack,
      cancelToken: cancelToken,
    );
    if (res.isCancelByUser) return;
    if (res.isError) {
      _isLoading = false;
      notifyListenersSafe();
      showAppError(
        // ignore: use_build_context_synchronously
        context,
        res.error,
        onRetry: () => fetchBars(showLoading: true),
      );
      return;
    }

    // API returns newest-first; sort ascending so the x-axis is chronological.
    final bars = [...?res.data]..sort((a, b) => a.date.compareTo(b.date));

    // Some timeframes (e.g. 1M) return duplicate timestamps — keep the last
    // value per timestamp so each candle appears once.
    final byTime = <int, Candle>{};
    for (final b in bars) {
      byTime[b.date.millisecondsSinceEpoch] = Candle(
        time: b.date,
        open: b.open,
        high: b.high,
        low: b.low,
        close: b.close,
      );
    }
    _candles = byTime.values.toList()..sort((a, b) => a.time.compareTo(b.time));

    _price = _candles.lastOrNull?.close;
    _color = _trendColor(_candles);
    _isLoading = false;
    notifyListenersSafe();
  }

  void _onRateReceived(RatePushModel data) {
    if (data.code != code) return;
    final price = data.price;
    if (price == null) return;

    // Live stats straight from the push payload.
    _dayChange = data.dayChange;
    _dayChangePercent = data.dayChangePercent;
    _high52 = data.highWeek52Price;
    _low52 = data.lowWeek52Price;

    _price = price;

    // Update only the latest candle in place: it "breathes" with the live
    // price (close = last tick, high/low expand). New candles arrive on the
    // next fetch/refresh, so we never create fake buckets from ticks.
    if (_candles.isNotEmpty) {
      final last = _candles.last;
      if (last.close != price || price > last.high || price < last.low) {
        final updated = last.copyWith(
          close: price,
          high: math.max(last.high, price),
          low: math.min(last.low, price),
        );
        _candles = [..._candles];
        _candles[_candles.length - 1] = updated;
      }
    }

    _color = _trendColor(_candles);
    notifyListenersSafe();
  }

  Color? _trendColor(List<Candle> candles) {
    if (candles.length < 2) return null;
    final diff = candles.last.close - candles.first.close;
    if (diff > 0) return Colors.green;
    if (diff < 0) return Colors.red;
    return null;
  }
}
