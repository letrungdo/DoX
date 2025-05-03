import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:do_x/constants/date_time.dart';
import 'package:do_x/constants/enum/overlay_type.dart';
import 'package:do_x/extensions/date_extensions.dart';
import 'package:do_x/model/response/user_info_response.dart';
import 'package:do_x/model/response/user_model.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/cupertino.dart';

class LocketService {
  final dio = DioClient.createLocket();

  Future<Result<UserInfoData>> fetchUserV2({required UserModel? user, CancelToken? cancelToken}) {
    return Result.guardFuture<UserInfoData>(() async {
      final response = await dio.post(
        '/fetchUserV2', //
        data: {
          "data": {"user_uid": user!.localId},
        },
        cancelToken: cancelToken,
      );
      debugPrint(response.data.toString());
      final userInfo = UserInfoResponse.fromJson(response.data).result.data;
      secureStorage.saveAccount(
        appData.user?.copyWith(
          profilePicture: userInfo.profilePictureUrl, //
        ),
      );
      return userInfo;
    });
  }

  Future<Result> postImage(
    String thumbnailUrl, {
    String? caption, //
    OverlayType? overlayType,
    required UserModel user,
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      // final analytics = {"platform": "ios"};
      final overlayName = (overlayType ?? OverlayType.standard).name;
      final body = {
        "data": {
          "thumbnail_url": thumbnailUrl,
          "recipients": [],
          // "analytics": analytics,
          "sent_to_self_only": false,
          "sent_to_all": true,
          "caption": caption,
          "overlays": [
            {
              "data": {
                "background": {"material_blur": "ultra_thin", "colors": []},
                "text_color": "#FFFFFFE6",
                "type": overlayName,
                "max_lines": {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": "4"},
                "text": caption,
              },
              "alt_text": caption,
              "overlay_id": "caption:$overlayName",
              "overlay_type": "caption",
            },
          ],
          "update_streak_for_yyyymmdd": {
            // TODO:
            "value": DateTime.now().toStringFormat(DateTimeConst.yyyyMMdd),
            "@type": "type.googleapis.com/google.protobuf.Int64Value",
          },
        },
      };

      final response = await dio.post(
        '/postMomentV2', //
        data: body,
        cancelToken: cancelToken,
      );
      debugPrint(response.data.toString());
      return response.data;
    });
  }

  Future postVideo(String videoUrl, String thumbnailUrl, String caption) async {
    // final functions = FirebaseFunctions.instance;
    // final request = _videoDataJson(videoUrl: videoUrl, thumbUrl: thumbnailUrl, caption: caption);

    // try {
    //   final HttpsCallableResult<Map<String, dynamic>> result = await functions.httpsCallable(
    //     "https://api.locketcamera.com/postMomentV2", //
    //   )(request);
    //   logger.d(result.data.toString());
    //   return true;
    // } on FirebaseFunctionsException catch (e) {
    //   logger.e(e.toString());
    //   return false;
    // }
  }

  Future<Result<bool>> postVideo2(String videoUrl, String thumbnailUrl, String caption, String token) async {
    final json = _videoDataJson(videoUrl: videoUrl, thumbUrl: thumbnailUrl, caption: caption);

    final url = "https://api.locketcamera.com/postMomentV2";

    return Result.guardFuture<bool>(() async {
      final response = await dio.post(url, data: jsonEncode(json));
      final responseJSON = jsonDecode(response.data);
      logger.d(responseJSON);
      return true;
    });
  }

  Map<String, dynamic> _videoDataJson({
    required String videoUrl, //
    required String thumbUrl,
    required String caption,
  }) {
    return {
      "video_url": videoUrl, //
      "thumbnail_url": thumbUrl,
      "caption": caption,
    };
  }
}
