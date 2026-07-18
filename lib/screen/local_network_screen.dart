import 'package:auto_route/auto_route.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/local_network_service.dart';
import 'package:do_x/view_model/local_network_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

@RoutePage()
class LocalNetworkScreen extends StatefulScreen implements AutoRouteWrapper {
  const LocalNetworkScreen({super.key});

  @override
  State<LocalNetworkScreen> createState() => _LocalNetworkScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocalNetworkViewModel(),
      child: this,
    );
  }
}

class _LocalNetworkScreenState<V extends LocalNetworkViewModel>
    extends ScreenState<LocalNetworkScreen, V> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DoAppBar(title: 'Thiết bị mạng nội bộ'),
      body: Consumer<V>(
        builder: (context, vm, _) {
          return RefreshIndicator.adaptive(
            onRefresh: vm.scan,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(15, 16, 15, 28),
              children: [
                _buildSummary(vm),
                const SizedBox(height: 14),
                if (vm.errorMessage != null)
                  _buildNotice(
                    vm.errorMessage!,
                    icon: Icons.wifi_off_rounded,
                    color: context.theme.colorScheme.error,
                  )
                else if (!vm.isScanning && vm.devices.isEmpty)
                  _buildNotice(
                    'Chưa tìm thấy thiết bị. Hãy chắc chắn điện thoại đang kết nối Wi-Fi rồi quét lại.',
                    icon: Icons.search_off_rounded,
                    color: context.theme.colorScheme.onSurfaceVariant,
                  )
                else
                  for (final device in vm.devices) ...[
                    _buildDeviceCard(device),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 4),
                Text(
                  'Kết quả gồm các thiết bị phản hồi trên những cổng mạng phổ biến. Thiết bị chặn kết nối có thể không xuất hiện.',
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(V vm) {
    final progress = vm.totalAddresses == 0
        ? 0.0
        : vm.scannedAddresses / vm.totalAddresses;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              const Icon(Icons.lan_outlined, color: Colors.white, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thiết bị đang hoạt động',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      vm.isScanning
                          ? 'Đang quét ${vm.scannedAddresses}/${vm.totalAddresses} địa chỉ'
                          : '${vm.devices.length} thiết bị được phát hiện',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: vm.isScanning ? null : vm.scan,
                tooltip: 'Quét lại',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          if (vm.isScanning)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(LocalNetworkDevice device) {
    final title = device.isCurrentDevice
        ? 'Thiết bị này'
        : device.isRouter
        ? 'Router'
        : device.deviceName ?? device.hostName ?? 'Thiết bị mạng';
    final details = <String>[
      device.ipAddress,
      if (device.deviceName != null &&
          (device.isCurrentDevice || device.isRouter))
        device.deviceName!,
      if (device.hostName != null &&
          (device.isCurrentDevice || device.isRouter) &&
          device.hostName != device.deviceName)
        device.hostName!,
      if (device.openPorts.isNotEmpty) 'Cổng: ${device.openPorts.join(', ')}',
    ];
    final color = device.isRouter
        ? Colors.blue
        : device.isCurrentDevice
        ? Colors.green
        : context.theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        spacing: 12,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.12),
            foregroundColor: color,
            child: Icon(
              device.isRouter
                  ? Icons.router_outlined
                  : device.isCurrentDevice
                  ? Icons.smartphone_outlined
                  : Icons.devices_other_outlined,
              size: 22,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  details.join(' • '),
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(
    String message, {
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 10,
        children: [
          Icon(icon, color: color, size: 20),
          Expanded(
            child: Text(
              message,
              style: context.theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
