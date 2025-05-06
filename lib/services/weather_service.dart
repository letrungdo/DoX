import 'dart:async';

import 'package:dio/dio.dart';
import 'package:do_x/model/weather_data.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';

class WeatherService {
  final dio = DioClient.dio;

  Future<Result<WeatherData>> getCurrentWeather({
    required double? latitude, //
    required double? longitude,
    required String timezone,
    CancelToken? cancelToken,
  }) async {
    return Result.guardFuture(() async {
      final response = await dio.get(
        "https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=is_day,weather_code,temperature_2m,cloud_cover&timezone=$timezone&forecast_days=1",
        cancelToken: cancelToken,
      );
      return WeatherData.fromJson(response.data);
    });
  }
}
