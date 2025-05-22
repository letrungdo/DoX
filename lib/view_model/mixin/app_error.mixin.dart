import 'dart:collection';

import 'package:do_x/repository/client/api_dialog.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:flutter/material.dart';

class ErrorCallback {
  final VoidCallback? onRetry;
  final ConnectionError? error;
  final ValueChanged<ApiErrorType?>? onClose;

  const ErrorCallback({
    this.onRetry, //
    this.error,
    this.onClose,
  });
}

mixin AppErrorMixin {
  final _errorQueues = Queue<ErrorCallback>();

  bool _isShow = false;

  Future<void> showAppError(
    BuildContext context,
    ConnectionError? error, {
    VoidCallback? onRetry,
    ValueChanged<ApiErrorType?>? onClose,
  }) async {
    if (error == null || error.type == ApiErrorType.cancel || !context.mounted) return;

    _errorQueues.add(ErrorCallback(onRetry: onRetry, error: error, onClose: onClose));

    if (_isShow) {
      return;
    }
    _isShow = true;
    await ApiDialog.showAppError(
      context,
      error,
      onRetry: () {
        while (_errorQueues.isNotEmpty) {
          final item = _errorQueues.removeFirst();
          item.onRetry?.call();
        }
      },
      onClose: (type) {
        while (_errorQueues.isNotEmpty) {
          final item = _errorQueues.removeFirst();
          item.onClose?.call(type);
        }
      },
    );
    _isShow = false;
  }

  void showErrorMessage(BuildContext context, {required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), //
      ),
    );
  }
}
