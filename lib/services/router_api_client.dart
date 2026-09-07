import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:do_x/repository/client/http_client_adapter.dart';
import 'package:flutter/foundation.dart';

/// Why a router call failed, so the UI can localize the message instead of
/// showing whatever the router happened to say.
enum RouterApiError {
  /// The router could not be reached at all.
  unreachable,

  /// The admin password is empty or rejected.
  auth,

  /// The router answered, but not with the JSON we expect.
  malformed,

  /// The router answered with a non-zero `code`.
  rejected,
}

class RouterApiException implements Exception {
  RouterApiException(this.error, {this.detail, this.code});

  final RouterApiError error;

  /// Raw router text, for the debug console only — never shown as a label.
  final String? detail;
  final int? code;

  @override
  String toString() => "RouterApiException(${error.name}, $code, $detail)";
}

/// Shared transport for the Xiaomi MiWiFi (R3G) web API: MAC scrape, the sha1
/// challenge-response login and authenticated `;stok=` calls.
///
/// One instance keeps one session token, so a screen that makes several calls
/// logs in once and reuses the token until the router expires it.
class RouterApiClient {
  static const _key = "a2ffa5c9be07488bbb04a3a47d3c5f6a";
  static const _fallbackMac = "00:11:22:33:44:55";
  static const _userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) DoXRouterUtility";

  // A bare Dio without the app's BaseInterceptor, which force-overrides every
  // request's Content-Type to application/json — that breaks the router's
  // form-urlencoded login parsing and makes it return "Invalid token".
  final Dio _dio = () {
    final dio = Dio();
    if (!kIsWeb) dio.httpClientAdapter = httpClientAdapter;
    return dio;
  }();

  String? _stok;
  String? _sessionBaseUrl;

  /// The token of the current session, if [login] has succeeded.
  String? get stok => _stok;

  void clearSession() {
    _stok = null;
    _sessionBaseUrl = null;
  }

  String cleanIp(String ip) {
    var cleaned = ip.trim();
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(cleaned)) {
      cleaned = "http://$cleaned";
    }
    return cleaned.replaceAll(RegExp(r'/+$'), '');
  }

  String sha1Hex(String text) => sha1.convert(utf8.encode(text)).toString();

  /// The router puts its own MAC in the login page markup. It only seeds the
  /// nonce identifier, which the router does not validate, so a miss is fine.
  Future<String> getRouterMac(
    String baseUrl, {
    void Function(String message)? onLog,
  }) async {
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
    } catch (e) {
      onLog?.call("Không quét được MAC, dùng MAC mặc định. ($e)");
    }
    return _fallbackMac;
  }

  String generateNonce(String mac) {
    const miwifiType = 0;
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final randomInt = Random().nextInt(10000);
    return "${miwifiType}_${mac}_${timestamp}_$randomInt";
  }

  String generatePasswordHash(String nonce, String password) {
    return sha1Hex(nonce + sha1Hex(password + _key));
  }

  /// Exchange the admin password for a session token, which is remembered on
  /// this client. Returns the token.
  Future<String> login({
    required String ip,
    required String password,
    String? nonce,
    void Function(String message)? onLog,
    CancelToken? cancelToken,
  }) async {
    if (password.isEmpty) {
      throw RouterApiException(RouterApiError.auth);
    }
    final baseUrl = cleanIp(ip);
    final loginNonce =
        nonce ?? generateNonce(await getRouterMac(baseUrl, onLog: onLog));
    final passwordHash = generatePasswordHash(loginNonce, password);

    // The form body is encoded by hand to match the browser's
    // URLSearchParams output, which is what the router's parser expects.
    final body =
        {
              "username": "admin", //
              "password": passwordHash,
              "logtype": "2",
              "nonce": loginNonce,
            }.entries
            .map(
              (entry) =>
                  "${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}",
            )
            .join("&");

    final Map<String, dynamic> data;
    try {
      final response = await _dio.post(
        "$baseUrl/cgi-bin/luci/api/xqsystem/login",
        data: body,
        options: Options(
          contentType: "application/x-www-form-urlencoded",
          headers: {"User-Agent": _userAgent},
          receiveTimeout: const Duration(seconds: 6),
        ),
        cancelToken: cancelToken,
      );
      data = jsonMap(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw RouterApiException(
        RouterApiError.unreachable,
        detail: e.message ?? e.type.name,
      );
    } on FormatException catch (e) {
      throw RouterApiException(RouterApiError.malformed, detail: e.message);
    }

    final code = data["code"];
    final token = data["token"]?.toString();
    if (code != 0 || token == null || token.isEmpty) {
      throw RouterApiException(
        RouterApiError.auth,
        code: code is int ? code : null,
        detail: data["msg"]?.toString(),
      );
    }

    _stok = token;
    _sessionBaseUrl = baseUrl;
    onLog?.call("Xác thực thành công! Đã nhận session token.");
    return token;
  }

  /// Call an authenticated endpoint such as `api/xqnetwork/wifi_list`.
  ///
  /// [login] must have run first. A `401 Invalid token` reply clears the
  /// session so the caller can log in again.
  Future<Map<String, dynamic>> apiGet(
    String path, {
    Map<String, dynamic>? query,
    Duration timeout = const Duration(seconds: 10),
    CancelToken? cancelToken,
    void Function(String message)? onLog,
  }) async {
    final stok = _stok;
    final baseUrl = _sessionBaseUrl;
    if (stok == null || baseUrl == null) {
      throw RouterApiException(RouterApiError.auth);
    }

    final Map<String, dynamic> data;
    try {
      final response = await _dio.get(
        "$baseUrl/cgi-bin/luci/;stok=$stok/$path",
        queryParameters: query,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: timeout,
          headers: {"User-Agent": _userAgent},
        ),
        cancelToken: cancelToken,
      );
      data = jsonMap(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw RouterApiException(
        RouterApiError.unreachable,
        detail: e.message ?? e.type.name,
      );
    } on FormatException catch (e) {
      throw RouterApiException(RouterApiError.malformed, detail: e.message);
    }

    onLog?.call("$path -> $data");
    final code = data["code"];
    if (code == 401) {
      clearSession();
      throw RouterApiException(RouterApiError.auth, code: 401);
    }
    return data;
  }

  /// Call an authenticated endpoint that takes a form body, such as
  /// `api/xqnetwork/set_wifi_ap`.
  Future<Map<String, dynamic>> apiPost(
    String path,
    Map<String, String> form, {
    Duration timeout = const Duration(seconds: 30),
    CancelToken? cancelToken,
    void Function(String message)? onLog,
  }) async {
    final stok = _stok;
    final baseUrl = _sessionBaseUrl;
    if (stok == null || baseUrl == null) {
      throw RouterApiException(RouterApiError.auth);
    }

    final body = form.entries
        .map(
          (entry) =>
              "${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}",
        )
        .join("&");

    final Map<String, dynamic> data;
    try {
      final response = await _dio.post(
        "$baseUrl/cgi-bin/luci/;stok=$stok/$path",
        data: body,
        options: Options(
          contentType: "application/x-www-form-urlencoded",
          responseType: ResponseType.plain,
          receiveTimeout: timeout,
          headers: {"User-Agent": _userAgent},
        ),
        cancelToken: cancelToken,
      );
      data = jsonMap(response.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw RouterApiException(
        RouterApiError.unreachable,
        detail: e.message ?? e.type.name,
      );
    } on FormatException catch (e) {
      throw RouterApiException(RouterApiError.malformed, detail: e.message);
    }

    onLog?.call("$path -> $data");
    final code = data["code"];
    if (code == 401) {
      clearSession();
      throw RouterApiException(RouterApiError.auth, code: 401);
    }
    return data;
  }

  Map<String, dynamic> jsonMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    final decoded = jsonDecode(value.toString());
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException("Router did not answer with a JSON object");
  }
}
