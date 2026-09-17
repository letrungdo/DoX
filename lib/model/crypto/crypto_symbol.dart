/// One coin as Binance lists it against USDT.
///
/// The catalogue is assembled from two public endpoints: the ticker carries
/// every pair and its price, and the asset directory carries the name and the
/// logo. A coin the directory has not heard of still trades, so the name and
/// logo are optional and the pair itself is what a record stores.
class CryptoSymbol {
  const CryptoSymbol({
    required this.symbol,
    required this.base,
    this.name,
    this.price,
    this.logo,
  });

  /// The pair as Binance writes it, e.g. "BTCUSDT". This is what an asset
  /// record stores, so it must round-trip exactly.
  final String symbol;

  /// The coin on its own, e.g. "BTC" — what a person calls it.
  final String base;

  /// The full name, e.g. "Bitcoin".
  final String? name;

  /// The last traded price in USDT.
  final double? price;
  final String? logo;

  /// Everything a search should look through: people type "btc", "bitcoin" or
  /// the whole pair and expect the same row.
  String get searchIndex => '$base ${name ?? ''} $symbol'.toLowerCase();

  @override
  bool operator ==(Object other) =>
      other is CryptoSymbol && other.symbol == symbol;

  @override
  int get hashCode => symbol.hashCode;
}

/// What Binance's asset directory adds to a pair the ticker already carries.
class CryptoAsset {
  const CryptoAsset({this.name, this.logo});

  final String? name;
  final String? logo;
}
