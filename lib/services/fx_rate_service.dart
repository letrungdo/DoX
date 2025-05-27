import 'dart:async';

import 'package:dio/dio.dart';
import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/constants/env.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/model/fx/gold_model.dart';
import 'package:do_x/model/fx/smile_model.dart';
import 'package:do_x/model/response/market_response.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' show parse; // Để parse HTML

class FxRateService {
  final dio = DioClient.create();

  Future<Result<List<MarketCodeInfo>>> getMarket({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final codes = MarketCode.values.map((e) => e.code).join(",");
      final response = await dio.get(
        'https://api.finpath.vn/api/tradingview/v2/bars/many/all/get?timeframe=5m&code=$codes&countBack=200', //
        cancelToken: cancelToken,
      );
      final data = MarketResponse.fromJson(response.data);

      return data.data.codes;
    });
  }

  Future<Result<double?>> getGoogleJpyVnd({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        'https://script.google.com/macros/s/${Envs.googleSheetKey}/exec'.withProxy(), //
        cancelToken: cancelToken,
      );
      final data = response.data as Map<String, dynamic>;

      return data["google_jpy_vnd"] as double;
    });
  }

  Future<Result<List<GoldSymbol>?>> getGoldPrice({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        'https://api.finpath.vn/api/domesticgold/symbols', //
        cancelToken: cancelToken,
      );
      final data = GoldResponse.fromJson(response.data);

      return data.data?.symbols;
    });
  }

  Future<Result<Map<String, CurrencyRate>>> getSmileRate({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        'https://ewm.digitalwalletcorp.com/EWA/WalletEx/ExchangeRate?TenantID=1&RegionCode=JP&CurrencyCode=JPY'.withProxy(), //
        cancelToken: cancelToken,
      );
      final data = ExchangeData.fromJson(response.data);

      return data.rates.allAllAll.currency;
    });
  }

  Future<Result<double?>> getMoneyGramRate({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        'https://ewm.digitalwalletcorp.com/EWA/DP/Tenant/1/Calculation?TenantID=1&DPType=15&ToCountry=VNM&RemitAmount=1000&BeneficiaryCurrency=VND&PointForFee=0&sendAmount=1000&sendCurrency=JPY&deliveryOption=BANK_DEPOSIT&RemittenceMethod=1&BankCode=970436&BankName=VIETCOMBANK%20-%20JOINT%20STOCK%20COMMERCIAL%20BANK%20FOR%20FOREIGN%20TRADE%20OF%20VIETNAM&ReceiveAgentID=73247188&RegionCode=JP&FromCurrency=JPY'
            .withProxy(), //
        cancelToken: cancelToken,
      );
      final data = response.data as Map<String, dynamic>;

      return data["Rate"];
    });
  }

  Future<Result<double?>> getDcomRate({CancelToken? cancelToken}) {
    return Result.guardFuture(() async {
      final response = await dio.get(
        kIsWeb ? 'https://app.xn--t-lia.vn/api/fx-rate/dcom' : "https://sendmoney.co.jp/en/fx-rate", //
        cancelToken: cancelToken,
      );
      if (kIsWeb) {
        final data = response.data as Map<String, dynamic>;
        return (data["vnd"] as num).toDouble();
      }
      final data = _parseExchangeRatesFromHtml(response.data);

      return data["vnd"].toDouble();
    });
  }
}

Map<String, String> _parseExchangeRatesFromHtml(String htmlContent) {
  final Map<String, String> rates = {};
  final document = parse(htmlContent);

  final rows = document.querySelectorAll('table.country-table tbody tr');

  for (final row in rows) {
    final columns = row.querySelectorAll('td');

    if (columns.length == 3) {
      final currencyCellText = columns[0].text.trim();
      final rateCellText = columns[1].text.trim();

      final currencyCodeRegex = RegExp(r'\(([^)]+)\)');
      final currencyCodeMatch = currencyCodeRegex.firstMatch(currencyCellText);

      if (currencyCodeMatch != null && currencyCodeMatch.groupCount >= 1) {
        final currencyCode = currencyCodeMatch.group(1);

        if (currencyCode != null && currencyCode.isNotEmpty) {
          final rateParts = rateCellText.split(RegExp(r'\s+'));

          if (rateParts.length >= 2) {
            final rateValue = rateParts[1];
            rates[currencyCode.toLowerCase()] = rateValue;
          }
        }
      }
    }
  }
  return rates;
}
