/// A single OHLC candle for the candlestick chart.
class Candle {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;

  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  /// True when the candle closed at or above its open (bullish).
  bool get isBull => close >= open;

  Candle copyWith({double? high, double? low, double? close}) {
    return Candle(
      time: time,
      open: open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
    );
  }
}
