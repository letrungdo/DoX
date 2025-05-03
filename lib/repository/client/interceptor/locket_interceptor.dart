import 'dart:io';

import 'package:dio/dio.dart';
import 'package:do_x/constants/apis.dart';
import 'package:do_x/repository/client/dio_exception.dart';
import 'package:do_x/repository/client/interceptor/interceptor.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/utils/firebase.dart';

class LocketInterceptor extends BaseInterceptor {
  @override
  ClientType get clientType => ClientType.locket;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    await FirebaseUtil.refreshTokenIfNeed();

    options.headers.addAll({
      HttpHeaders.contentTypeHeader: "application/json", //
      HttpHeaders.authorizationHeader: "Bearer ${appData.user?.idToken}",
    });
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final body = response.data;
    Map<String, dynamic>? errorResponse;
    if (response.statusCode == HttpStatus.ok && body is Map<String, dynamic>) {
      // HTTP status code of header and status, result of API response
      final result = body[ApiParamNames.result];
      final errors = result?[ApiParamNames.errors];
      if (errors == null) {
        // Success
        super.onResponse(response, handler);
        return;
      }
      errorResponse = body;
    }
    handler.reject(
      DioExceptionExt.badResponse(
        error: FXDioError(
          clientType: clientType,
          response: Response(
            data: errorResponse ?? response.data,
            requestOptions: response.requestOptions,
            statusCode: response.statusCode,
          ),
        ),
      ),
    );
  }
}
