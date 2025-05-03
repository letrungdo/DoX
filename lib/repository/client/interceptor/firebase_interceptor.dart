import 'dart:io';

import 'package:dio/dio.dart';
import 'package:do_x/repository/client/dio_exception.dart';
import 'package:do_x/repository/client/interceptor/interceptor.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/utils/firebase.dart';

class FirebaseInterceptor extends BaseInterceptor {
  @override
  ClientType get clientType => ClientType.firebase;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    await FirebaseUtil.refreshTokenIfNeed();
    options.headers.addAll({
      'X-Ios-Bundle-Identifier': 'com.locket.Locket', //
      HttpHeaders.authorizationHeader: "Firebase ${appData.user?.idToken}",
    });
    super.onRequest(options, handler);
  }
}
