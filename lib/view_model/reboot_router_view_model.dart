import 'package:do_x/services/router_reboot_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

class RebootRouterViewModel extends CoreViewModel {
  final _service = RouterRebootService();

  static const stepLabels = [
    "Kết nối & Quét MAC", //
    "Mã hóa & Xác thực",
    "Nhận Token (stok)",
    "Khởi động lại",
    "Chờ khởi động xong",
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

  int elapsedSeconds = 0;
  bool get isWaitingForOnline => activeStep == stepLabels.indexOf("Chờ khởi động xong");
  bool get isTakingTooLong => elapsedSeconds > 120; // Alert if > 2 minutes

  void skipWaiting() {
    activeStep = stepLabels.length;
    successMessage = "Đã bỏ qua bước chờ. Hãy kiểm tra kết nối thủ công.";
    notifyListenersSafe();
  }

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

      // New step: Wait for router to come back online
      activeStep = stepLabels.indexOf("Chờ khởi động xong");
      elapsedSeconds = 0;
      notifyListenersSafe();

      // Start a timer to track elapsed time while waiting
      final timer = Stream.periodic(const Duration(seconds: 1), (i) => i + 1).listen((val) {
        elapsedSeconds = val;
        notifyListenersSafe();
      });

      try {
        await _service.checkRouterOnline(
          ip: ip,
          onLog: _log,
          cancelToken: cancelToken,
        );
      } finally {
        timer.cancel();
      }

      activeStep = stepLabels.length; // Finished all steps
      successMessage = "Router đã khởi động lại xong và đang hoạt động! (Tổng thời gian chờ: ${elapsedSeconds}s)";
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
