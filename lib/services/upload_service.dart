import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:do_x/model/response/generated_image_model.dart';
import 'package:do_x/model/response/user_model.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/cupertino.dart';

class UploadService {
  final dio = DioClient.create();

  static const uploadHeaders = {
    'content-type': 'application/octet-stream',
    'x-goog-upload-protocol': 'resumable',
    'x-goog-upload-offset': '0',
    'x-goog-upload-command': 'upload, finalize',
    'upload-incomplete': '?1',
    'upload-draft-interop-version': '6',
    'user-agent': 'com.locket.Locket/1.121.1 iPhone/18.3.2 hw/iPhone17_3 (GTMSUF/1)',
  };

  Future<String> _initUploadImage({
    required Uint8List data, //
    required UserModel user,
    required String imgName,
    CancelToken? cancelToken,
  }) async {
    final fileSize = data.lengthInBytes;
    final idUser = user.localId;
    final body = {
      "name": "users/$idUser/moments/thumbnails/$imgName",
      "contentType": 'image/webp',
      "bucket": '',
      "metadata": {"creator": idUser, "visibility": 'private'},
    };

    final response = await dio.post(
      "https://firebasestorage.googleapis.com/v0/b/locket-img/o/users%2F$idUser%2Fmoments%2Fthumbnails%2F$imgName?uploadType=resumable&name=users%2F$idUser%2Fmoments%2Fthumbnails%2F$imgName", //
      data: body,
      options: Options(
        headers: {
          "content-type": "application/json; charset=UTF-8",
          HttpHeaders.authorizationHeader: "Firebase ${user.idToken}",
          "x-goog-upload-protocol": "resumable",
          "accept": "*/*",
          "x-goog-upload-command": "start",
          "x-goog-upload-content-length": fileSize,
          "x-goog-upload-content-type": "image/webp",
        },
      ),
      cancelToken: cancelToken,
    );
    final uploadUrl = response.headers['x-goog-upload-url']?.firstOrNull;
    if (uploadUrl == null) {
      throw "init upload url fail";
    }

    return uploadUrl;
  }

  Future<String> _getDownloadUrl({
    required UserModel user, //
    required String nameImg,
    CancelToken? cancelToken,
  }) async {
    final getUrl = "https://firebasestorage.googleapis.com/v0/b/locket-img/o/users%2F${user.localId}%2Fmoments%2Fthumbnails%2F$nameImg";

    final response = await dio.get(
      getUrl, //
      options: Options(
        headers: {
          HttpHeaders.authorizationHeader: "Firebase ${user.idToken}", //
        },
      ),
      cancelToken: cancelToken,
    );
    final downloadToken = GeneratedImage.fromJson(response.data).downloadTokens;
    return "$getUrl?alt=media&token=$downloadToken";
  }

  Future<Result<String>> uploadImage({
    required Uint8List data, //
    required UserModel user,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return Result.guardFuture(() async {
      final nameImg = _generateName(type: FileType.image);

      final uploadUrl = await _initUploadImage(
        data: data, //
        user: user,
        imgName: nameImg,
        cancelToken: cancelToken,
      );
      final resUpload = await dio.put(
        uploadUrl, //
        data: data,
        options: Options(
          headers: {
            HttpHeaders.authorizationHeader: "Firebase ${user.idToken}", //
            ...uploadHeaders,
          },
        ),
        onReceiveProgress: onReceiveProgress,
      );
      debugPrint("resUpload ${resUpload.data.toString()}");
      final downloadUrl = await _getDownloadUrl(
        nameImg: nameImg, //
        user: user,
        cancelToken: cancelToken,
      );

      return downloadUrl;
    });
  }

  Future uploadVideo({
    required File video, //
    required Uint8List thumbnail,
    required String userId,
  }) async {
    try {
      // final String videoFileName = _generateName(type: FileType.video);
      // final Reference videoRef = FirebaseStorage.instance
      //     .refFromURL("gs://locket-video")
      //     .child('/users/$userId/moments/videos/$videoFileName');

      // final UploadTask videoUploadTask = videoRef.putFile(video);
      // final TaskSnapshot videoSnapshot = await videoUploadTask.whenComplete(() {});
      // final String videoUrl = await videoSnapshot.ref.getDownloadURL();

      // final thumbnailUrl = await uploadImage(data: thumbnail, userId: userId);

      // if (thumbnailUrl != null) {
      //   return (videoUrl, thumbnailUrl, true);
      // } else {
      //   return ("", "", false);
      // }
    } catch (e) {
      logger.e(e.toString());
      return ("", "", false);
    }
  }

  String _generateName({required FileType type}) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final idBuffer = StringBuffer();
    for (int i = 0; i < 20; i++) {
      final randomIndex = random.nextInt(chars.length);
      idBuffer.write(chars[randomIndex]);
    }
    final name = idBuffer.toString();
    switch (type) {
      case FileType.image:
        return '$name.webp';
      case FileType.video:
        return '$name.mp4';
    }
  }
}

enum FileType { image, video }
