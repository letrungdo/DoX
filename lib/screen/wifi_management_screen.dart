import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/speed_test_service.dart';
import 'package:do_x/view_model/wifi_management_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:provider/provider.dart';

@RoutePage()
class WifiManagementScreen extends StatefulScreen implements AutoRouteWrapper {
  const WifiManagementScreen({super.key});

  @override
  State<WifiManagementScreen> createState() => _WifiManagementScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WifiManagementViewModel(), //
      child: this,
    );
  }
}

class _WifiManagementScreenState<V extends WifiManagementViewModel> extends ScreenState<WifiManagementScreen, V> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DoAppBar(title: l10n.wifiManagement),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        child: Consumer<V>(
          builder: (context, vm, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                _buildHeader(l10n),
                _buildConfigSection(l10n, vm),
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
                      const SFIcon(SFIcons.sf_arrow_counterclockwise),
                      Text(vm.isBusy ? "Đang xử lý..." : l10n.rebootRouterXiaomi),
                    ],
                  ),
                ),
                const Divider(height: 32),
                _buildSpeedTestSection(l10n, vm),
                if (vm.logs.isNotEmpty) _buildLogs(vm),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
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
      child: const Row(
        spacing: 12,
        children: [
          SFIcon(SFIcons.sf_wifi, color: Colors.white, fontSize: 36),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Đo tốc độ mạng và quản lý thiết bị router của bạn",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedTestSection(AppLocalizations l10n, V vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Kiểm tra tốc độ kết nối", style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            _buildServerPicker(vm),
          ],
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: _buildSpeedCard(
                title: l10n.lanSpeed,
                subtitle: vm.ip.replaceAll(RegExp(r'https?://'), ''),
                speed: vm.lanSpeed,
                latency: vm.lanLatency,
                isTesting: vm.isTestingLan,
                onTap: vm.testLanSpeed,
                icon: SFIcons.sf_network,
                color: Colors.blue,
                l10n: l10n,
              ),
            ),
            Expanded(
              child: _buildSpeedCard(
                title: l10n.internetSpeed,
                subtitle: vm.selectedServer.name,
                speed: vm.internetSpeed,
                latency: vm.internetLatency,
                isTesting: vm.isTestingInternet,
                onTap: vm.testInternetSpeed,
                icon: SFIcons.sf_globe,
                color: Colors.green,
                l10n: l10n,
              ),
            ),
          ],
        ),
        if (vm.lanSpeed != null && vm.internetSpeed != null && !vm.isTestingLan && !vm.isTestingInternet)
          _buildSpeedAnalysis(vm.lanSpeed!, vm.internetSpeed!),
      ],
    );
  }

  Widget _buildServerPicker(V vm) {
    return PopupMenuButton<SpeedTestServer>(
      initialValue: vm.selectedServer,
      onSelected: vm.setSelectedServer,
      tooltip: "Chọn máy chủ đo internet",
      itemBuilder: (context) => SpeedTestServer.internetServers.map((server) {
        return PopupMenuItem(
          value: server,
          child: Row(
            spacing: 8,
            children: [
              if (vm.selectedServer == server) const Icon(Icons.check, size: 16, color: Colors.green),
              Text(server.name, style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: context.theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dns_outlined, size: 14),
            const SizedBox(width: 4),
            Text("Máy chủ", style: context.theme.textTheme.labelSmall),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedCard({
    required String title,
    String? subtitle,
    required double? speed,
    required int? latency,
    required bool isTesting,
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    required AppLocalizations l10n,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isTesting ? color : color.withValues(alpha: 0.3), width: isTesting ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SFIcon(icon, color: color, fontSize: 24),
                if (isTesting)
                  const SizedBox(
                    height: 36,
                    width: 32,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 42,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    speed != null && (speed > 0 || isTesting) ? l10n.speedMbps(speed.toStringAsFixed(1)) : "--",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.theme.colorScheme.onSurface),
                  ),
                  if (latency != null)
                    Text(
                      "Ping: ${latency}ms",
                      style: TextStyle(fontSize: 11, color: context.theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isTesting ? "STOP" : l10n.startSpeedTest,
              style: TextStyle(
                fontSize: 10,
                color: isTesting ? Colors.red : context.theme.colorScheme.onSurfaceVariant,
                fontWeight: isTesting ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedAnalysis(double lan, double internet) {
    String analysis;
    Color color;
    if (lan < 10) {
      analysis = "Kết nối LAN rất yếu. Hãy kiểm tra lại dây mạng hoặc khoảng cách tới repeater.";
      color = Colors.red;
    } else if (lan > 50 && internet < 10) {
      analysis = "Kết nối LAN tốt, nhưng Internet chậm. Vấn đề có thể từ nhà cung cấp mạng hoặc router chính.";
      color = Colors.orange;
    } else if (lan > 50 && internet > 50) {
      analysis = "Mạng hoạt động hoàn hảo!";
      color = Colors.green;
    } else {
      analysis = "Tốc độ mạng ổn định.";
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        spacing: 8,
        children: [
          Icon(Icons.analytics_outlined, color: color, size: 20),
          Expanded(child: Text(analysis, style: TextStyle(fontSize: 12, color: color))),
        ],
      ),
    );
  }

  Widget _buildConfigSection(AppLocalizations l10n, V vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text("Cấu hình thiết bị", style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        DoTextField(
          labelText: l10n.routerIpAddress,
          placeholder: "http://192.168.2.35",
          value: vm.ip,
          keyboardType: TextInputType.url,
          onChanged: vm.setIp,
        ),
        DoTextField(
          labelText: l10n.adminPassword,
          obscureText: !vm.showPassword,
          value: vm.password,
          onChanged: vm.setPassword,
          decoration: InputDecoration(
            labelText: l10n.adminPassword,
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
      ],
    );
  }

  Widget _buildSteps(V vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text("Tiến trình thực hiện:", style: context.theme.textTheme.bodySmall),
        for (final (index, label) in WifiManagementViewModel.stepLabels.indexed) //
          _buildStepRow(vm, index, label),
        if (vm.isWaitingForOnline) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              // Estimate 90s for a full reboot cycle
              value: (vm.elapsedSeconds / 90).clamp(0.0, 0.99),
              minHeight: 6,
              backgroundColor: context.theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                vm.isTakingTooLong ? Colors.orange : context.theme.colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    vm.isTakingTooLong
                        ? "Vẫn chưa thấy router phản hồi (${vm.elapsedSeconds}s)..."
                        : "Đang kết nối lại... (Ước tính ~90 giây)",
                    style: context.theme.textTheme.labelSmall?.copyWith(
                      color: vm.isTakingTooLong ? Colors.orange : context.theme.colorScheme.primary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: vm.skipWaiting,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text("Bỏ qua chờ", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          if (vm.isTakingTooLong)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Lưu ý: Nếu router đã đổi IP hoặc đèn đã báo xanh, bạn có thể bỏ qua bước này.",
                style: context.theme.textTheme.bodySmall?.copyWith(fontSize: 10, fontStyle: FontStyle.italic),
              ),
            ),
        ],
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
        Expanded(child: Text("${index + 1}. $label", style: TextStyle(color: color))),
        if (isRunning && vm.isWaitingForOnline)
          Text(
            "${vm.elapsedSeconds}s",
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
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
