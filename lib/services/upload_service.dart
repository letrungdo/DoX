import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:do_x/model/response/generated_image_model.dart';
import 'package:do_x/model/response/user_model.dart';
import 'package:do_x/repository/client/dio_client.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:flutter/cupertino.dart';

class UploadService {
  final dio = DioClient.createFirebase();

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
    required int fileSize, //
    required UserModel user,
    required String imgName,
    CancelToken? cancelToken,
  }) async {
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

  Future<String> _initUploadVideo({
    required int fileSize, //
    required UserModel user,
    required String videoName,
    CancelToken? cancelToken,
  }) async {
    final idUser = user.localId;
    final body = {
      "name": "users/$idUser/moments/videos/$videoName",
      "contentType": 'video/mp4',
      "bucket": '',
      "metadata": {"creator": idUser, "visibility": 'private'},
    };

    final response = await dio.post(
      "https://firebasestorage.googleapis.com/v0/b/locket-video/o/users%2F$idUser%2Fmoments%2Fvideos%2F$videoName?uploadType=resumable&name=users%2F$idUser%2Fmoments%2Fvideos%2F$videoName", //
      data: body,
      options: Options(
        headers: {
          'content-type': 'application/json; charset=UTF-8',
          'x-goog-upload-protocol': 'resumable',
          "accept": '*/*',
          'x-goog-upload-command': 'start',
          'x-goog-upload-content-length': fileSize,
          'accept-language': 'vi-VN,vi;q=0.9',
          'x-firebase-storage-version': 'ios/10.13.0',
          'user-agent': 'com.locket.Locket/1.43.1 iPhone/17.3 hw/iPhone15_3 (GTMSUF/1)',
          'x-goog-upload-content-type': 'video/mp4',
          'x-firebase-gmpid': '1:641029076083:ios:cc8eb46290d69b234fa609',
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

  Future<String> _getDownloadImageUrl({
    required UserModel user, //
    required String imgName,
    CancelToken? cancelToken,
  }) async {
    final getUrl = "https://firebasestorage.googleapis.com/v0/b/locket-img/o/users%2F${user.localId}%2Fmoments%2Fthumbnails%2F$imgName";

    final response = await dio.get(
      getUrl, //
      cancelToken: cancelToken,
    );
    final downloadToken = GeneratedImage.fromJson(response.data).downloadTokens;
    return "$getUrl?alt=media&token=$downloadToken";
  }

  Future<String> _getDownloadVideoUrl({
    required UserModel user, //
    required String videoName,
    CancelToken? cancelToken,
  }) async {
    final getUrl = "https://firebasestorage.googleapis.com/v0/b/locket-video/o/users%2F${user.localId}%2Fmoments%2Fvideos%2F$videoName";

    final response = await dio.get(
      getUrl, //
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
      final imgName = _generateName(type: FileType.image);

      final uploadUrl = await _initUploadImage(
        fileSize: data.lengthInBytes, //
        user: user,
        imgName: imgName,
        cancelToken: cancelToken,
      );
      final resUpload = await dio.put(
        uploadUrl, //
        data: data,
        options: Options(headers: uploadHeaders),
        onReceiveProgress: onReceiveProgress,
      );
      debugPrint("resUpload ${resUpload.data.toString()}");
      final downloadUrl = await _getDownloadImageUrl(
        imgName: imgName, //
        user: user,
        cancelToken: cancelToken,
      );

      return downloadUrl;
    });
  }

  Future<Result<String>> uploadVideo({
    required Uint8List data, //
    required UserModel user,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return Result.guardFuture(() async {
      final videoName = _generateName(type: FileType.video);

      final uploadUrl = await _initUploadVideo(
        fileSize: data.lengthInBytes, //
        user: user,
        videoName: videoName,
        cancelToken: cancelToken,
      );
      final resUpload = await dio.put(
        uploadUrl, //
        data: data,
        options: Options(headers: uploadHeaders),
        onReceiveProgress: onReceiveProgress,
      );
      debugPrint("resUpload ${resUpload.data.toString()}");
      final downloadUrl = await _getDownloadVideoUrl(
        videoName: videoName, //
        user: user,
        cancelToken: cancelToken,
      );

      return downloadUrl;
    });
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
