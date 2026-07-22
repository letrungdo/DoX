import 'package:dio/dio.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/services/update_controller.dart';
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

class _ToastCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isDone = phase == UpdatePhase.done;
    final isError = phase == UpdatePhase.error;

    final String title;
    if (isDone) {
      title = l10n.updateReadyToInstall(version);
    } else if (isError) {
      title = _errorMessage(l10n, error);
    } else {
      title = l10n.downloadingUpdateVersion(version);
    }

    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 4),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: scheme.surfaceContainerHigh,
        child: Padding(
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
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        progress != null
                            ? "${(progress! * 100).toStringAsFixed(0)}%"
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
          FilledButton(
            onPressed: updateController.install,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              visualDensity: VisualDensity.compact,
            ),
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
