import 'package:do_x/constants/enum/market_code.dart';

/// A market's live snapshot from the market API's overview endpoints — the
/// numbers the bars endpoint doesn't carry (day change, session range, 52-week
/// band, market cap, turnover).
///
/// One class covers all four endpoints (`commodities`, `cryptos`, `indexes`,
/// `indices`): they share the price fields and differ only in the extras, which
/// stay null where the endpoint doesn't publish them. In particular the
/// Vietnamese indices have no 52-week band or one-year change, and report
/// matched volume/turnover instead.
class MarketOverview {
  const MarketOverview({
    required this.code,
    this.price,
    this.dayChange,
    this.dayChangePercent,
    this.refPrice,
    this.open,
    this.high,
    this.low,
    this.high52,
    this.low52,
    this.yearChangePercent,
    this.marketCap,
    this.volume24h,
    this.dayVolume,
    this.dayValue,
  });

  final MarketCode code;
  final double? price;
  final double? dayChange;
  final double? dayChangePercent;

  /// Previous close — what the day change is measured against.
  final double? refPrice;

  final double? open;
  final double? high;
  final double? low;
  final double? high52;
  final double? low52;
  final double? yearChangePercent;

  /// Crypto only.
  final double? marketCap;
  final double? volume24h;

  /// Vietnamese indices only: matched volume (shares) and turnover (VND).
  final double? dayVolume;
  final double? dayValue;

  static double? _num(dynamic value) => (value as num?)?.toDouble();

  static MarketOverview? fromJson(Map<String, dynamic> json) {
    final code = MarketCode.from(json['c'] as String?);
    if (code == null) return null;
    return MarketOverview(
      code: code,
      price: _num(json['p']),
      dayChange: _num(json['dc']),
      dayChangePercent: _num(json['dcp']),
      refPrice: _num(json['rp']),
      open: _num(json['op']),
      high: _num(json['hp']),
      low: _num(json['lp']),
      high52: _num(json['hw52p']),
      low52: _num(json['lw52p']),
      yearChangePercent: _num(json['y1cp']),
      marketCap: _num(json['mc']),
      volume24h: _num(json['v24h']),
      dayVolume: _num(json['dv']),
      dayValue: _num(json['dve']),
    );
  }
}
