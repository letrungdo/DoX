import 'package:do_x/services/current_device_info_service.dart';
import 'package:do_x/services/local_network_service.dart';
import 'package:do_x/services/router_device_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

class LocalNetworkViewModel extends CoreViewModel {
  final _localNetworkService = LocalNetworkService();
  final _routerService = RouterDeviceService();
  final _currentDeviceInfoService = CurrentDeviceInfoService();

  final List<LocalNetworkDevice> devices = [];
  bool isScanning = false;
  int scannedAddresses = 0;
  int totalAddresses = 254;
  String? errorMessage;

  String? get routerUrl => storageService.getRouterIp();

  @override
  void initData() {
    super.initData();
    scan();
  }

  @override
  void dispose() {
    _localNetworkService.cancelScan();
    super.dispose();
  }

  Future<void> scan() async {
    if (isScanning) return;
    isScanning = true;
    scannedAddresses = 0;
    errorMessage = null;
    devices.clear();
    notifyListenersSafe();

    try {
      final configuredRouter = routerUrl;
      final currentDeviceIdentity = _currentDeviceInfoService.getIdentity();
      final routerDevices = configuredRouter == null
          ? Future.value(const <RouterConnectedDevice>[])
          : _loadRouterDevices(configuredRouter);
      final result = await _localNetworkService.scan(
        routerUrl: configuredRouter,
        onDeviceFound: (device) {
          final index = devices.indexWhere(
            (item) => item.ipAddress == device.ipAddress,
          );
          if (index == -1) {
            devices.add(device);
          } else {
            devices[index] = device;
          }
          devices.sort(
            (a, b) => _ipValue(a.ipAddress).compareTo(_ipValue(b.ipAddress)),
          );
          notifyListenersSafe();
        },
        onProgress: (scanned, total) {
          scannedAddresses = scanned;
          totalAddresses = total;
          notifyListenersSafe();
        },
      );
      final merged = {for (final device in result) device.ipAddress: device};
      for (final routerDevice in await routerDevices) {
        final existing = merged[routerDevice.ipAddress];
        merged[routerDevice.ipAddress] = LocalNetworkDevice(
          ipAddress: routerDevice.ipAddress,
          hostName: existing?.hostName,
          deviceName: routerDevice.name ?? existing?.deviceName,
          macAddress: routerDevice.macAddress ?? existing?.macAddress,
          modelName: existing?.modelName,
          openPorts: existing?.openPorts ?? const [],
          deviceType: _deviceTypeForRouterDevice(routerDevice, existing),
          isCurrentDevice: existing?.isCurrentDevice ?? false,
          isRouter: existing?.isRouter ?? false,
        );
      }
      final identity = await currentDeviceIdentity;
      for (final entry in merged.entries.toList()) {
        final device = entry.value;
        if (!device.isCurrentDevice) continue;
        merged[entry.key] = LocalNetworkDevice(
          ipAddress: device.ipAddress,
          hostName: device.hostName,
          deviceName: identity.name ?? device.deviceName,
          macAddress: device.macAddress,
          modelName: identity.modelName ?? device.modelName,
          openPorts: device.openPorts,
          deviceType: device.deviceType,
          isCurrentDevice: true,
          isRouter: device.isRouter,
        );
      }
      devices
        ..clear()
        ..addAll(merged.values)
        ..sort(
          (a, b) => _ipValue(a.ipAddress).compareTo(_ipValue(b.ipAddress)),
        );
    } on LocalNetworkScanException catch (e) {
      errorMessage = e.message;
    } on Object catch (e) {
      logger.e('Local network scan failed', error: e);
      errorMessage =
          'Không thể quét mạng nội bộ. Hãy kiểm tra kết nối Wi-Fi và quyền Local Network.';
    } finally {
      isScanning = false;
      notifyListenersSafe();
    }
  }

  Future<List<RouterConnectedDevice>> _loadRouterDevices(
    String routerAddress,
  ) async {
    final password = await secureStorage.getRouterPassword();
    if (password == null || password.isEmpty || isDispose) return const [];
    return _routerService.getConnectedDevices(
      ip: routerAddress,
      password: password,
      cancelToken: cancelToken,
    );
  }

  LocalNetworkDeviceType _deviceTypeForRouterDevice(
    RouterConnectedDevice routerDevice,
    LocalNetworkDevice? existing,
  ) {
    final inferred = classifyLocalNetworkDevice(
      name: routerDevice.name ?? existing?.deviceName,
      hostName: existing?.hostName,
      openPorts: existing?.openPorts ?? const [],
      isCurrentDevice: existing?.isCurrentDevice ?? false,
      isRouter: existing?.isRouter ?? false,
    );
    return inferred == LocalNetworkDeviceType.unknown
        ? existing?.deviceType ?? LocalNetworkDeviceType.unknown
        : inferred;
  }

  int _ipValue(String ip) => ip
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .fold(0, (value, part) => (value << 8) + part);
}
