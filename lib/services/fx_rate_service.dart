import 'dart:async';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/constants/env.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/model/fx/gold_model.dart';
import 'package:do_x/model/market/market_overview.dart';
import 'package:do_x/model/news/gold_news.dart';
import 'package:do_x/model/response/market_response.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/services/supabase_service.dart';

class FxRateService {
  final dio = DioClient.create();

  /// Bars for the markets the user picked. Asking only for those keeps the
  /// response small — the catalogue is far larger than any one card shows.
  Future<Result<List<MarketCodeInfo>>> getMarket({
    required List<MarketCode> markets,
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      if (markets.isEmpty) return const <MarketCodeInfo>[];
      final codes = markets.map((e) => e.code).join(",");
      // Bars come back newest-first (DESC); we sort ascending client-side.
      // 1m timeframe keeps the sparkline responsive and matches the real-time
      // push cadence (see CoinChartMixin._bucketMs). Only recent points are
      // charted, so keep countBack small.
      final response = await dio.get(
        '${Envs.marketApiUrl}/api/tradingview/v2/bars/many/all/get?timeframe=1m&code=$codes&countBack=60'
            .withProxy(),
        cancelToken: cancelToken,
      );
      final data = MarketResponse.fromJson(response.data);

      return data.data.codes;
    });
  }

  /// The overview endpoint each group is published on, and the key its rows sit
  /// under. The world indices and the US stocks share one endpoint.
  static const _overviewPaths = {
    MarketGroup.commodity: ('commodities', 'commodities'),
    MarketGroup.crypto: ('cryptos', 'cryptos'),
    MarketGroup.vnIndex: ('indexes', 'indexs'),
    MarketGroup.worldIndex: ('indices', 'indices'),
    MarketGroup.usStock: ('indices', 'indices'),
  };

  /// Live snapshots for [markets] — day change, session range, 52-week band and
  /// the per-group extras the bars endpoint doesn't carry.
  ///
  /// Only the endpoints the selection actually needs are called, in parallel,
  /// and a group that fails is simply missing from the result: the card falls
  /// back to what it can compute from the bars rather than showing an error.
  Future<Result<Map<MarketCode, MarketOverview>>> getMarketOverviews({
    required List<MarketCode> markets,
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      final paths = {
        for (final market in markets) _overviewPaths[market.group]!,
      };
      final responses = await Future.wait(
        paths.map((entry) async {
          try {
            final response = await dio.get(
              '${Envs.marketApiUrl}/api/${entry.$1}/v2/overview'.withProxy(),
              cancelToken: cancelToken,
            );
            final rows = response.data['data']?[entry.$2];
            return rows is List ? rows : const [];
          } on DioException catch (_) {
            return const [];
          }
        }),
      );

      final wanted = markets.toSet();
      return {
        for (final rows in responses)
          for (final row in rows)
            if (row is Map<String, dynamic>)
              if (MarketOverview.fromJson(row) case final overview?)
                if (wanted.contains(overview.code)) overview.code: overview,
      };
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
        '${Envs.marketApiUrl}/api/tradingview/v2/bars/many/all/get?timeframe=$timeframe&code=${code.code}&countBack=$countBack'
            .withProxy(),
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
        for (final row in rows)
          row['code'] as String: (row['rate'] as num).toDouble(),
      };
    });
  }

  /// The gold-news digest, rebuilt three times a day by the
  /// `summarize-gold-news` edge function (RSS from several outlets, summarised
  /// by Gemini). The table holds a single row that each run overwrites.
  Future<Result<GoldNews?>> getGoldNews({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final row = await supabase.from('gold_news').select().maybeSingle();

      return row == null ? null : GoldNews.fromJson(row);
    });
  }

  /// Symbols dropped from the API response before they reach the UI.
  /// `SJCBTMCHN` (vàng miếng SJC - Bảo Tín Minh Châu Hà Nội) duplicates the
  /// SJC Hồ Chí Minh row at nearly the same price.
  static const _ignoredGoldCodes = {'SJCBTMCHN'};

  Future<Result<List<GoldSymbol>?>> getGoldPrice({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        '${Envs.marketApiUrl}/api/domesticgold/symbols'.withProxy(), //
        cancelToken: cancelToken,
      );
      final data = GoldResponse.fromJson(response.data);

      return data.data?.symbols
          ?.where((e) => !_ignoredGoldCodes.contains(e.code))
          .toList();
    });
  }
}
