import 'dart:async';

import 'package:dio/dio.dart';
import 'package:do_x/constants/env.dart';
import 'package:do_x/model/response/user_model.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/utils/firebase.dart';

class AuthService {
  final dio = DioClient.dio;

  Future<Result<UserModel>> login({
    required String email, //
    required String password,
  }) async {
    return Result.guardFuture<UserModel>(() async {
      final response = await dio.post(
        "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=${Envs.locketApiKey.iOS}",
        options: Options(headers: FirebaseUtil.authHeader),
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

  Future<void> logout() async {
    appData.clearSession();
  }
}
