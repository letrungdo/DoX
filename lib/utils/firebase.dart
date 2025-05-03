import 'package:dio/dio.dart' show Options;
import 'package:do_x/constants/env.dart';
import 'package:do_x/model/response/auth_response.dart';
import 'package:do_x/model/response/user_model.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/store/app_data.dart';

class FirebaseUtil {
  const FirebaseUtil._();

  static const authHeader = {
    'X-Ios-Bundle-Identifier': 'com.locket.Locket', //
  };

  static Future<Result?> refreshTokenIfNeed() async {
    final expiryTime = appData.user?.expiryTime;
    if (expiryTime != null && expiryTime - 1000 > DateTime.now().millisecondsSinceEpoch) {
      // No need refresh token
      return null;
    }
    return Result.guardFuture<AuthResponse>(() async {
      final response = await DioClient.dio.post(
        "https://securetoken.googleapis.com/v1/token?key=${Envs.locketApiKey.iOS}",
        options: Options(headers: authHeader),
        data: {
          "grant_type": "refresh_token", //
          "refresh_token": appData.user?.refreshToken,
        },
      );
      final result = AuthResponse.fromJson(response.data);
      secureStorage.saveAccount(
        appData.user?.copyWith(
          idToken: result.idToken,
          refreshToken: result.refreshToken, //
          expiresIn: result.expiresIn,
        ),
      );
      return result;
    });
  }
}
