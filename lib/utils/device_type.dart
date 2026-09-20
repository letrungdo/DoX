import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// What kind of machine the app is running on, resolved once at launch.
///
/// Only the television case is interesting: a Google TV box has no touchscreen,
/// so every control has to be reachable with the remote's D-pad instead. The
/// answer is needed synchronously while widgets build, hence the one-off
/// [init] rather than a future each caller has to await.
class _DeviceType {
  bool _isTv = false;
  List<String> _supportedAbis = const [];

  /// True on Android TV / Google TV — the app is being driven by a remote.
  bool get isTv => _isTv;

  /// The device's native ABIs, most preferred first — `arm64-v8a` on a modern
  /// phone, `armeabi-v7a` on the 32-bit boxes a lot of TV hardware still is.
  /// Empty off Android. Used to pick the right APK when the app updates itself.
  List<String> get supportedAbis => _supportedAbis;

  Future<void> init() async {
    // `defaultTargetPlatform` rather than `Platform.isAndroid`: this file is
    // reached by the web build too, which cannot import `dart:io`.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      // `leanback` is the feature every TV device declares (`leanback_only` is
      // the stricter one only set-top boxes without a touch layer have);
      // `type.television` covers the older boxes that predate it.
      _isTv =
          info.systemFeatures.contains('android.software.leanback') ||
          info.systemFeatures.contains('android.hardware.type.television');
      _supportedAbis = info.supportedAbis;
    } on Object {
      // Not knowing means assuming a phone, which is the behaviour the app
      // shipped with — never a reason to fail launch.
    }
  }

  /// Whether the screen's orientation is the app's to drive.
  ///
  /// A phone or tablet turns in the hand, so a video player may force it
  /// landscape and hand it back afterwards. A television has one orientation
  /// and no way to be turned: asking it for portrait does not rotate anything,
  /// it squeezes the whole app into a phone-shaped window in the middle of the
  /// panel and leaves it there. So on a TV nobody drives the orientation at
  /// all. The web has no such control either.
  bool get canDriveOrientation =>
      !kIsWeb &&
      !isTv &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @visibleForTesting
  set isTv(bool value) => _isTv = value;

  @visibleForTesting
  set supportedAbis(List<String> value) => _supportedAbis = value;
}

final deviceType = _DeviceType();
