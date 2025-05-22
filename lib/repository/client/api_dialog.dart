import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/string_extensions.dart';
import 'package:do_x/repository/client/error_handler.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/utils/app_dialog.dart';
import 'package:flutter/material.dart';

class ApiDialog {
  const ApiDialog._();

  static Future<void> showAppError(
    BuildContext context,
    ConnectionError error, {
    VoidCallback? onRetry,
    ValueChanged<ApiErrorType?>? onClose,
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

    String title = context.l10n.error;
    String? message;
    List<ActionProps>? actions;

    switch (error.type) {
      case ApiErrorType.sessionTimeout:
      case ApiErrorType.unauthorized:
        title = context.l10n.sessionExpired;
        message = context.l10n.pleaseLoginAgain;
        actions = [
          ActionProps(
            onPressed: (context) async {
              context.replaceRoute(const LoginRoute());
            },
            text: context.l10n.logout,
          ),
        ];
        break;
      case ApiErrorType.businessError:
        title = context.l10n.error;
        message = error.message;
        actions = genActions();
        break;
      case ApiErrorType.maintenance:
        message = context.l10n.meSystemMaintenance;
        actions = genActions();
        break;
      case ApiErrorType.requestTimeout:
        message = context.l10n.meRequestTimeout;
        actions = genActions();
        break;
      case ApiErrorType.networkError:
        message = context.l10n.meNetworkError;
        actions = genActions();
        break;
      case ApiErrorType.other:
      default:
        title = context.l10n.error;
        message = (error.message ?? context.l10n.anErrorOccurred).withStatusCode(error.statusCode);
        actions = [closeAction];
        break;
    }
    if (!context.mounted) return;

    final action = await showAppDialog(
      context, //
      title: title,
      message: message,
      actions: actions,
    );
    if (action == ActionButtonType.cancel) {
      onClose?.call(ApiErrorType.cancel);
    }
  }
}
