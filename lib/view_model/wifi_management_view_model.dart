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
    _signalTimer?.cancel();
    _autoScanTimer?.cancel();
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

  /// The upstream signal poll: cheap (~0.3s per call), so it can run live
  /// while the repeater tab is on screen.
  static const _signalInterval = Duration(seconds: 3);

  /// A scan takes the radio off the air for ~3.5s, and a second one landing
  /// on top of it hangs the router for ~40s — so auto scans are slow and
  /// never overlap.
  static const _autoScanInterval = Duration(seconds: 20);
  static const _minScanGap = Duration(seconds: 10);

  /// How long the uplink reading stays untrustworthy after a scan. Measured
  /// on ROM 2.25.124: the router answers 0 for the ~3.5s the radio is away
  /// and one more depressed value ~0.5s after it comes back, so the poll
  /// waits for the link to settle rather than drawing the dip.
  static const _scanSettleDelay = Duration(milliseconds: 1500);

  Timer? _signalTimer;
  Timer? _autoScanTimer;
  DateTime? _lastScanAt;
  bool _isPollingSignal = false;

  /// Bumped whenever a scan starts or ends. A poll whose reply crosses a scan
  /// is thrown away: the scan pulls the radio off the uplink channel, and the
  /// router answers `wifiap_signal` with 0 while it is away.
  int _scanTick = 0;

  bool isRepeaterLoading = false;
  bool isScanning = false;

  /// An auto scan, which keeps the old list on screen and leaves the main
  /// scan button alone.
  bool isBackgroundScanning = false;
  bool isAutoScanOn = false;

  /// Set when a signal poll fails, so the card can mark the value as old
  /// instead of flashing an error banner every few seconds.
  bool isSignalStale = false;
  bool isApplyingUpstream = false;
  String? repeaterError;
  String? repeaterSuccess;

  /// Guards the one-shot auto login when the repeater tab is first opened.
  bool _repeaterAutoConnected = false;

  bool get isRepeaterLoggedIn => _repeaterService.isLoggedIn;

  // A getter, so a message built after an await still reads the live context
  // instead of one captured before the gap.
  AppLocalizations get _l10n => context.l10n;

  bool get isLive => _signalTimer != null;

  /// Starts the live signal poll; called when the repeater tab becomes
  /// visible. Resumes auto scanning too, if it was left on.
  void startRepeaterLive() {
    if (_signalTimer == null && password.isNotEmpty) {
      _signalTimer = Timer.periodic(_signalInterval, (_) => _pollSignal());
      _pollSignal();
    }
    if (isAutoScanOn && _autoScanTimer == null) {
      _autoScanTimer = Timer.periodic(_autoScanInterval, (_) => _autoScan());
    }
    notifyListenersSafe();
  }

  /// Stops every repeater timer — leaving the tab, or leaving the screen.
  /// [isAutoScanOn] is kept so returning to the tab resumes it.
  void stopRepeaterLive() {
    _signalTimer?.cancel();
    _signalTimer = null;
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
    notifyListenersSafe();
  }

  void toggleAutoScan() {
    isAutoScanOn = !isAutoScanOn;
    if (isAutoScanOn) {
      _autoScanTimer = Timer.periodic(_autoScanInterval, (_) => _autoScan());
      _autoScan();
    } else {
      _autoScanTimer?.cancel();
      _autoScanTimer = null;
    }
    notifyListenersSafe();
  }

  /// One live tick: reads the uplink quality only, and stays quiet about
  /// failures beyond marking the value stale.
  Future<void> _pollSignal() async {
    if (_isPollingSignal ||
        isRepeaterLoading ||
        isApplyingUpstream ||
        isScanning ||
        isBackgroundScanning ||
        isDispose) {
      return;
    }
    final settledAt = _lastScanAt;
    if (settledAt != null &&
        DateTime.now().difference(settledAt) < _scanSettleDelay) {
      return;
    }
    final tick = _scanTick;
    _isPollingSignal = true;
    try {
      if (!_repeaterService.isLoggedIn) {
        await _repeaterService.login(
          ip: ip,
          password: password,
          cancelToken: cancelToken,
        );
      }
      final upstream = await _repeaterService.getUpstream(
        cancelToken: cancelToken,
      );
      if (isDispose || cancelToken.isCancelled) return;
      // A scan started while this call was out, so the reading is the router's
      // off-channel 0 rather than the uplink. The old value stays on screen.
      if (_scanTick != tick) return;
      repeaterStatus = upstream.copyWith(
        localSsids: repeaterStatus?.localSsids,
      );
      isSignalStale = false;
      notifyListenersSafe();
    } catch (e) {
      if (isDispose) return;
      isSignalStale = true;
      // An expired token is the usual cause; dropping it makes the next tick
      // log in again.
      if (e is RouterApiException && e.error == RouterApiError.auth) {
        _repeaterService.logout();
      }
      notifyListenersSafe();
    } finally {
      _isPollingSignal = false;
    }
  }

  /// Re-applies the order of the list already on screen to [fresh], keeping
  /// each access point's new signal. Newly appeared ones go last.
  List<NearbyWifi> _keepScanOrder(List<NearbyWifi> fresh) {
    final previous = nearbyWifi;
    if (previous == null || previous.isEmpty) return fresh;
    final byBssid = {for (final wifi in fresh) wifi.bssid: wifi};
    final ordered = <NearbyWifi>[];
    for (final wifi in previous) {
      final updated = byBssid.remove(wifi.bssid);
      if (updated != null) ordered.add(updated);
    }
    return [...ordered, ...byBssid.values];
  }

  /// A scan on the timer. Skipped whenever the radio is likely still busy, so
  /// two scans can never pile up on the router.
  void _autoScan() {
    if (isScanning || isBackgroundScanning || isApplyingUpstream) return;
    final last = _lastScanAt;
    if (last != null && DateTime.now().difference(last) < _minScanGap) return;
    scanNearbyWifi(background: true);
  }

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
      isSignalStale = false;
      startRepeaterLive();
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

  /// Scans for nearby Wi-Fi. A [background] scan keeps whatever is already on
  /// screen — the list, and any success or error message.
  Future<void> scanNearbyWifi({bool background = false}) async {
    if (isScanning || isBackgroundScanning) return;
    if (background) {
      isBackgroundScanning = true;
    } else {
      isScanning = true;
      repeaterError = null;
      repeaterSuccess = null;
    }
    _lastScanAt = DateTime.now();
    _scanTick++;
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
      // A manual scan sorts by signal; a background one keeps the order the
      // user is looking at, so rows do not swap places under their finger.
      nearbyWifi = background ? _keepScanOrder(list) : list;
    } catch (e) {
      // A background scan that fails leaves the previous list alone rather
      // than replacing the page with an error.
      if (background) {
        _log("autoScan -> $e");
        if (e is RouterApiException && e.error == RouterApiError.auth) {
          _repeaterService.logout();
        }
      } else {
        _handleRepeaterFailure(e, "scanNearbyWifi");
      }
    } finally {
      _lastScanAt = DateTime.now();
      _scanTick++;
      isScanning = false;
      isBackgroundScanning = false;
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
    // The router restarts its network here, so nothing should be polling it.
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
    isAutoScanOn = false;
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
      // The session dies with the network restart, and the router usually
      // comes back on a different address, so polling stops here.
      _repeaterService.logout();
      stopRepeaterLive();
      return true;
    } on RouterApiException catch (e) {
      if (e.error == RouterApiError.unreachable) {
        // The router applied the change and dropped the link before it could
        // answer, which is the common case rather than an error.
        _repeaterService.logout();
        stopRepeaterLive();
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
