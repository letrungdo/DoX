import 'package:do_x/services/update_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:do_x/widgets/dialog/dialog_action_button.dart';
import 'package:flutter/material.dart';

class MainViewModel extends CoreViewModel {
  final Map<String, Future<void> Function()> _tabReselectHandlers = {};
  final Set<String> _tabsBeingReselected = {};

  void registerTabReselectHandler(
    String routeName,
    Future<void> Function() handler,
  ) {
    _tabReselectHandlers[routeName] = handler;
  }

  void unregisterTabReselectHandler(
    String routeName,
    Future<void> Function() handler,
  ) {
    if (identical(_tabReselectHandlers[routeName], handler)) {
      _tabReselectHandlers.remove(routeName);
    }
  }

  Future<void> handleTabReselect(String routeName) async {
    if (!_tabsBeingReselected.add(routeName)) return;
    try {
      await _tabReselectHandlers[routeName]?.call();
    } finally {
      _tabsBeingReselected.remove(routeName);
    }
  }

  @override
  void initData() {
    super.initData();
    _checkAppUpdate();
  }

  void _checkAppUpdate() async {
    final update = await updateService.checkForUpdate();
    if (update == null || !context.mounted) return;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Có bản cập nhật mới v${update.version}"),
        content: update.releaseNotes?.trim().isNotEmpty == true
            ? SingleChildScrollView(child: Text(update.releaseNotes!))
            : null,
        actions: [
          DialogActionButton(
            text: "Để sau",
            kind: DialogActionKind.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          DialogActionButton(
            text: "Cập nhật",
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (shouldUpdate != true || !context.mounted) return;

    await _downloadAndInstall(update);
  }

  Future<void> _downloadAndInstall(AppUpdateInfo update) async {
    final progress = ValueNotifier<double?>(null);
    final error = ValueNotifier<Object?>(null);
    final isDone = ValueNotifier<bool>(false);

    bool isDialogVisible = true;

    Future<void> runDownload() async {
      try {
        error.value = null;
        isDone.value = false;
        progress.value = null;

        await updateService.downloadAndInstall(
          update,
          onReceiveProgress: (received, total) {
            if (total > 0) progress.value = received / total;
          },
        );

        isDone.value = true;
        await Future.delayed(const Duration(seconds: 1));
        if (isDialogVisible && context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      } catch (e) {
        if (isDialogVisible) {
          error.value = e;
        }
      }
    }

    runDownload();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Cập nhật ứng dụng"),
        content: ValueListenableBuilder<Object?>(
          valueListenable: error,
          builder: (context, errorValue, _) {
            if (errorValue != null) {
              return Text(
                "Lỗi tải bản cập nhật: $errorValue",
                style: const TextStyle(color: Colors.red),
              );
            }
            return ValueListenableBuilder<bool>(
              valueListenable: isDone,
              builder: (context, done, _) {
                if (done) {
                  return const Text("Tải hoàn tất, đang mở trình cài đặt...");
                }
                return ValueListenableBuilder<double?>(
                  valueListenable: progress,
                  builder: (context, value, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Đang tải bản cập nhật..."),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: value),
                      const SizedBox(height: 8),
                      Text(
                        value != null
                            ? "${(value * 100).toStringAsFixed(0)}%"
                            : "Đang chuẩn bị...",
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        actions: [
          ValueListenableBuilder<Object?>(
            valueListenable: error,
            builder: (context, errorValue, _) => errorValue != null
                ? DialogActionButton(text: "Thử lại", onPressed: runDownload)
                : const SizedBox.shrink(),
          ),
          DialogActionButton(
            text: "Đóng",
            kind: DialogActionKind.cancel,
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(),
          ),
        ],
      ),
    );
    isDialogVisible = false;
  }
}
