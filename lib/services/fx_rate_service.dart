import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/model/fx/gold_model.dart';
import 'package:do_x/model/response/market_response.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/services/supabase_service.dart';

class FxRateService {
  final dio = DioClient.create();

  Future<Result<List<MarketCodeInfo>>> getMarket({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final codes = MarketCode.values.map((e) => e.code).join(",");
      // Bars come back newest-first (DESC); we sort ascending client-side.
      // 1m timeframe keeps the sparkline responsive and matches the real-time
      // push cadence (see CoinChartMixin._bucketMs). Only recent points are
      // charted, so keep countBack small.
      final response = await dio.get(
        'https://api.market-data.example/api/tradingview/v2/bars/many/all/get?timeframe=1m&code=$codes&countBack=60'.withProxy(),
        cancelToken: cancelToken,
      );
      final data = MarketResponse.fromJson(response.data);

      return data.data.codes;
    });
  }

  /// Fetches the bars for a single [code] at the given [timeframe]
  /// (e.g. `1m`, `5m`, `1h`, `1d`). Bars come back newest-first (DESC);
  /// callers should sort ascending before charting.
  Future<Result<List<Bar>>> getBars({
    required MarketCode code,
    required String timeframe,
    int countBack = 100,
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        'https://api.market-data.example/api/tradingview/v2/bars/many/all/get?timeframe=$timeframe&code=${code.code}&countBack=$countBack'.withProxy(),
        cancelToken: cancelToken,
      );
      final data = MarketResponse.fromJson(response.data);
      final info = data.data.codes.firstWhereOrNull((c) => c.code == code);
      return info?.bars ?? [];
    });
  }

  /// Reads every JPY→VND rate from Supabase in a single query, keyed by code
  /// (e.g. `google_jpy_vnd`, `smile_jpy_vnd`, `moneygram_jpy_vnd`, `dcom_jpy_vnd`).
  ///
  /// The table is refreshed every minute by a cron + edge function, so the app
  /// only reads it — fast, and free of the upstream sources' cold-start latency.
  Future<Result<Map<String, double>>> getFxRates({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final rows = await supabase.from('fx_rates').select('code, rate');

      return {
        for (final row in rows) row['code'] as String: (row['rate'] as num).toDouble(),
      };
    });
  }

  /// Symbols dropped from the API response before they reach the UI.
  /// `SJCBTMCHN` (vàng miếng SJC - Bảo Tín Minh Châu Hà Nội) duplicates the
  /// SJC Hồ Chí Minh row at nearly the same price.
  static const _ignoredGoldCodes = {'SJCBTMCHN'};

  Future<Result<List<GoldSymbol>?>> getGoldPrice({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        'https://api.market-data.example/api/domesticgold/symbols'.withProxy(), //
        cancelToken: cancelToken,
      );
      final data = GoldResponse.fromJson(response.data);

      return data.data?.symbols
          ?.where((e) => !_ignoredGoldCodes.contains(e.code))
          .toList();
    });
  }

}
