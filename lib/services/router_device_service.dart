import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:do_x/repository/client/http_client_adapter.dart';
import 'package:flutter/foundation.dart';

class RouterConnectedDevice {
  const RouterConnectedDevice({
    required this.ipAddress,
    this.name,
    this.macAddress,
  });

  final String ipAddress;
  final String? name;
  final String? macAddress;
}

/// Reads connected-client information from the Xiaomi MiWiFi API.
class RouterDeviceService {
  static const _key = "a2ffa5c9be07488bbb04a3a47d3c5f6a";
  static const _fallbackMac = "00:11:22:33:44:55";
  static const _userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) DoXNetworkUtility";

  final Dio _dio = () {
    final dio = Dio();
    if (!kIsWeb) dio.httpClientAdapter = httpClientAdapter;
    return dio;
  }();

  Future<List<RouterConnectedDevice>> getConnectedDevices({
    required String ip,
    required String password,
    CancelToken? cancelToken,
  }) async {
    if (password.isEmpty) return const [];
    final baseUrl = _cleanIp(ip);
    final mac = await _getRouterMac(baseUrl);
    final nonce = _generateNonce(mac);
    final passwordHash = _generatePasswordHash(nonce, password);
    final body =
        {
              "username": "admin",
              "password": passwordHash,
              "logtype": "2",
              "nonce": nonce,
            }.entries
            .map(
              (entry) =>
                  "${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}",
            )
            .join("&");

    try {
      final loginResponse = await _dio.post(
        "$baseUrl/cgi-bin/luci/api/xqsystem/login",
        data: body,
        options: Options(
          contentType: "application/x-www-form-urlencoded",
          headers: {"User-Agent": _userAgent},
          receiveTimeout: const Duration(seconds: 4),
        ),
        cancelToken: cancelToken,
      );
      final loginData = _jsonMap(loginResponse.data);
      final stok = loginData["token"]?.toString();
      if (loginData["code"] != 0 || stok == null || stok.isEmpty) {
        return const [];
      }

      final devicesResponse = await _dio.get(
        "$baseUrl/cgi-bin/luci/;stok=$stok/api/misystem/devicelist",
        options: Options(
          headers: {"User-Agent": _userAgent},
          receiveTimeout: const Duration(seconds: 4),
        ),
        cancelToken: cancelToken,
      );
      return _parseConnectedDevices(_jsonMap(devicesResponse.data));
    } on Object {
      return const [];
    }
  }

  Future<String> _getRouterMac(String baseUrl) async {
    try {
      final response = await _dio.get(
        "$baseUrl/cgi-bin/luci/web/home",
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(milliseconds: 2500),
          headers: {"User-Agent": _userAgent},
        ),
      );
      final match = RegExp(
        r'([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}',
      ).firstMatch(response.data.toString());
      if (match != null) return match.group(0)!;
    } on Object {
      // The nonce identifier is not validated, so the fallback is sufficient.
    }
    return _fallbackMac;
  }

  List<RouterConnectedDevice> _parseConnectedDevices(
    Map<String, dynamic> data,
  ) {
    if (data["code"] != 0 || data["list"] is! List) return const [];
    final result = <RouterConnectedDevice>[];
    for (final rawDevice in data["list"] as List) {
      if (rawDevice is! Map) continue;
      final device = Map<String, dynamic>.from(rawDevice);
      if (device["online"].toString() != "1") continue;
      final ipEntries = device["ip"];
      if (ipEntries is! List || ipEntries.isEmpty) continue;
      final addressEntries = ipEntries.whereType<Map>().toList();
      if (addressEntries.isEmpty) continue;
      final activeEntry = addressEntries.firstWhere(
        (entry) => entry["active"].toString() == "1",
        orElse: () => addressEntries.first,
      );
      final ipAddress = activeEntry["ip"]?.toString().trim();
      if (ipAddress == null ||
          InternetAddress.tryParse(ipAddress)?.type !=
              InternetAddressType.IPv4) {
        continue;
      }
      final name = _firstDeviceName(device);
      result.add(
        RouterConnectedDevice(
          ipAddress: ipAddress,
          name: name,
          macAddress: device["mac"]?.toString(),
        ),
      );
    }
    return result;
  }

  Map<String, dynamic> _jsonMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    return jsonDecode(value.toString()) as Map<String, dynamic>;
  }

  String? _firstDeviceName(Map<String, dynamic> device) {
    for (final key in const ["name", "oname"]) {
      final value = device[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value.length <= 80) return value;
    }
    return null;
  }

  String _cleanIp(String ip) {
    var cleaned = ip.trim();
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(cleaned)) {
      cleaned = "http://$cleaned";
    }
    return cleaned.replaceAll(RegExp(r'/+$'), '');
  }

  String _generateNonce(String mac) {
    const miwifiType = 0;
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final randomInt = Random().nextInt(10000);
    return "${miwifiType}_${mac}_${timestamp}_$randomInt";
  }

  String _generatePasswordHash(String nonce, String password) {
    return _sha1(nonce + _sha1(password + _key));
  }

  String _sha1(String text) => sha1.convert(utf8.encode(text)).toString();
}
