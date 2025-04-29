import 'dart:collection';

import 'package:do_x/repository/client/api_dialog.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:flutter/material.dart';

class ErrorCallback {
  final VoidCallback? onRetry;
  final ConnectionError? error;
  final ValueChanged<ApiErrorType?>? onClose;
  final bool isGetSymbolAll;
  final bool checkUpdateHeight;

  const ErrorCallback({
    this.onRetry, //
    this.error,
    this.onClose,
    this.isGetSymbolAll = false,
    this.checkUpdateHeight = false,
  });
}

mixin AppErrorMixin {
  final _errorQueues = Queue<ErrorCallback>();

  bool _isShow = false;

  Future<void> showAppError(
    BuildContext context,
    ConnectionError? error, {
    GlobalKey? gKey,
    VoidCallback? onRetry,
    ValueChanged<ApiErrorType?>? onClose,
    bool isGetSymbolAll = false,
    //Check update height for small screen
    bool checkUpdateHeight = false,
    bool isMainWindow = false,
  }) async {
    if (error == null || error.type == ApiErrorType.cancel || !context.mounted) return;

    if (!context.mounted) return;

    if (_isShow) {
      _errorQueues.add(
        ErrorCallback(
          onRetry: onRetry,
          error: error,
          onClose: onClose,
          isGetSymbolAll: isGetSymbolAll,
          checkUpdateHeight: checkUpdateHeight,
        ),
      );
      return;
    }
    _isShow = true;
    await ApiDialog.showAppError(
      context,
      error,
      isGetSymbolAll: isGetSymbolAll,
      onRetry: onRetry,
      onClose: onClose,
      isMainWindow: isMainWindow,
    );
    _isShow = false;
    if (_errorQueues.isNotEmpty) {
      final item = _errorQueues.removeFirst();
      if (!context.mounted) return;
      showAppError(
        context,
        item.error,
        gKey: gKey,
        onClose: item.onClose,
        onRetry: item.onRetry,
        isGetSymbolAll: item.isGetSymbolAll,
        checkUpdateHeight: item.checkUpdateHeight,
        isMainWindow: isMainWindow,
      );
    }
  }
}
