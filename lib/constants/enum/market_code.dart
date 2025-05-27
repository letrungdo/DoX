import 'package:collection/collection.dart';

enum MarketCode {
  xauUSD("XAUUSD"),
  xagUSD("XAGUSD"),
  btcUSDT("BTCUSDT"),
  ethUSDT("ETHUSDT"),
  vnIndex("VNIndex");

  const MarketCode(this.code);
  final String code;

  static MarketCode? from(String? code) {
    return MarketCode.values.firstWhereOrNull((e) => code == e.code);
  }

  String getName() {
    return switch (this) {
      xauUSD => "Gold / USD",
      xagUSD => "Sliver / USD",
      btcUSDT => "BTC / USDT",
      ethUSDT => "ETH / USDT",
      vnIndex => "VNIndex",
    };
  }
}
