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

  /// Downloads the APK to the temp dir and opens the Android installer.
  Future<void> downloadAndInstall(AppUpdateInfo update, {ProgressCallback? onReceiveProgress}) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/dox_${update.version.replaceAll('+', '_')}.apk';
    await _dio.download(update.apkUrl, path, onReceiveProgress: onReceiveProgress);
    await OpenFilex.open(path);
  }

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
