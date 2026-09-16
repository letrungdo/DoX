import 'dart:async';

import 'package:dio/dio.dart';
import 'package:do_x/constants/date_time.dart';
import 'package:do_x/constants/enum/overlay_type.dart';
import 'package:do_x/constants/overlay_style.dart';
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
import 'package:do_x/view_model/my_life/weather.dart';
import 'package:flutter/cupertino.dart';

class MyLifeService {
  final dio = DioClient.createMyLife();

  Future<Result<UserInfoData>> fetchUserV2({
    required UserModel? user,
    CancelToken? cancelToken,
  }) {
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
    final colors =
        bgColors
            ?.where((e) => e != null)
            .map(((e) => e.toHexString(includeAlpha: false)))
            .toList() ??
        [];

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
              "max_lines": {
                "@type": "type.googleapis.com/google.protobuf.Int64Value",
                "value": "4",
              },
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
                "rating": {
                  "@type": "type.googleapis.com/google.protobuf.Int64Value",
                  // The picker allows half stars, so this stays a double - the
                  // capture only ever shows whole ratings because that client
                  // rounds them.
                  "value": reviewRating,
                },
              },
              "text_color": OverlayStyle.text.toHexString(),
              "type": overlayName,
              // The capture came from a free account, where the review caption
              // is capped at a single line. Paid accounts get four.
              "max_lines": {
                "@type": "type.googleapis.com/google.protobuf.Int64Value",
                "value": "4",
              },
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
              "max_lines": {
                "@type": "type.googleapis.com/google.protobuf.Int64Value",
                "value": "1",
              },
              "payload": {},
              "text": text,
              "background": {"material_blur": "regular", "colors": []},
              "type": overlayName,
              "icon": {
                "color": OverlayStyle.locationIcon.toHexString(
                  includeAlpha: false,
                ),
                "data": "location.fill",
                "type": "sf_symbol",
              },
              "text_color": OverlayStyle.text.toHexString(),
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
              "max_lines": {
                "@type": "type.googleapis.com/google.protobuf.Int64Value",
                "value": "1",
              },
              "payload": {
                "temperature": weather.temperature2m.celsiusToFahrenheit(),
                "wk_condition": data?.description,
                "is_daylight": weather.isDaylight,
                // A plain fraction of the sky, not an Int64Value percentage.
                "cloud_cover": (weather.cloudCover ?? 0) / 100,
              },
              "text": text,
              // The weather badge is a gradient rather than a blurred surface,
              // so it carries colors and no material_blur. Which gradient goes
              // with which condition is the API client's own table, and this
              // app offers no way to pick one, so it posts none.
              "background": {"colors": []},
              "type": overlayName,
              "icon": {
                "color": OverlayStyle.weatherIcon.toHexString(
                  includeAlpha: false,
                ),
                "data": data.symbolName(weather.isDaylight),
                "type": "sf_symbol",
              },
              "text_color": OverlayStyle.weatherText.toHexString(
                includeAlpha: false,
              ),
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
              "max_lines": {
                "@type": "type.googleapis.com/google.protobuf.Int64Value",
                "value": "1",
              },
              "payload": {"date": date},
              "text": text,
              "background": {"material_blur": "regular", "colors": []},
              "type": overlayName,
              "icon": {
                "type": "sf_symbol",
                "color": OverlayStyle.timeIcon.toHexString(),
                "data": "clock.fill",
              },
              "text_color": OverlayStyle.text.toHexString(),
            },
            "alt_text": text,
            "overlay_id": "caption:$overlayName",
            "overlay_type": "caption",
          },
        ];
    }
  }

  /// A plain text overlay is also the moment's caption: the API stores it
  /// outside the overlay so clients that cannot draw the overlay still have
  /// something to show. Every other overlay type leaves the caption unset.
  void _addCaption(
    Map<String, Map> body, {
    required OverlayType overlayType,
    required String? caption,
  }) {
    if (overlayType != OverlayType.standard) return;
    final text = caption?.trim();
    if (text.isNullOrEmpty) return;
    body["data"]!["caption"] = text;
  }

  Future<Result> postImage(
    String? thumbnailUrl, {
    required String? md5,
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
      if (md5 == null) throw "thumbnail md5 invalid";
      // final analytics = {"platform": "ios"};
      final body = {
        "data": {
          "thumbnail_url": thumbnailUrl,
          "md5": md5,
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
      _addCaption(body, overlayType: overlayType, caption: caption);
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
    required String? md5,
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
      if (md5 == null) throw "video md5 invalid";

      final body = {
        "data": {
          "thumbnail_url": thumbnailUrl, //
          "video_url": videoUrl,
          "md5": md5,
          "recipients": [],
          "sent_to_self_only": false,
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
      _addCaption(body, overlayType: overlayType, caption: caption);
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
