import 'dart:async';

import 'package:dio/dio.dart';
import 'package:do_x/model/finpath/gold_model.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';

class FinpathService {
  final dio = DioClient.create();

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
}
