import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:do_x/utils/app_info.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  /// e.g. "1.0.1+6"
  final String version;
  final String apkUrl;
  final String? releaseNotes;

  AppUpdateInfo({required this.version, required this.apkUrl, this.releaseNotes});
}

class UpdateService {
  static const _latestReleaseApi = 'https://api.github.com/repos/letrungdo/DoX/releases/latest';

  final _dio = Dio();

  /// Returns info about the latest GitHub release when it is newer than the
  /// running app and contains an APK asset. Android only.
  Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      final res = await _dio.get(
        _latestReleaseApi,
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      final tag = (res.data['tag_name'] as String?) ?? '';
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      if (!_isNewerThanCurrent(latest)) return null;

      final assets = (res.data['assets'] as List?) ?? [];
      final apk = assets.firstWhereOrNull((a) => (a['name'] as String? ?? '').endsWith('.apk'));
      if (apk == null) return null;

      return AppUpdateInfo(
        version: latest,
        apkUrl: apk['browser_download_url'],
        releaseNotes: res.data['body'],
      );
    } catch (e) {
      logger.e("check update failed", error: e);
      return null;
    }
  }

  /// Deterministic temp-dir path where the given update's APK is downloaded.
  /// Stable across app restarts so a partial file can be resumed.
  Future<String> apkPath(AppUpdateInfo update) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/dox_${update.version.replaceAll('+', '_')}.apk';
  }

  /// Downloads the APK to the temp dir, resuming from any partial file left
  /// over from a previous (possibly killed) run via an HTTP range request.
  /// Does NOT install — call [install] afterwards.
  Future<void> download(
    AppUpdateInfo update, {
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final path = await apkPath(update);
    final file = File(path);

    int existingLength = 0;
    if (await file.exists()) {
      existingLength = await file.length();
    }

    IOSink? sink;
    try {
      final response = await _dio.get<ResponseBody>(
        update.apkUrl,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            if (existingLength > 0) 'range': 'bytes=$existingLength-',
          },
          responseType: ResponseType.stream,
        ),
      );

      final totalLength = int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
      final isPartial = response.statusCode == 206;

      if (!isPartial && existingLength > 0) {
        existingLength = 0;
        await file.delete();
      }

      sink = file.openWrite(mode: isPartial ? FileMode.append : FileMode.write);

      int received = existingLength;
      int actualTotal = isPartial ? totalLength + existingLength : totalLength;

      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        onReceiveProgress?.call(received, actualTotal);
      }

      await sink.flush();
      await sink.close();
      sink = null;
    } catch (e) {
      await sink?.flush();
      await sink?.close();
      if (e is! DioException || e.type != DioExceptionType.cancel) {
        logger.e("Download failed", error: e);
      }
      rethrow;
    }
  }

  /// Opens the Android installer for the already-downloaded APK.
  Future<void> install(AppUpdateInfo update) async {
    final path = await apkPath(update);
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  /// Whether the given "1.0.1+6"-style version is newer than the running app.
  bool isNewerThanCurrent(String version) => _isNewerThanCurrent(version);

  /// Compares "1.0.1+6"-style versions against the running app.
  bool _isNewerThanCurrent(String latest) {
    final current = "${appInfo.version}+${appInfo.packageInfo.buildNumber}";
    final latestParts = _numericParts(latest);
    final currentParts = _numericParts(current);
    final length = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
    for (var i = 0; i < length; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l != c) return l > c;
    }
    return false;
  }

  List<int> _numericParts(String version) {
    return version.split(RegExp(r'[.+]')).map((e) => int.tryParse(e.trim()) ?? 0).toList();
  }
}

final updateService = UpdateService();
