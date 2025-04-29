import 'dart:io';

import 'package:dio/dio.dart';
import 'package:do_x/repository/client/interceptor/interceptor.dart';
import 'package:do_x/store/app_data.dart';

class LocketInterceptor extends BaseInterceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers.addAll({
      HttpHeaders.contentTypeHeader: "application/json", //
      // HttpHeaders.acceptEncodingHeader: "gzip",
      HttpHeaders.authorizationHeader: "Bearer ${appData.user?.idToken}",
    });
    super.onRequest(options, handler);
  }
}
