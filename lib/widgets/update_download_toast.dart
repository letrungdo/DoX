import 'package:dio/dio.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/services/update_controller.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/widgets/neu/neu_button.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'package:flutter/material.dart';

/// A small fixed toast that shows the background APK download progress and,
/// once finished, an install button. Backed by the global [updateController]
/// so it persists across tab/route changes and app restarts.
class UpdateDownloadToast extends StatelessWidget {
  const UpdateDownloadToast({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: updateController,
      builder: (context, _) {
        if (!updateController.hasActiveToast) {
          return const SizedBox.shrink();
        }
        return _ToastCard(
          phase: updateController.phase,
          progress: updateController.progress,
          version: updateController.update?.version ?? '',
          error: updateController.error,
        );
      },
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.phase,
    required this.progress,
    required this.version,
    required this.error,
  });

  final UpdatePhase phase;
  final double? progress;
  final String version;
  final Object? error;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> {
  /// The remote has to be able to reach Install, and it cannot: the toast
  /// floats at the bottom of a page whose content is a feed, so walking the
  /// D-pad down to it means walking past every article first. The button comes
  /// to the remote instead, the moment there is something to install.
  final _installFocusNode = FocusNode(debugLabel: 'update-install');

  @override
  void didUpdateWidget(_ToastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (deviceType.isTv &&
        widget.phase == UpdatePhase.done &&
        oldWidget.phase != UpdatePhase.done) {
      // After the frame that builds the button — before it, its node has
      // nothing to attach to.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _installFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _installFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isDone = widget.phase == UpdatePhase.done;
    final isError = widget.phase == UpdatePhase.error;

    final String title;
    if (isDone) {
      title = l10n.updateReadyToInstall(widget.version);
    } else if (isError) {
      title = _errorMessage(l10n, widget.error);
    } else {
      title = l10n.downloadingUpdateVersion(widget.version);
    }

    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 4),
      child: NeuCard(
        radius: 12,
        // Floats over the page, so it lifts a little higher than a normal card.
        depth: 1.3,
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            _leadingIcon(scheme, isDone, isError),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isError ? scheme.error : null,
                    ),
                  ),
                  if (!isDone && !isError) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Dimens.radiusTiny),
                      child: LinearProgressIndicator(
                        value: widget.progress,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.progress != null
                          ? "${(widget.progress! * 100).toStringAsFixed(0)}%"
                          : l10n.preparing,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            _trailing(context, l10n, isDone, isError),
          ],
        ),
      ),
    );
  }

  Widget _leadingIcon(ColorScheme scheme, bool isDone, bool isError) {
    if (isError) {
      return Icon(Icons.error_outline, color: scheme.error);
    }
    if (isDone) {
      return Icon(Icons.check_circle, color: scheme.primary);
    }
    return Icon(Icons.system_update, color: scheme.primary);
  }

  Widget _trailing(
    BuildContext context,
    AppLocalizations l10n,
    bool isDone,
    bool isError,
  ) {
    if (isDone) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeuButton(
            focusNode: _installFocusNode,
            onPressed: updateController.install,
            accent: Theme.of(context).colorScheme.primary,
            radius: 12,
            depth: 0.6,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(l10n.install),
          ),
          _closeButton(),
        ],
      );
    }
    if (isError) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: updateController.retry,
            child: Text(l10n.retry),
          ),
          _closeButton(),
        ],
      );
    }
    return _closeButton();
  }

  Widget _closeButton() {
    return IconButton(
      icon: const Icon(Icons.close, size: 20),
      visualDensity: VisualDensity.compact,
      tooltip: null,
      onPressed: updateController.dismiss,
    );
  }

  String _errorMessage(AppLocalizations l10n, Object? error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return l10n.downloadErrorTimeout;
      }
      if (error.response?.statusCode == 404) {
        return l10n.downloadErrorNotFound;
      }
    }
    return l10n.downloadErrorGeneric;
  }
}
