import 'dart:async';

import 'package:dio/dio.dart';
import 'package:do_x/constants/date_time.dart';
import 'package:do_x/constants/enum/overlay_type.dart';
import 'package:do_x/extensions/color_extensions.dart';
import 'package:do_x/extensions/date_extensions.dart';
import 'package:do_x/extensions/double_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/model/response/user_info_response.dart';
import 'package:do_x/model/response/user_model.dart';
import 'package:do_x/model/weather_data.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/store/app_data.dart';
import 'package:do_x/view_model/locket/weather.dart';
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
    required OverlayType overlayType,
    required String? caption, //
    required String? reviewCaption,
    required double? reviewRating,
    required DateTime? currentTime,
    required CurrentWeather? weather,
    required String? locationName,
    required Color? textColor,
    required List<Color?>? bgColors,
  }) {
    final overlayName = overlayType.name;
    final colors = bgColors?.where((e) => e != null).map(((e) => e.toHexString(includeAlpha: false))).toList() ?? [];

    switch (overlayType) {
      case OverlayType.standard:
        final text = caption?.trim();
        if (text.isNullOrEmpty) return null;
        return [
          {
            "data": {
              "background": {"material_blur": "ultra_thin", "colors": colors},
              "text_color": textColor.toHexString(),
              // "text_color": "#FFFFFFE6",
              "type": overlayName,
              "max_lines": {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": "4"},
              "text": text,
            },
            "alt_text": text,
            "overlay_id": "caption:$overlayName",
            "overlay_type": "caption",
          },
        ];
      case OverlayType.review:
        if (reviewRating == 0 && reviewCaption.isNullOrEmpty) return null;
        final text = "★$reviewRating - “${reviewCaption?.trim()}”";
        return [
          {
            "data": {
              "background": {"material_blur": "regular", "colors": []},
              "payload": {
                "comment": reviewCaption,
                "rating": {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": reviewRating},
              },
              "text_color": "#FFFFFFE6",
              "type": overlayName,
              "max_lines": {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": "4"},
              "text": text,
            },
            "alt_text": text,
            "overlay_id": "caption:$overlayName",
            "overlay_type": "caption",
          },
        ];
      // case OverlayType.music:
      case OverlayType.location:
        final text = locationName?.trim();
        if (text.isNullOrEmpty) return null;
        return [
          {
            "data": {
              "max_lines": {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": "1"},
              "payload": {},
              "text": text,
              "background": {"material_blur": "regular", "colors": []},
              "type": overlayName,
              "icon": {"color": "#24B0FF", "data": "location.fill", "type": "sf_symbol"},
              "text_color": "#FFFFFFE6",
            },
            "alt_text": text,
            "overlay_id": "caption:$overlayName",
            "overlay_type": "caption",
          },
        ];
      case OverlayType.weather:
        if (weather == null) return null;
        final text = weather.temperatureText;
        final data = wmoWeatherInfos[weather.weatherCode];

        return [
          {
            "data": {
              "max_lines": {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": "1"},
              "payload": {
                "temperature": weather.temperature2m.celsiusToFahrenheit(),
                "wk_condition": data?.description,
                "is_daylight": weather.isDaylight,
                "cloud_cover": {
                  "value": weather.cloudCover, //
                  "@type": "type.googleapis.com/google.protobuf.Int64Value",
                },
              },
              "text": text,
              "background": {"colors": []},
              "type": overlayName,
              "icon": {"color": "#FFFFFF", "data": data.symbolName(weather.isDaylight), "type": "sf_symbol"},
              "text_color": "#FFFFFFE6",
            },
            "alt_text": text,
            "overlay_id": "caption:$overlayName",
            "overlay_type": "caption",
          },
        ];
      case OverlayType.time:
        if (currentTime == null) return null;
        final text = currentTime.toStringFormat(DateTimeConst.HHmma);
        final date = currentTime.millisecondsSinceEpoch / 1000;
        return [
          {
            "data": {
              "max_lines": {"@type": "type.googleapis.com/google.protobuf.Int64Value", "value": "1"},
              "payload": {"date": date},
              "text": text,
              "background": {"material_blur": "regular", "colors": []},
              "type": overlayName,
              "icon": {"type": "sf_symbol", "color": "#FFFFFFCC", "data": "clock.fill"},
              "text_color": "#FFFFFFE6",
            },
            "alt_text": text,
            "overlay_id": "caption:$overlayName",
            "overlay_type": "caption",
          },
        ];
    }
  }

  Future<Result> postImage(
    String? thumbnailUrl, {
    required UserModel user,
    CancelToken? cancelToken,
    required OverlayType overlayType,
    required String? caption,
    required String? reviewCaption,
    required double? reviewRating,
    required CurrentWeather? weather,
    required DateTime? currentTime,
    required String? locationName,
    required Color? textColor,
    required List<Color?>? bgColors,
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
          "update_streak_for_yyyymmdd": {
            "value": DateTime.now().toStringFormat(DateTimeConst.yyyyMMdd),
            "@type": "type.googleapis.com/google.protobuf.Int64Value",
          },
        },
      };
      final overlays = _createOverlay(
        caption: caption, //
        reviewCaption: reviewCaption,
        reviewRating: reviewRating,
        overlayType: overlayType,
        currentTime: currentTime,
        weather: weather,
        locationName: locationName,
        textColor: textColor,
        bgColors: bgColors,
      );
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
    required UserModel user,
    CancelToken? cancelToken,
    required OverlayType overlayType,
    required String? thumbnailUrl,
    required String? videoUrl,
    required String? caption, //
    required String? reviewCaption,
    required double? reviewRating,
    required CurrentWeather? weather,
    required DateTime? currentTime,
    required String? locationName,
    required Color? textColor,
    required List<Color?>? bgColors,
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
      final overlays = _createOverlay(
        caption: caption, //
        reviewCaption: reviewCaption,
        reviewRating: reviewRating,
        overlayType: overlayType,
        currentTime: currentTime,
        weather: weather,
        locationName: locationName,
        textColor: textColor,
        bgColors: bgColors,
      );
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
