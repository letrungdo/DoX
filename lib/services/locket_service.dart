import 'dart:async';

import 'package:dio/dio.dart';
import 'package:do_x/constants/date_time.dart';
import 'package:do_x/constants/enum/overlay_type.dart';
import 'package:do_x/extensions/date_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/model/response/user_info_response.dart';
import 'package:do_x/model/response/user_model.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/store/app_data.dart';
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

  List<Map>? _createOverlay({
    OverlayType? overlayType,
    String? caption, //
  }) {
    if (caption.isNullOrEmpty) return null;
    final overlayName = (overlayType ?? OverlayType.standard).name;
    return [
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
    ];
  }

  Future<Result> postImage(
    String? thumbnailUrl, {
    String? caption, //
    OverlayType? overlayType,
    required UserModel user,
    CancelToken? cancelToken,
  }) {
    return Result.guardFuture(() async {
      if (thumbnailUrl == null) throw "thumbnail url invalid";
      // final analytics = {"platform": "ios"};
      final body = {
        "data": {
          "thumbnail_url": thumbnailUrl,
          "recipients": [],
          // "analytics": analytics,
          "sent_to_self_only": false,
          "sent_to_all": true,
          "caption": caption,
          "update_streak_for_yyyymmdd": {
            // TODO:
            "value": DateTime.now().toStringFormat(DateTimeConst.yyyyMMdd),
            "@type": "type.googleapis.com/google.protobuf.Int64Value",
          },
        },
      };
      final overlays = _createOverlay(caption: caption, overlayType: overlayType);
      if (overlays != null) {
        body["data"]!["overlays"] = overlays;
      }
      final response = await dio.post(
        '/postMomentV2', //
        data: body,
        cancelToken: cancelToken,
      );
      debugPrint(response.data.toString());
      return response.data;
    });
  }

  Future<Result> postVideo({
    required String? thumbnailUrl,
    required String? videoUrl,
    String? caption, //
    OverlayType? overlayType,
    required UserModel user,
    CancelToken? cancelToken,
  }) async {
    return Result.guardFuture(() async {
      if (thumbnailUrl == null) throw "thumbnail url invalid";
      if (videoUrl == null) throw "video url invalid";

      final body = {
        "data": {
          "thumbnail_url": thumbnailUrl, //
          "video_url": videoUrl,
          "md5": videoUrl.toMd5(),
          "recipients": [],
          "sent_to_all": true,
        },
      };
      final overlays = _createOverlay(caption: caption, overlayType: overlayType);
      if (overlays != null) {
        body["data"]!["overlays"] = overlays;
      }
      final response = await dio.post(
        "/postMomentV2", //
        data: body,
        cancelToken: cancelToken,
      );
      debugPrint(response.data.toString());
      return response.data;
    });
  }
}
