import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:do_x/repository/client/http_client_adapter.dart';
import 'package:flutter/foundation.dart';

class RouterRebootException implements Exception {
  RouterRebootException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reboot Xiaomi Router (R3G / MiWiFi) via web api:
/// scrape MAC from login page -> generate nonce ->
/// sha1 challenge-response login -> stok -> reboot.
/// Mirrors the proven web implementation exactly.
class RouterRebootService {
  static const _key = "a2ffa5c9be07488bbb04a3a47d3c5f6a";
  static const _fallbackMac = "00:11:22:33:44:55";
  static const _userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) DoXRebootUtility";

  // A bare Dio without the app's BaseInterceptor, which force-overrides every
  // request's Content-Type to application/json — that breaks the router's
  // form-urlencoded login parsing and makes it return "Invalid token".
  final Dio _dio = () {
    final dio = Dio();
    if (!kIsWeb) dio.httpClientAdapter = httpClientAdapter;
    return dio;
  }();

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
      if (match != null) return match.group(0)!;
    } catch (e) {
      onLog("Không quét được MAC, dùng MAC mặc định. ($e)");
    }
    // The nonce identifier is not validated by the router, so a fallback is fine.
    return _fallbackMac;
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

    if (password.isEmpty) {
      throw RouterRebootException("Mật khẩu đang trống. Hãy nhập mật khẩu trang quản trị router rồi thử lại.");
    }

    // Step 1: Get MAC address (used in the login nonce)
    onStep(0);
    onLog("Step 1: Đang quét MAC address của router...");
    final mac = await _getRouterMac(baseUrl, onLog);
    onLog("MAC Address: $mac");

    // Step 2: Generate nonce and hash password
    onStep(1);
    onLog("Step 2: Tạo nonce và mã hóa mật khẩu... (mật khẩu dài ${password.length} ký tự)");
    final nonce = _generateNonce(mac);
    final passwordHash = _generatePasswordHash(nonce, password);
    onLog("Nonce: $nonce");

    // Step 3: Login to retrieve stok.
    // The form body is encoded by hand to match the browser's URLSearchParams output.
    onStep(2);
    onLog("Step 3: Đăng nhập để lấy session token (stok)...");
    final Map<String, dynamic> loginData;
    try {
      final body = {
        "username": "admin", //
        "password": passwordHash,
        "logtype": "2",
        "nonce": nonce,
      }.entries.map((e) => "${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}").join("&");

      final response = await _dio.post(
        "$baseUrl/cgi-bin/luci/api/xqsystem/login",
        data: body,
        options: Options(
          contentType: "application/x-www-form-urlencoded",
          headers: {"User-Agent": _userAgent},
        ),
        cancelToken: cancelToken,
      );
      final raw = response.data;
      loginData = raw is Map<String, dynamic> ? raw : jsonDecode(raw.toString()) as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw RouterRebootException("Không kết nối được tới router: ${e.message ?? e.type.name}");
    } on FormatException {
      throw RouterRebootException("Router trả về dữ liệu không hợp lệ khi đăng nhập.");
    }

    if (loginData["code"] != 0) {
      final msg = loginData["msg"]?.toString() ?? "sai mật khẩu";
      throw RouterRebootException(
        "Đăng nhập thất bại (code ${loginData["code"]}): $msg. Kiểm tra lại mật khẩu trang quản trị router.",
      );
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

  /// Periodically check if the router is back online after a reboot.
  Future<void> checkRouterOnline({
    required String ip,
    required void Function(String message) onLog,
    CancelToken? cancelToken,
  }) async {
    final baseUrl = cleanIp(ip);
    onLog("Đang chờ router khởi động lại... (thường mất 1-2 phút)");

    // Give the router some time to actually shut down services before we start polling.
    await Future.delayed(const Duration(seconds: 20));

    int retryCount = 0;
    while (true) {
      if (cancelToken?.isCancelled == true) return;
      retryCount++;

      try {
        final response = await _dio.get(
          "$baseUrl/cgi-bin/luci/web/home",
          options: Options(
            receiveTimeout: const Duration(seconds: 3),
            headers: {"User-Agent": _userAgent},
          ),
          cancelToken: cancelToken,
        );

        if (response.statusCode == 200) {
          onLog("Router đã phản hồi sau $retryCount lần thử. Đã khởi động xong!");
          return;
        }
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
        onLog("Lần thử $retryCount: Router chưa sẵn sàng...");
      }

      // Poll every 5 seconds
      await Future.delayed(const Duration(seconds: 5));
    }
  }
}
