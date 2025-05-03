import 'package:dio/dio.dart';
import 'package:do_x/constants/app_const.dart';
import 'package:do_x/repository/client/http_client_adapter.dart';
import 'package:do_x/repository/client/interceptor/firebase_interceptor.dart';
import 'package:do_x/repository/client/interceptor/interceptor.dart';
import 'package:do_x/repository/client/interceptor/locket_interceptor.dart';
import 'package:flutter/foundation.dart';

final _baseOptions = BaseOptions(
  connectTimeout: const Duration(seconds: AppConst.apiRequestTimeout),
  receiveTimeout: const Duration(seconds: AppConst.apiRequestTimeout),
  sendTimeout: const Duration(seconds: AppConst.apiRequestTimeout),
);

class DioClient {
  static Dio create([String? baseUrl]) {
    final dio = Dio(_baseOptions.copyWith(baseUrl: baseUrl));
    dio.interceptors.add(BaseInterceptor());
    if (!kIsWeb) {
      dio.httpClientAdapter = httpClientAdapter;
    }
    return dio;
  }

  static final dio = DioClient.create();

  static Dio createLocket() {
    final dio = Dio(_baseOptions.copyWith(baseUrl: "https://api.locketcamera.com"));
    dio.interceptors.addAll([
      LocketInterceptor(), //
    ]);
    if (!kIsWeb) {
      dio.httpClientAdapter = httpClientAdapter;
    }
    return dio;
  }

  static Dio createFirebase() {
    final dio = Dio(_baseOptions);
    dio.interceptors.addAll([
      FirebaseInterceptor(), //
    ]);
    if (!kIsWeb) {
      dio.httpClientAdapter = httpClientAdapter;
    }
    return dio;
  }
}
