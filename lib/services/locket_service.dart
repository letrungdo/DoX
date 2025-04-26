import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:do_ai/repository/client/dio_client.dart';
import 'package:do_ai/repository/client/error_handler.dart';
import 'package:do_ai/utils/logger.dart';
import 'package:firebase_storage/firebase_storage.dart';

class LocketService {
  final dio = DioClient.create();

  Future<String?> uploadImage({
    required Uint8List data, //
    required String userId,
  }) async {
    try {
      final Reference ref = FirebaseStorage.instance.ref().child(
        '/users/$userId/moments/thumbnails/${_generateName(type: FileType.image)}',
      );

      final UploadTask uploadTask = ref.putData(data);
      final TaskSnapshot snapshot = await uploadTask.whenComplete(() {});

      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      logger.e("Err: Failed to upload image ${e.toString()}");
      return null;
    }
  }

  Future<(String, String, bool)> uploadVideo({
    required File video, //
    required Uint8List thumbnail,
    required String userId,
  }) async {
    try {
      final String videoFileName = _generateName(type: FileType.video);
      final Reference videoRef = FirebaseStorage.instance
          .refFromURL("gs://locket-video")
          .child('/users/$userId/moments/videos/$videoFileName');

      final UploadTask videoUploadTask = videoRef.putFile(video);
      final TaskSnapshot videoSnapshot = await videoUploadTask.whenComplete(() {});
      final String videoUrl = await videoSnapshot.ref.getDownloadURL();

      final thumbnailUrl = await uploadImage(data: thumbnail, userId: userId);

      if (thumbnailUrl != null) {
        return (videoUrl, thumbnailUrl, true);
      } else {
        return ("", "", false);
      }
    } catch (e) {
      logger.e(e.toString());
      return ("", "", false);
    }
  }

  Future<bool> postImage(String thumbnailUrl, String caption) async {
    final functions = FirebaseFunctions.instance;
    final request = {"thumbnail_url": thumbnailUrl, "caption": caption};

    try {
      final result = await functions.httpsCallableFromUrl(
        "https://api.locketcamera.com/postMomentV2", //
      )(request);
      logger.d(result.data.toString());
      return true;
    } on FirebaseFunctionsException catch (e) {
      logger.e(e.details.toString(), error: e);
      return false;
    }
  }

  Future<bool> postVideo(String videoUrl, String thumbnailUrl, String caption) async {
    final functions = FirebaseFunctions.instance;
    final request = _videoDataJson(videoUrl: videoUrl, thumbUrl: thumbnailUrl, caption: caption);

    try {
      final HttpsCallableResult<Map<String, dynamic>> result = await functions.httpsCallable(
        "https://api.locketcamera.com/postMomentV2", //
      )(request);
      logger.d(result.data.toString());
      return true;
    } on FirebaseFunctionsException catch (e) {
      logger.e(e.toString());
      return false;
    }
  }

  Future<Result<bool>> postVideo2(String videoUrl, String thumbnailUrl, String caption, String token) async {
    final json = _videoDataJson(videoUrl: videoUrl, thumbUrl: thumbnailUrl, caption: caption);

    final url = "https://api.locketcamera.com/postMomentV2";

    return Result.guardFuture<bool>(() async {
      final response = await dio.post(
        url,
        options: Options(
          headers: {
            'Content-Type': 'application/json', //
            'Authorization': 'Bearer $token',
          },
        ),
        data: jsonEncode(json),
      );
      final responseJSON = jsonDecode(response.data);
      logger.d(responseJSON);
      return true;
    });
  }

  String _generateName({required FileType type}) {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 1000;
    switch (type) {
      case FileType.image:
        return 'IMG_${timestamp}_$random.jpg';
      case FileType.video:
        return 'VID_${timestamp}_$random.mp4';
    }
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

enum FileType { image, video }
