import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Silently replays a request a few times on a transient network failure
/// (e.g. the app just resumed from background before connectivity is ready)
/// before letting the error propagate to the caller / error dialog.
///
/// Timeouts, bad HTTP responses and user cancellations are intentionally not
/// retried.
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

  bool _isRetriable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return true;
      case DioExceptionType.unknown:
        return err.error is SocketException;
      default:
        return false;
    }
  }
}
