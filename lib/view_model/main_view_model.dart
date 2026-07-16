import 'package:do_x/services/update_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';

class MainViewModel extends CoreViewModel {
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Để sau")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Cập nhật")),
        ],
      ),
    );
    if (shouldUpdate != true || !context.mounted) return;

    await _downloadAndInstall(update);
  }

  Future<void> _downloadAndInstall(AppUpdateInfo update) async {
    final progress = ValueNotifier<double?>(null);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Đang tải bản cập nhật..."),
        content: ValueListenableBuilder<double?>(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value),
              const SizedBox(height: 8),
              Text(value != null ? "${(value * 100).toStringAsFixed(0)}%" : ""),
            ],
          ),
        ),
      ),
    );

    try {
      await updateService.downloadAndInstall(
        update,
        onReceiveProgress: (received, total) {
          if (total > 0) progress.value = received / total;
        },
      );
      _closeProgressDialog();
    } catch (e) {
      _closeProgressDialog();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi tải bản cập nhật: $e")));
    }
  }

  void _closeProgressDialog() {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }
}
