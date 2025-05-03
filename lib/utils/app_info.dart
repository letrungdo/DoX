import 'package:package_info_plus/package_info_plus.dart';

class _AppInfo {
  late PackageInfo _packageInfo;
  PackageInfo get packageInfo => _packageInfo;

  String get version => _packageInfo.version;

  Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }
}

final appInfo = _AppInfo();
