import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/services/local_network_service.dart';
import 'package:do_x/view_model/local_network_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Reusable body that lists the devices discovered on the local network.
///
/// Expects a [LocalNetworkViewModel] to be provided by an ancestor.
class LocalNetworkView extends StatelessWidget {
  const LocalNetworkView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<LocalNetworkViewModel>(
      builder: (context, vm, _) {
        return RefreshIndicator.adaptive(
          onRefresh: vm.scan,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(15, 16, 15, 28),
            children: [
              _buildSummary(context, vm),
              const SizedBox(height: 14),
              if (vm.errorMessage != null)
                _buildNotice(
                  context,
                  vm.errorMessage!,
                  icon: Icons.wifi_off_rounded,
                  color: context.theme.colorScheme.error,
                )
              else if (!vm.isScanning && vm.devices.isEmpty)
                _buildNotice(
                  context,
                  l10n.noDevicesFound,
                  icon: Icons.search_off_rounded,
                  color: context.theme.colorScheme.onSurfaceVariant,
                )
              else
                for (final device in vm.devices) ...[
                  _buildDeviceCard(context, device),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 4),
              Text(
                l10n.deviceScanHint,
                style: context.theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummary(BuildContext context, LocalNetworkViewModel vm) {
    final l10n = AppLocalizations.of(context);
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
                    Text(
                      l10n.activeDevices,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      vm.isScanning
                          ? l10n.scanningAddresses(
                              vm.scannedAddresses,
                              vm.totalAddresses,
                            )
                          : l10n.devicesDetected(vm.devices.length),
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
                tooltip: l10n.rescan,
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

  Widget _buildDeviceCard(BuildContext context, LocalNetworkDevice device) {
    final l10n = AppLocalizations.of(context);
    final title = _deviceTitle(context, device);
    final details = <String>[
      device.ipAddress,
      if (device.deviceName != null && device.isRouter) device.deviceName!,
      if (device.hostName != null &&
          device.isRouter &&
          device.hostName != device.deviceName)
        device.hostName!,
      if (device.macAddress != null) l10n.macLabel(device.macAddress!),
      if (device.modelName != null &&
          device.deviceName != null &&
          device.modelName != device.deviceName)
        device.modelName!,
      if (device.openPorts.isNotEmpty)
        l10n.portsLabel(device.openPorts.join(', ')),
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
            child: Icon(_deviceIcon(device), size: 22),
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

  String _deviceTitle(BuildContext context, LocalNetworkDevice device) {
    final l10n = AppLocalizations.of(context);
    if (device.isCurrentDevice) {
      final name = device.deviceName ?? device.modelName ?? device.hostName;
      return name == null ? l10n.thisDevice : l10n.thisDeviceNamed(name);
    }
    if (device.isRouter) return l10n.routerLabel;
    return device.deviceName ?? device.hostName ?? l10n.networkDevice;
  }

  IconData _deviceIcon(LocalNetworkDevice device) {
    if (device.isRouter) return Icons.router_outlined;
    return switch (device.deviceType) {
      LocalNetworkDeviceType.phone => Icons.phone_iphone_rounded,
      LocalNetworkDeviceType.tablet => Icons.tablet_mac_rounded,
      LocalNetworkDeviceType.computer => Icons.laptop_mac_rounded,
      LocalNetworkDeviceType.camera => Icons.videocam_outlined,
      LocalNetworkDeviceType.router => Icons.router_outlined,
      LocalNetworkDeviceType.unknown => Icons.devices_other_outlined,
    };
  }

  Widget _buildNotice(
    BuildContext context,
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
