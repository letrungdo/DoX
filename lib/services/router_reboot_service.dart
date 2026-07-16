import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:do_x/repository/client/dio_client.dart';

class RouterRebootException implements Exception {
  RouterRebootException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reboot Xiaomi Router (R3G / MiWiFi) via web api:
/// scrape MAC -> generate nonce -> sha1 challenge-response login -> stok -> reboot
class RouterRebootService {
  static const _authKey = "a2ffa5c9be07488bbb04a3a47d3c5f6a";
  static const _fallbackMac = "00:11:22:33:44:55";
  static const _userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) DoXRebootUtility";

  final _dio = DioClient.create();

  String _sha1(String text) => sha1.convert(utf8.encode(text)).toString();

  String cleanIp(String ip) {
    var cleaned = ip.trim();
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(cleaned)) {
      cleaned = "http://$cleaned";
    }
    return cleaned.replaceAll(RegExp(r'/+$'), '');
  }

  Future<String> _getRouterMac(String baseUrl, void Function(String) onLog) async {
    try {
      final response = await _dio.get(
        "$baseUrl/cgi-bin/luci/web/home",
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(milliseconds: 2500),
          headers: {"User-Agent": _userAgent},
        ),
      );
      final match = RegExp(r'([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}').firstMatch(response.data.toString());
      if (match != null) {
        return match.group(0)!;
      }
    } catch (e) {
      onLog("Không quét được MAC address, dùng MAC mặc định. ($e)");
    }
    return _fallbackMac;
  }

  String _generateNonce(String mac) {
    const miwifiType = 0;
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final randomInt = Random().nextInt(10000);
    return "${miwifiType}_${mac}_${timestamp}_$randomInt";
  }

  String _generatePasswordHash(String nonce, String password) {
    return _sha1(nonce + _sha1(password + _authKey));
  }

  /// Run the full reboot sequence.
  /// [onStep] is called with 0..3 when each step starts.
  /// Returns the success message, throws [RouterRebootException] on failure.
  Future<String> reboot({
    required String ip,
    required String password,
    required void Function(int step) onStep,
    required void Function(String message) onLog,
    CancelToken? cancelToken,
  }) async {
    final baseUrl = cleanIp(ip);
    onLog("Bắt đầu reboot router tại $baseUrl");

    // Step 1: Get MAC address (required for nonce)
    onStep(0);
    onLog("Step 1: Đang quét MAC address của router...");
    final mac = await _getRouterMac(baseUrl, onLog);
    onLog("MAC Address: $mac");

    // Step 2: Generate nonce and hash password
    onStep(1);
    onLog("Step 2: Tạo nonce và mã hóa mật khẩu...");
    final nonce = _generateNonce(mac);
    final passwordHash = _generatePasswordHash(nonce, password);
    onLog("Nonce: $nonce");

    // Step 3: Login to retrieve stok
    onStep(2);
    onLog("Step 3: Đăng nhập để lấy session token (stok)...");
    final Map<String, dynamic> loginData;
    try {
      final loginResponse = await _dio.post(
        "$baseUrl/cgi-bin/luci/api/xqsystem/login",
        data: {
          "username": "admin", //
          "password": passwordHash,
          "logtype": "2",
          "nonce": nonce,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {"User-Agent": _userAgent},
        ),
        cancelToken: cancelToken,
      );
      final raw = loginResponse.data;
      loginData = raw is Map<String, dynamic> ? raw : jsonDecode(raw.toString()) as Map<String, dynamic>;
    } on DioException catch (e) {
      throw RouterRebootException("Không kết nối được tới router: ${e.message ?? e.type.name}");
    } on FormatException {
      throw RouterRebootException("Router trả về dữ liệu không hợp lệ khi đăng nhập.");
    }
    if (loginData["code"] != 0) {
      throw RouterRebootException("Đăng nhập thất bại (code ${loginData["code"]}): ${loginData["msg"] ?? "Sai mật khẩu."}");
    }
    final stok = loginData["token"] as String?;
    if (stok == null || stok.isEmpty) {
      throw RouterRebootException("Đăng nhập thành công nhưng router không trả về session token (stok).");
    }
    onLog("Xác thực thành công! Đã nhận session token.");

    // Step 4: Call reboot endpoint
    onStep(3);
    onLog("Step 4: Gửi lệnh khởi động lại tới router...");
    try {
      final rebootResponse = await _dio.get(
        "$baseUrl/cgi-bin/luci/;stok=$stok/api/xqsystem/reboot",
        queryParameters: {"client": "web"},
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          headers: {"User-Agent": _userAgent},
        ),
        cancelToken: cancelToken,
      );
      onLog("Reboot response: ${rebootResponse.data}");
    } on DioException catch (e) {
      switch (e.type) {
        // Connection reset/timeout is expected: the router drops network interfaces while rebooting
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          onLog("Mất kết nối/timeout — bình thường vì router bắt đầu khởi động lại.");
        case DioExceptionType.cancel:
          rethrow;
        default:
          throw RouterRebootException("Gửi lệnh reboot thất bại: ${e.message ?? e.type.name}");
      }
    }

    onLog("Hoàn tất! Router đang khởi động lại.");
    return "Đã gửi lệnh khởi động lại router thành công!";
  }
}
