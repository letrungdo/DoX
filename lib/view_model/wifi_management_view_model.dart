import 'dart:async';
import 'package:dio/dio.dart';
import 'package:do_x/services/router_reboot_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/speed_test_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

class WifiManagementViewModel extends CoreViewModel {
  final _rebootService = RouterRebootService();
  final _speedTestService = SpeedTestService();

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

  /// -1: idle, 0..last index: step in progress, length: all done.
  int activeStep = -1;
  String? successMessage;
  String? errorMessage;

  int elapsedSeconds = 0;
  bool get isWaitingForOnline =>
      activeStep == stepLabels.indexOf("Chờ khởi động xong");
  bool get isTakingTooLong => elapsedSeconds > 120; // Alert if > 2 minutes

  double? lanSpeed;
  int? lanLatency;
  double? internetSpeed;
  int? internetLatency;

  bool isTestingLan = false;
  bool isTestingInternet = false;
  bool get isTesting => isTestingLan || isTestingInternet;

  SpeedTestServer selectedServer = SpeedTestServer.internetServers.first;

  StreamSubscription? _lanSubscription;
  StreamSubscription? _internetSubscription;
  CancelToken? _lanCancelToken;
  CancelToken? _internetCancelToken;

  @override
  void dispose() {
    _lanCancelToken?.cancel("Wifi management disposed");
    _internetCancelToken?.cancel("Wifi management disposed");
    _lanSubscription?.cancel();
    _internetSubscription?.cancel();
    super.dispose();
  }

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
    stopTests();
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
      await _rebootService.reboot(
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
      final timer = Stream.periodic(const Duration(seconds: 1), (i) => i + 1)
          .listen((val) {
            elapsedSeconds = val;
            notifyListenersSafe();
          });

      try {
        await _rebootService.checkRouterOnline(
          ip: ip,
          onLog: _log,
          cancelToken: cancelToken,
        );
      } finally {
        timer.cancel();
      }
      if (isDispose || cancelToken.isCancelled) return;

      activeStep = stepLabels.length;
      successMessage =
          "Router đã khởi động lại xong (Thời gian chờ: ${elapsedSeconds}s).";
      _log("Router đã online. Hoàn tất khởi động lại.");
      notifyListenersSafe();
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

  void stopTests() {
    _lanCancelToken?.cancel("Speed test stopped");
    _lanCancelToken = null;
    _lanSubscription?.cancel();
    _lanSubscription = null;
    _internetCancelToken?.cancel("Speed test stopped");
    _internetCancelToken = null;
    _internetSubscription?.cancel();
    _internetSubscription = null;
    isTestingLan = false;
    isTestingInternet = false;
    notifyListenersSafe();
  }

  /// Runs the LAN and Internet speed tests concurrently. If a test is already
  /// running, it stops everything instead (acts as a toggle for a single
  /// "start/stop" button).
  void runSpeedTests() {
    if (isTesting) {
      stopTests();
      return;
    }
    _startLanTest();
    _startInternetTest();
  }

  void setSelectedServer(SpeedTestServer server) {
    selectedServer = server;
    notifyListenersSafe();
  }

  void _startLanTest() {
    _lanCancelToken?.cancel("Restarting LAN test");
    _lanSubscription?.cancel();
    isTestingLan = true;
    lanSpeed = 0;
    lanLatency = null;
    notifyListenersSafe();

    final baseUrl = _rebootService.cleanIp(ip);
    _lanCancelToken = CancelToken();

    _lanSubscription = _speedTestService
        .testLanSpeed(baseUrl, cancelToken: _lanCancelToken)
        .listen(
          (update) {
            lanSpeed = update.currentMbps;
            lanLatency = update.latencyMs;
            notifyListenersSafe();
          },
          onError: (e) {
            logger.e("LAN Speed test failed", error: e);
            isTestingLan = false;
            notifyListenersSafe();
          },
          onDone: () {
            isTestingLan = false;
            notifyListenersSafe();
          },
        );
  }

  void _startInternetTest() {
    _internetCancelToken?.cancel("Restarting Internet test");
    _internetSubscription?.cancel();
    isTestingInternet = true;
    internetSpeed = 0;
    internetLatency = null;
    notifyListenersSafe();

    _internetCancelToken = CancelToken();

    _internetSubscription = _speedTestService
        .testInternetSpeed(selectedServer, cancelToken: _internetCancelToken)
        .listen(
          (update) {
            internetSpeed = update.currentMbps;
            internetLatency = update.latencyMs;
            notifyListenersSafe();
          },
          onError: (e) {
            logger.e("Internet Speed test failed", error: e);
            isTestingInternet = false;
            notifyListenersSafe();
          },
          onDone: () {
            isTestingInternet = false;
            notifyListenersSafe();
          },
        );
  }
}
