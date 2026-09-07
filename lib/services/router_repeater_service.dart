import 'package:dio/dio.dart';
import 'package:do_x/services/router_api_client.dart';

/// What the router is currently repeating from, if anything.
class RepeaterStatus {
  const RepeaterStatus({
    this.upstreamSsid,
    this.signal,
    this.band,
    this.localSsids = const [],
  });

  /// SSID of the upstream Wi-Fi the router relays. Null when the router is not
  /// in repeater mode.
  final String? upstreamSsid;

  /// Uplink quality in percent, as the router reports it.
  final int? signal;

  /// "2g" / "5g" when the router reports one.
  final String? band;

  /// The router's own broadcast SSIDs, in the order the router lists them.
  final List<String> localSsids;

  bool get isRepeating => (upstreamSsid ?? "").isNotEmpty;
}

/// One access point seen by the router's own scan.
class NearbyWifi {
  const NearbyWifi({
    required this.ssid,
    required this.bssid,
    required this.signal,
    this.band,
    this.channel,
    this.encryption,
    this.enctype,
    this.bandwidth,
  });

  final String ssid;
  final String bssid;

  /// Signal quality in percent (0-100).
  final int signal;
  final String? band;
  final int? channel;

  /// Router-reported encryption, e.g. `WPA2PSK`, `WEP` or `NONE`.
  final String? encryption;
  final String? enctype;
  final String? bandwidth;

  bool get isOpen {
    final value = encryption?.toUpperCase() ?? "";
    return value.isEmpty || value == "NONE" || value == "OPEN";
  }

  bool get isWep => encryption?.toUpperCase() == "WEP";
}

/// Outcome of switching the upstream Wi-Fi.
class RepeaterApplyResult {
  const RepeaterApplyResult({required this.ssid, this.ip});

  /// SSID the router will repeat from now on.
  final String ssid;

  /// New LAN IP of the router, which usually changes: in repeater mode the
  /// upstream router hands out the address.
  final String? ip;
}

/// Repeater (无线中继) management for the Xiaomi R3G developer ROM.
///
/// Endpoints confirmed against ROM 2.25.124 — they are the same ones the
/// router's own "工作模式切换" dialog calls:
/// - `api/xqnetwork/wifiap_signal` — upstream SSID and uplink quality
/// - `api/xqnetwork/wifi_detail_all` — the router's own SSIDs
/// - `api/xqnetwork/wifi_list` — scan of the surrounding Wi-Fi
/// - `api/xqnetwork/set_wifi_ap` — pick a new upstream (POST form)
class RouterRepeaterService {
  RouterRepeaterService([RouterApiClient? client])
    : _client = client ?? RouterApiClient();

  final RouterApiClient _client;

  bool get isLoggedIn => _client.stok != null;

  void logout() => _client.clearSession();

  Future<void> login({
    required String ip,
    required String password,
    void Function(String message)? onLog,
    CancelToken? cancelToken,
  }) {
    return _client.login(
      ip: ip,
      password: password,
      onLog: onLog,
      cancelToken: cancelToken,
    );
  }

  Future<RepeaterStatus> getStatus({
    void Function(String message)? onLog,
    CancelToken? cancelToken,
  }) async {
    final signal = await _client.apiGet(
      "api/xqnetwork/wifiap_signal",
      cancelToken: cancelToken,
      onLog: onLog,
    );
    final ssid = signal["ssid"]?.toString().trim();
    final band = signal["band"]?.toString().trim();

    // The router's own SSIDs are a separate call, and a failure there must not
    // hide the upstream we already know about.
    var localSsids = const <String>[];
    try {
      final detail = await _client.apiGet(
        "api/xqnetwork/wifi_detail_all",
        cancelToken: cancelToken,
        onLog: onLog,
      );
      final info = detail["info"];
      if (info is List) {
        localSsids = info
            .whereType<Map>()
            .where((entry) => entry["status"].toString() == "1")
            .map((entry) => entry["ssid"]?.toString() ?? "")
            .where((entry) => entry.isNotEmpty)
            .toList();
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
    } on RouterApiException catch (e) {
      onLog?.call("wifi_detail_all failed: $e");
    }

    return RepeaterStatus(
      upstreamSsid: (ssid ?? "").isEmpty ? null : ssid,
      signal: _asInt(signal["signal"]),
      band: (band ?? "").isEmpty ? null : band,
      localSsids: localSsids,
    );
  }

  /// Ask the router to scan for nearby access points, strongest first.
  ///
  /// The scan takes the radio off the air for a moment, so the router needs a
  /// generous timeout here.
  Future<List<NearbyWifi>> scan({
    void Function(String message)? onLog,
    CancelToken? cancelToken,
  }) async {
    final data = await _client.apiGet(
      "api/xqnetwork/wifi_list",
      timeout: const Duration(seconds: 25),
      cancelToken: cancelToken,
      onLog: onLog,
    );
    if (data["code"] != 0 || data["list"] is! List) {
      throw RouterApiException(
        RouterApiError.rejected,
        code: _asInt(data["code"]),
        detail: data["msg"]?.toString(),
      );
    }

    final result = <NearbyWifi>[];
    for (final raw in data["list"] as List) {
      if (raw is! Map) continue;
      final ssid = raw["ssid"]?.toString().trim() ?? "";
      // A hidden network has no SSID to relay from, so it cannot be picked.
      if (ssid.isEmpty) continue;
      result.add(
        NearbyWifi(
          ssid: ssid,
          bssid: raw["bssid"]?.toString() ?? "",
          signal: _asInt(raw["signal"]) ?? 0,
          band: raw["band"]?.toString(),
          channel: _asInt(raw["channel"]),
          encryption: raw["encryption"]?.toString(),
          enctype: raw["enctype"]?.toString(),
          bandwidth: raw["bandwidth"]?.toString(),
        ),
      );
    }
    result.sort((a, b) => b.signal.compareTo(a.signal));
    return result;
  }

  /// Point the repeater at [wifi]. [password] is the *upstream* Wi-Fi password
  /// and is ignored for an open network.
  ///
  /// The router restarts its network right after answering, so whoever is
  /// connected through it loses the link for a while.
  Future<RepeaterApplyResult> setUpstream({
    required NearbyWifi wifi,
    required String password,
    void Function(String message)? onLog,
    CancelToken? cancelToken,
  }) async {
    final form = <String, String>{
      "ssid": wifi.ssid,
      "encryption": wifi.isOpen ? "NONE" : (wifi.encryption ?? "WPA2PSK"),
      if (!wifi.isOpen) "password": password,
      if (wifi.enctype != null && wifi.enctype!.isNotEmpty)
        "enctype": wifi.enctype!,
      if (wifi.channel != null) "channel": "${wifi.channel}",
      if (wifi.bandwidth != null && wifi.bandwidth!.isNotEmpty)
        "bandwidth": wifi.bandwidth!,
      if (wifi.band != null && wifi.band!.isNotEmpty) "band": wifi.band!,
    };

    final data = await _client.apiPost(
      "api/xqnetwork/set_wifi_ap",
      form,
      cancelToken: cancelToken,
      onLog: onLog,
    );
    if (data["code"] != 0) {
      throw RouterApiException(
        RouterApiError.rejected,
        code: _asInt(data["code"]),
        detail: data["msg"]?.toString(),
      );
    }
    return RepeaterApplyResult(
      ssid: data["ssid"]?.toString() ?? wifi.ssid,
      ip: data["ip"]?.toString(),
    );
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? "");
  }
}
