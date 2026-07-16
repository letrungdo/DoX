import 'package:do_x/services/router_reboot_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

class RebootRouterViewModel extends CoreViewModel {
  final _service = RouterRebootService();

  static const stepLabels = [
    "Kết nối & Lấy deviceId", //
    "Mã hóa & Xác thực",
    "Nhận Token (stok)",
    "Khởi động lại",
  ];

  String ip = "http://192.168.2.35";
  String password = "";
  bool showPassword = false;

  final List<String> logs = [];
  bool showLogs = false;

  /// -1: idle, 0..3: step in progress, 4: all done
  int activeStep = -1;
  String? successMessage;
  String? errorMessage;

  @override
  void initData() async {
    super.initData();
    ip = storageService.getRouterIp() ?? ip;
    password = await secureStorage.getRouterPassword() ?? password;
    notifyListenersSafe();
  }

  void setIp(String value) {
    ip = value;
  }

  void setPassword(String value) {
    password = value;
  }

  void togglePasswordVisible() {
    showPassword = !showPassword;
    notifyListenersSafe();
  }

  void toggleShowLogs() {
    showLogs = !showLogs;
    notifyListenersSafe();
  }

  void _log(String message) {
    logs.add(message);
    notifyListenersSafe();
  }

  Future<void> reboot() async {
    if (isBusy) return;
    setBusy(true);
    successMessage = null;
    errorMessage = null;
    logs.clear();
    activeStep = 0;
    showLogs = true; // Auto show console logs during execution
    notifyListenersSafe();

    storageService.setRouterIp(ip);
    secureStorage.saveRouterPassword(password);

    try {
      final message = await _service.reboot(
        ip: ip,
        password: password,
        cancelToken: cancelToken,
        onStep: (step) {
          activeStep = step;
          notifyListenersSafe();
        },
        onLog: _log,
      );
      activeStep = stepLabels.length; // Finished all steps
      successMessage = message;
    } on RouterRebootException catch (e) {
      errorMessage = e.message;
      _log("Lỗi: ${e.message}");
    } catch (e) {
      logger.e("Reboot router failed", error: e);
      errorMessage = "Đã xảy ra lỗi kết nối hệ thống.";
      _log("Lỗi hệ thống: $e");
    } finally {
      setBusy(false);
    }
  }
}
