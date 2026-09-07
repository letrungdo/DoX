import 'dart:async';
import 'package:dio/dio.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/services/router_api_client.dart';
import 'package:do_x/services/router_reboot_service.dart';
import 'package:do_x/services/router_repeater_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/speed_test_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';

class WifiManagementViewModel extends CoreViewModel {
  final _rebootService = RouterRebootService();
  final _speedTestService = SpeedTestService();
  final _repeaterService = RouterRepeaterService();

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

  // --- Repeater (wireless relay) ---

  /// Null until the router has been asked; set once [connectRepeater] runs.
  RepeaterStatus? repeaterStatus;

  /// Null until a scan has run, so "not scanned yet" and "nothing found" stay
  /// distinguishable.
  List<NearbyWifi>? nearbyWifi;

  bool isRepeaterLoading = false;
  bool isScanning = false;
  bool isApplyingUpstream = false;
  String? repeaterError;
  String? repeaterSuccess;

  /// Guards the one-shot auto login when the repeater tab is first opened.
  bool _repeaterAutoConnected = false;

  bool get isRepeaterLoggedIn => _repeaterService.isLoggedIn;

  // A getter, so a message built after an await still reads the live context
  // instead of one captured before the gap.
  AppLocalizations get _l10n => context.l10n;

  /// Logs in with the credentials from the config section and reads which
  /// Wi-Fi the router currently repeats.
  Future<void> connectRepeater() async {
    if (isRepeaterLoading) return;
    isRepeaterLoading = true;
    repeaterError = null;
    repeaterSuccess = null;
    notifyListenersSafe();

    storageService.setRouterIp(ip);
    secureStorage.saveRouterPassword(password);

    try {
      if (!_repeaterService.isLoggedIn) {
        await _repeaterService.login(
          ip: ip,
          password: password,
          onLog: _log,
          cancelToken: cancelToken,
        );
      }
      final status = await _repeaterService.getStatus(
        onLog: _log,
        cancelToken: cancelToken,
      );
      if (isDispose || cancelToken.isCancelled) return;
      repeaterStatus = status;
    } catch (e) {
      _handleRepeaterFailure(e, "connectRepeater");
    } finally {
      isRepeaterLoading = false;
      notifyListenersSafe();
    }
  }

  /// Called when the repeater tab is first shown, so the status is already
  /// there without the user pressing anything.
  void connectRepeaterOnce() {
    if (_repeaterAutoConnected || password.isEmpty) return;
    _repeaterAutoConnected = true;
    connectRepeater();
  }

  Future<void> scanNearbyWifi() async {
    if (isScanning) return;
    isScanning = true;
    repeaterError = null;
    repeaterSuccess = null;
    notifyListenersSafe();

    try {
      if (!_repeaterService.isLoggedIn) {
        await _repeaterService.login(
          ip: ip,
          password: password,
          onLog: _log,
          cancelToken: cancelToken,
        );
      }
      final list = await _repeaterService.scan(
        onLog: _log,
        cancelToken: cancelToken,
      );
      if (isDispose || cancelToken.isCancelled) return;
      nearbyWifi = list;
    } catch (e) {
      _handleRepeaterFailure(e, "scanNearbyWifi");
    } finally {
      isScanning = false;
      notifyListenersSafe();
    }
  }

  /// Points the repeater at [wifi]. Returns true when the router accepted it.
  ///
  /// The router restarts its network right after answering, so losing the
  /// connection here is expected rather than a failure.
  Future<bool> applyUpstream(NearbyWifi wifi, String wifiPassword) async {
    if (isApplyingUpstream) return false;
    isApplyingUpstream = true;
    repeaterError = null;
    repeaterSuccess = null;
    notifyListenersSafe();

    try {
      if (!_repeaterService.isLoggedIn) {
        await _repeaterService.login(
          ip: ip,
          password: password,
          onLog: _log,
          cancelToken: cancelToken,
        );
      }
      final result = await _repeaterService.setUpstream(
        wifi: wifi,
        password: wifiPassword,
        onLog: _log,
        cancelToken: cancelToken,
      );
      if (isDispose || cancelToken.isCancelled) return false;

      repeaterSuccess = [
        _l10n.repeaterApplied(result.ssid),
        if (result.ip != null && result.ip!.isNotEmpty)
          _l10n.repeaterAppliedIp(result.ip!),
      ].join(" ");
      repeaterStatus = RepeaterStatus(
        upstreamSsid: result.ssid,
        band: wifi.band,
        localSsids: repeaterStatus?.localSsids ?? const [],
      );
      // The session dies with the network restart.
      _repeaterService.logout();
      return true;
    } on RouterApiException catch (e) {
      if (e.error == RouterApiError.unreachable) {
        // The router applied the change and dropped the link before it could
        // answer, which is the common case rather than an error.
        _repeaterService.logout();
        repeaterSuccess = _l10n.repeaterApplyDropped;
        return true;
      }
      _handleRepeaterFailure(e, "applyUpstream");
      return false;
    } catch (e) {
      _handleRepeaterFailure(e, "applyUpstream");
      return false;
    } finally {
      isApplyingUpstream = false;
      notifyListenersSafe();
    }
  }

  void _handleRepeaterFailure(Object error, String action) {
    if (error is DioException && error.type == DioExceptionType.cancel) return;
    if (error is RouterApiException) {
      _log("$action -> $error");
      repeaterError = _repeaterErrorMessage(error.error);
      return;
    }
    logger.e("Router repeater $action failed", error: error);
    _log("$action -> $error");
    repeaterError = _l10n.routerErrorMalformed;
  }

  String _repeaterErrorMessage(RouterApiError error) {
    final l10n = _l10n;
    return switch (error) {
      RouterApiError.unreachable => l10n.routerErrorUnreachable,
      RouterApiError.auth => l10n.routerErrorAuth,
      RouterApiError.malformed => l10n.routerErrorMalformed,
      RouterApiError.rejected => l10n.routerErrorRejected,
    };
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
