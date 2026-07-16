import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/view_model/reboot_router_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:provider/provider.dart';

@RoutePage()
class RebootRouterScreen extends StatefulScreen implements AutoRouteWrapper {
  const RebootRouterScreen({super.key});

  @override
  State<RebootRouterScreen> createState() => _RebootRouterScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RebootRouterViewModel(), //
      child: this,
    );
  }
}

class _RebootRouterScreenState<V extends RebootRouterViewModel> extends ScreenState<RebootRouterScreen, V> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DoAppBar(title: "Reboot Router Xiaomi R3G"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        child: Consumer<V>(
          builder: (context, vm, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                _buildHeader(),
                DoTextField(
                  labelText: "Địa chỉ IP Router",
                  placeholder: "http://192.168.2.35",
                  value: vm.ip,
                  keyboardType: TextInputType.url,
                  onChanged: vm.setIp,
                ),
                DoTextField(
                  labelText: "Mật khẩu Admin",
                  obscureText: !vm.showPassword,
                  value: vm.password,
                  onChanged: vm.setPassword,
                  decoration: InputDecoration(
                    labelText: "Mật khẩu Admin",
                    helperText: "Mật khẩu đăng nhập trang quản trị router (MiWiFi)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20), //
                    ),
                    suffixIcon: IconButton(
                      onPressed: vm.togglePasswordVisible,
                      icon: SFIcon(vm.showPassword ? SFIcons.sf_eye_slash : SFIcons.sf_eye, fontSize: 18),
                    ),
                  ),
                ),
                if (vm.isBusy || vm.activeStep >= 0) _buildSteps(vm),
                if (vm.successMessage != null) _buildAlert(vm.successMessage!, isError: false),
                if (vm.errorMessage != null) _buildAlert(vm.errorMessage!, isError: true),
                DoButton(
                  isBusy: vm.isBusy,
                  onPressed: vm.reboot,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      SFIcon(SFIcons.sf_arrow_counterclockwise),
                      Text(vm.isBusy ? "Đang xử lý khởi động lại..." : "Khởi động lại Router Xiaomi"),
                    ],
                  ),
                ),
                if (vm.logs.isNotEmpty) _buildLogs(vm),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        spacing: 12,
        children: [
          const SFIcon(SFIcons.sf_wifi, color: Colors.white, fontSize: 36),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bảng Điều Khiển Router",
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Khởi động lại thiết bị của bạn từ xa một cách nhanh chóng và an toàn",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps(V vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text("Tiến trình thực hiện:", style: context.theme.textTheme.bodySmall),
        for (final (index, label) in RebootRouterViewModel.stepLabels.indexed) //
          _buildStepRow(vm, index, label),
      ],
    );
  }

  Widget _buildStepRow(V vm, int index, String label) {
    final isFailed = vm.errorMessage != null && vm.activeStep == index;
    final isDone = vm.activeStep > index && !isFailed;
    final isRunning = vm.isBusy && vm.activeStep == index;

    final color = isFailed
        ? context.theme.colorScheme.error
        : isDone
        ? Colors.green
        : context.theme.colorScheme.onSurface.withValues(alpha: isRunning ? 1 : 0.4);

    return Row(
      spacing: 8,
      children: [
        SizedBox.square(
          dimension: 18,
          child: isRunning
              ? const CircularProgressIndicator.adaptive(strokeWidth: 2)
              : SFIcon(
                  isFailed
                      ? SFIcons.sf_xmark_circle_fill
                      : isDone
                      ? SFIcons.sf_checkmark_circle_fill
                      : SFIcons.sf_circle,
                  color: color,
                  fontSize: 16,
                ),
        ),
        Text("${index + 1}. $label", style: TextStyle(color: color)),
      ],
    );
  }

  Widget _buildAlert(String message, {required bool isError}) {
    final color = isError ? context.theme.colorScheme.error : Colors.green;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isError ? "Lỗi!" : "Thành công!",
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          Text(message, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildLogs(V vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: vm.toggleShowLogs,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const SFIcon(SFIcons.sf_apple_terminal, fontSize: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("Nhật ký chi tiết (Console Log)", style: context.theme.textTheme.bodySmall),
                ),
                SFIcon(vm.showLogs ? SFIcons.sf_chevron_up : SFIcons.sf_chevron_down, fontSize: 14),
              ],
            ),
          ),
        ),
        if (vm.showLogs)
          Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              border: Border.all(color: const Color(0xFF333333)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final log in vm.logs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: "monospace",
                          fontSize: 12,
                          color: log.contains("Lỗi") || log.contains("thất bại")
                              ? const Color(0xFFF44336)
                              : log.contains("thành công") || log.contains("Hoàn tất")
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFD4D4D4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
