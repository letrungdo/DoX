import 'package:do_x/services/local_network_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

class LocalNetworkViewModel extends CoreViewModel {
  final _localNetworkService = LocalNetworkService();

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
      final result = await _localNetworkService.scan(
        routerUrl: routerUrl,
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
      devices
        ..clear()
        ..addAll(result);
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

  int _ipValue(String ip) => ip
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .fold(0, (value, part) => (value << 8) + part);
}
