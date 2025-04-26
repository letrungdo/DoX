import 'dart:io';

import 'package:dio/dio.dart';
import 'package:do_ai/utils/logger.dart';
import 'package:flutter/material.dart';

class BaseInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    debugPrint("""------------------------------------------------------
                1. REQUEST [${options.method}] => URL: ${options.path}
                ${options.data}
              """);

    options.headers.addAll({HttpHeaders.contentTypeHeader: "application/json", HttpHeaders.acceptEncodingHeader: "gzip"});
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint("""2. RESPONSE [${response.requestOptions.method}:${response.statusCode}] => URL: ${response.requestOptions.path}
                ------------------------------------------------------
              """);
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final errRes = err.response;

    logger.e('ERROR[${err.response?.statusCode}] => URL: ${err.requestOptions.uri}; res: $errRes');

    super.onError(err, handler);
  }
}
