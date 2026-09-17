import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/model/crypto/crypto_symbol.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';

/// Binance's public market data: which coins trade against USDT, what they
/// cost, and what they are called.
///
/// Everything here is unauthenticated. Prices come from the documented spot
/// API; the names and logos come from the directory the Binance site itself
/// reads, which is the only public place they are published.
class BinanceService {
  final _dio = DioClient.create();

  static const _tickerUrl = 'https://api.binance.com/api/v3/ticker/price';
  static const _assetUrl =
      'https://www.binance.com/bapi/asset/v2/public/asset/asset/get-all-asset';

  /// Every pair quoted in USDT — the only quote currency this app records in.
  static const _quote = 'USDT';

  /// The coins most people are looking for, kept at the top of the list so the
  /// picker opens on something useful rather than on whatever sorts first
  /// alphabetically.
  static const _majors = [
    _quote,
    'BTC',
    'ETH',
    'BNB',
    'SOL',
    'XRP',
    'ADA',
    'DOGE',
  ];

  /// Names and logos, keyed by the coin's own code ("BTC"). Around a megabyte
  /// and it changes when a coin is listed, so the first answer is kept for the
  /// session: a picker reopened should not pay for it twice.
  static Map<String, CryptoAsset>? _assets;

  /// The whole USDT catalogue, priced, for the picker.
  Future<Result<List<CryptoSymbol>>> getUsdtSymbols({
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      final results = await Future.wait([
        _fetchPrices(cancelToken: cancelToken),
        _fetchAssets(cancelToken: cancelToken),
      ]);
      final prices = results[0] as Map<String, double>;
      final assets = results[1] as Map<String, CryptoAsset>;

      final symbols = [
        for (final entry in prices.entries)
          if (entry.key.endsWith(_quote))
            () {
              final base = entry.key.substring(
                0,
                entry.key.length - _quote.length,
              );

              return CryptoSymbol(
                symbol: entry.key,
                base: base,
                name: assets[base]?.name,
                logo: assets[base]?.logo,
                price: entry.value,
              );
            }(),
      ];

      // USDT is held like any other coin, but there is no USDTUSDT pair for it
      // to arrive in — it is the thing every other pair is priced against. It
      // is worth one of itself, by definition.
      symbols.add(
        CryptoSymbol(
          symbol: _quote,
          base: _quote,
          name: assets[_quote]?.name,
          logo: assets[_quote]?.logo,
          price: 1,
        ),
      );

      symbols.sort((a, b) {
        final rankA = _majors.indexOf(a.base);
        final rankB = _majors.indexOf(b.base);
        if (rankA != rankB) {
          if (rankA < 0) return 1;
          if (rankB < 0) return -1;

          return rankA.compareTo(rankB);
        }

        return a.base.compareTo(b.base);
      });

      return symbols;
    });
  }

  /// The price of just the pairs held, which is all a refresh needs. Asking for
  /// them by name keeps the response a few hundred bytes instead of 150KB.
  Future<Result<Map<String, double>>> getPrices(
    List<String> symbols, {
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      if (symbols.isEmpty) return <String, double>{};

      final response = await _dio.get(
        '$_tickerUrl?symbols=${jsonEncode(symbols)}'.withProxy(),
        cancelToken: cancelToken,
      );

      return _pricesOf(response.data);
    });
  }

  /// Names and logos for the coins held, from the cached directory.
  Future<Map<String, CryptoAsset>> getAssets({CancelToken? cancelToken}) {
    return _fetchAssets(cancelToken: cancelToken);
  }

  Future<Map<String, double>> _fetchPrices({CancelToken? cancelToken}) async {
    final response = await _dio.get(
      _tickerUrl.withProxy(),
      cancelToken: cancelToken,
    );

    return _pricesOf(response.data);
  }

  /// Binance answers a single-symbol request with an object and a multi-symbol
  /// one with a list, so both shapes are read here rather than at each call.
  Map<String, double> _pricesOf(dynamic data) {
    final rows = data is List ? data : [data];

    return {
      for (final row in rows)
        if (row is Map && row['symbol'] is String)
          row['symbol'] as String: ?double.tryParse('${row['price']}'),
    };
  }

  Future<Map<String, CryptoAsset>> _fetchAssets({
    CancelToken? cancelToken,
  }) async {
    final cached = _assets;
    if (cached != null) return cached;

    try {
      final response = await _dio.get(
        _assetUrl.withProxy(),
        cancelToken: cancelToken,
      );
      final rows = (response.data?['data'] as List?) ?? const [];
      final assets = {
        for (final row in rows)
          if (row is Map && row['assetCode'] is String)
            row['assetCode'] as String: CryptoAsset(
              name: row['assetName'] as String?,
              logo: row['logoUrl'] as String?,
            ),
      };
      _assets = assets;

      return assets;
    } on DioException catch (_) {
      // A picker that lists every coin by its ticker is still usable; one that
      // refuses to open because the logos are missing is not.
      return const {};
    }
  }
}
