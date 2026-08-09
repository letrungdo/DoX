import 'package:collection/collection.dart';

/// How the picker groups the catalogue. The API keeps one overview endpoint per
/// group (`/api/{commodities,cryptos,indexes,indices}/v2/overview`), and every
/// code below was verified against the bars endpoint the charts read.
enum MarketGroup { commodity, crypto, vnIndex, worldIndex, usStock }

enum MarketCode {
  // Commodities — /api/commodities/v2/overview
  xauUSD("XAUUSD", "Gold/USD", MarketGroup.commodity),
  xagUSD("XAGUSD", "Silver/USD", MarketGroup.commodity),
  usOil("USOIL", "WTI Oil", MarketGroup.commodity),
  brent("BRENT", "Brent Oil", MarketGroup.commodity),
  naturalGas("NATURALGAS", "Natural Gas", MarketGroup.commodity),
  sugar("SUGAR", "Sugar", MarketGroup.commodity),
  rice("RICE", "Rice", MarketGroup.commodity),

  // Crypto — /api/cryptos/v2/overview
  btcUSDT("BTCUSDT", "BTC/USDT", MarketGroup.crypto),
  ethUSDT("ETHUSDT", "ETH/USDT", MarketGroup.crypto),
  bnbUSDT("BNBUSDT", "BNB/USDT", MarketGroup.crypto),
  solUSDT("SOLUSDT", "SOL/USDT", MarketGroup.crypto),
  xrpUSDT("XRPUSDT", "XRP/USDT", MarketGroup.crypto),
  adaUSDT("ADAUSDT", "ADA/USDT", MarketGroup.crypto),
  dogeUSDT("DOGEUSDT", "DOGE/USDT", MarketGroup.crypto),
  trxUSDT("TRXUSDT", "TRX/USDT", MarketGroup.crypto),
  dotUSDT("DOTUSDT", "DOT/USDT", MarketGroup.crypto),
  ltcUSDT("LTCUSDT", "LTC/USDT", MarketGroup.crypto),
  linkUSDT("LINKUSDT", "LINK/USDT", MarketGroup.crypto),
  etcUSDT("ETCUSDT", "ETC/USDT", MarketGroup.crypto),
  filUSDT("FILUSDT", "FIL/USDT", MarketGroup.crypto),
  icpUSDT("ICPUSDT", "ICP/USDT", MarketGroup.crypto),

  // Vietnamese indices — /api/indexes/v2/overview
  vnIndex("VNIndex", "VNIndex", MarketGroup.vnIndex),
  vn30("VN30", "VN30", MarketGroup.vnIndex),
  hnxIndex("HNXIndex", "HNXIndex", MarketGroup.vnIndex),
  hnx30("HNX30", "HNX30", MarketGroup.vnIndex),
  hnxUpcomIndex("HNXUpcomIndex", "UPCOM", MarketGroup.vnIndex),

  // World indices — /api/indices/v2/overview
  us30("US30", "Dow Jones", MarketGroup.worldIndex),
  sp500("SP500", "S&P 500", MarketGroup.worldIndex),
  nasdaq("COMP", "NASDAQ", MarketGroup.worldIndex),
  jpn225("JPN225", "Nikkei 225", MarketGroup.worldIndex),
  kospi("KOSPI", "KOSPI", MarketGroup.worldIndex),
  uk100("UK100", "FTSE 100", MarketGroup.worldIndex),
  hkg33("HKG33", "Hang Seng", MarketGroup.worldIndex),

  // US stocks — same endpoint as the world indices
  apple("APPLE", "Apple", MarketGroup.usStock),
  microsoft("MICROSOFT", "Microsoft", MarketGroup.usStock),
  nvidia("NVIDIA", "NVIDIA", MarketGroup.usStock),
  tesla("TESLA", "Tesla", MarketGroup.usStock),
  meta("META", "Meta", MarketGroup.usStock);

  const MarketCode(this.code, this.name, this.group);

  final String code;

  /// Display label. Deliberately not translated: tickers and index names are
  /// written the same way in both of the app's languages.
  final String name;

  final MarketGroup group;

  /// What a fresh install shows, before the user picks their own set.
  static const defaults = [xauUSD, xagUSD, btcUSDT, bnbUSDT, ethUSDT, vnIndex];

  static MarketCode? from(String? code) {
    return MarketCode.values.firstWhereOrNull((e) => code == e.code);
  }

  String getName() => name;
}
