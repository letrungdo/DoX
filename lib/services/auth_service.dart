import 'dart:async';

import 'package:dio/dio.dart';
import 'package:do_x/constants/env.dart';
import 'package:do_x/model/response/auth_response.dart';
import 'package:do_x/model/response/user_model.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/store/app_data.dart';

class AuthService {
  final dio = DioClient.create();

  final authHeader = {
    'X-Ios-Bundle-Identifier': 'com.locket.Locket', //
  };

  Future<Result<UserModel>> login({
    required String email, //
    required String password,
  }) async {
    return Result.guardFuture<UserModel>(() async {
      final response = await dio.post(
        "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=${Envs.locketApiKey.iOS}",
        options: Options(headers: authHeader),
        data: {
          "email": email, //
          "password": password,
          "clientType": "CLIENT_TYPE_IOS",
          "returnSecureToken": true,
        },
      );
      return UserModel.fromJson(response.data);
    });
  }

  Future<Result<AuthResponse>> refreshToken({CancelToken? cancelToken}) async {
    return Result.guardFuture<AuthResponse>(() async {
      final response = await dio.post(
        "https://securetoken.googleapis.com/v1/token?key=${Envs.locketApiKey.iOS}",
        options: Options(headers: authHeader),
        data: {
          "grant_type": "refresh_token", //
          "refresh_token": appData.user?.refreshToken,
        },
        cancelToken: cancelToken,
      );
      final result = AuthResponse.fromJson(response.data);
      appData.setUser(
        appData.user?.copyWith(
          idToken: result.idToken,
          refreshToken: result.refreshToken, //
          expiresIn: result.expiresIn,
        ),
      );
      return result;
    });
  }

  Future<void> logout() async {
    appData.clearSession();
  }
}
