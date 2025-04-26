import 'package:dio/dio.dart';
import 'package:do_ai/constants/app_const.dart';
import 'package:do_ai/repository/client/http_client_adapter.dart';
import 'package:do_ai/repository/client/interceptor.dart';

final _baseOptions = BaseOptions(
  connectTimeout: const Duration(seconds: AppConst.apiRequestTimeout),
  receiveTimeout: const Duration(seconds: AppConst.apiRequestTimeout),
  sendTimeout: const Duration(seconds: AppConst.apiRequestTimeout),
);

class DioClient {
  static Dio create([String? baseUrl]) {
    final dio = Dio(
      _baseOptions.copyWith(
        baseUrl: baseUrl, //
      ),
    );
    dio.interceptors.add(BaseInterceptor());
    dio.httpClientAdapter = httpClientAdapter;
    return dio;
  }
}
