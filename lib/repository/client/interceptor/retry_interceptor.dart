import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Silently replays a request a few times on a transient network failure
/// (e.g. the app just resumed from background before connectivity is ready)
/// before letting the error propagate to the caller / error dialog.
///
/// Connection errors, timeouts and flaky server responses (5xx) are retried.
/// User cancellations and client errors (4xx) are not — replaying them can't
/// change the outcome.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxRetries = 2,
    this.retryDelay = const Duration(seconds: 1),
  });

  /// The client used to replay the failed request.
  final Dio _dio;

  /// Number of silent retries before the error is surfaced.
  final int maxRetries;

  /// Delay between silent retries.
  final Duration retryDelay;

  static const _retryKey = 'retry_attempt';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_isRetriable(err)) {
      final options = err.requestOptions;
      final attempt = (options.extra[_retryKey] as int?) ?? 0;
      if (attempt < maxRetries) {
        options.extra[_retryKey] = attempt + 1;
        debugPrint('Network error, silent retry ${attempt + 1}/$maxRetries => URL: ${options.uri}');
        await Future.delayed(retryDelay);
        try {
          final response = await _dio.fetch(options);
          return handler.resolve(response);
        } on DioException catch (e) {
          return handler.next(e);
        }
      }
    }
    super.onError(err, handler);
  }

  /// Methods that may have already changed state on the server, so a replay
  /// could duplicate the effect.
  static const _unsafeMethods = {'POST', 'PATCH'};

  bool _isRetriable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return true;
      case DioExceptionType.unknown:
        return err.error is SocketException;
      // Timeouts and 5xx leave it unknown whether the server already applied
      // the request, so only replay them for safe methods.
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return _isSafeMethod(err);
      case DioExceptionType.badResponse:
        if (!_isSafeMethod(err)) return false;
        final statusCode = err.response?.statusCode ?? 0;
        // 501 means the endpoint will never work, replaying won't help.
        return statusCode >= 500 && statusCode != HttpStatus.notImplemented;
      default:
        return false;
    }
  }

  bool _isSafeMethod(DioException err) => !_unsafeMethods.contains(err.requestOptions.method.toUpperCase());
}
