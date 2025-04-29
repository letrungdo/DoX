import 'dart:async';
import 'dart:convert';

import 'package:do_x/constants/enum/overlay_type.dart';
import 'package:do_x/model/response/user_model.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/cupertino.dart';

class LocketService {
  final dio = DioClient.createLocket();

  Future<Result> postImage(
    String thumbnailUrl, {
    String? caption, //
    OverlayType? overlayType,
    required UserModel user,
  }) {
    return Result.guardFuture(() async {
      final overlayName = (overlayType ?? OverlayType.standard).name;
      final body = {
        "data": {
          "thumbnail_url": thumbnailUrl,
          "recipients": [],
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
        },
      };

      final response = await dio.post('https://api.locketcamera.com/postMomentV2', data: body);
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
