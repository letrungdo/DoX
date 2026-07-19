import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class CurrentDeviceIdentity {
  const CurrentDeviceIdentity({this.name, this.modelName});

  final String? name;
  final String? modelName;
}

/// Reads the identity of the phone that is running the app. Network discovery
/// cannot reliably obtain this on iOS because the assigned device name is
/// privacy-protected, while the commercial model name remains available.
class CurrentDeviceInfoService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<CurrentDeviceIdentity> getIdentity() async {
    try {
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return CurrentDeviceIdentity(
          name: _usefulAssignedName(
            info.name,
            genericNames: const {'iphone', 'ipad'},
          ),
          modelName: _clean(info.modelName),
        );
      }
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        final manufacturer = _clean(info.manufacturer);
        final model = _clean(info.model);
        final modelName = [
          if (manufacturer != null) manufacturer,
          if (model != null &&
              model.toLowerCase() != manufacturer?.toLowerCase())
            model,
        ].join(' ');
        return CurrentDeviceIdentity(
          name: _usefulAssignedName(info.name),
          modelName: modelName.isEmpty ? null : modelName,
        );
      }
    } on Object {
      // Device metadata is optional; network discovery can still continue.
    }
    return const CurrentDeviceIdentity();
  }

  String? _usefulAssignedName(
    String? value, {
    Set<String> genericNames = const {},
  }) {
    final name = _clean(value);
    if (name == null || genericNames.contains(name.toLowerCase())) return null;
    return name;
  }

  String? _clean(String? value) {
    final cleaned = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
