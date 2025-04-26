import 'package:do_ai/extensions/context_extensions.dart';
import 'package:do_ai/extensions/string_extensions.dart';
import 'package:do_ai/repository/client/error_handler.dart';
import 'package:do_ai/utils/app_dialog.dart';
import 'package:flutter/material.dart';

class ApiDialog {
  const ApiDialog._();

  static Future<void> showAppError(
    BuildContext context,
    ConnectionError error, {
    VoidCallback? onRetry,
    ValueChanged<ApiErrorType?>? onClose,
    bool isGetSymbolAll = false,
    bool isMainWindow = false,
  }) async {
    final closeAction = ActionProps(
      onPressed: (context) async {
        onClose?.call(error.type);
      },
      text: context.l10n.close,
    );
    List<ActionProps> genActions({bool alwayShowRetry = true}) {
      return [
        closeAction,
        if (alwayShowRetry)
          ActionProps(
            onPressed: (context) async {
              onRetry?.call();
            },
            text: context.l10n.retry,
          ),
      ];
    }

    String? title;
    String? message;
    List<ActionProps>? actions;

    switch (error.type) {
      case ApiErrorType.businessError:
        title = context.l10n.error;
        message = error.message;
        actions = genActions(alwayShowRetry: isGetSymbolAll);
        break;
      case ApiErrorType.maintenance:
        message = context.l10n.meSystemMaintenance;
        actions = genActions();
        break;
      case ApiErrorType.other:
        message = error.message.withStatusCode(error.statusCode);
        actions = genActions(alwayShowRetry: false);
        break;
      case ApiErrorType.sessionTimeout:
        title = context.l10n.error;
        message = error.message;
        // TODO: logout
        break;
      case ApiErrorType.requestTimeout:
        message = context.l10n.meRequestTimeout;
        actions = genActions();
        break;
      case ApiErrorType.networkError:
        message = context.l10n.meNetworkError;
        actions = genActions();
        break;
      case ApiErrorType.unknownError:
      default:
        message = error.message.withStatusCode(error.statusCode);
        actions = [closeAction];
        break;
    }
    if (!context.mounted) return;

    final action = await showAppDialog(context, title: title, message: message, actions: actions);
    if (action == ActionButtonType.cancel) {
      onClose?.call(ApiErrorType.cancel);
    }
  }
}
