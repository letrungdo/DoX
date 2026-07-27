/// Chart timeframe options offered on the market detail screen.
///
/// [timeframe] is the value sent to the REST API's `timeframe` param, and
/// [bucketMs] is the same interval in milliseconds — used to fold real-time
/// WebSocket ticks into the current candle so live updates line up exactly
/// with the historical bars.
enum ChartInterval {
  m1('1m', '1m', 60 * 1000),
  m5('5m', '5m', 5 * 60 * 1000),
  m15('15m', '15m', 15 * 60 * 1000),
  m30('30m', '30m', 30 * 60 * 1000),
  h1('1h', '1h', 60 * 60 * 1000),
  h4('4h', '4h', 4 * 60 * 60 * 1000),
  d1('1D', '1d', 24 * 60 * 60 * 1000),
  w1('1W', '1w', 7 * 24 * 60 * 60 * 1000),
  mo1('1M', '1M', 30 * 24 * 60 * 60 * 1000);

  const ChartInterval(this.label, this.timeframe, this.bucketMs);

  /// Text shown on the selector chip.
  final String label;

  /// Value sent to the API `timeframe` query param.
  final String timeframe;

  /// Interval length in milliseconds for real-time bucketing.
  final int bucketMs;
}
