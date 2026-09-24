import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/network/local_network_screen.dart';
import 'package:do_x/services/router_repeater_service.dart';
import 'package:do_x/services/speed_test_service.dart';
import 'package:do_x/view_model/local_network_view_model.dart';
import 'package:do_x/view_model/wifi_management_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/cute_dialog.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/input/cute_text_field.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/surface/app_card.dart';
import 'package:do_x/widgets/surface/surface_scope.dart';
import 'package:do_x/widgets/text_field.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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

class _WifiManagementScreenState<V extends WifiManagementViewModel>
    extends ScreenState<WifiManagementScreen, V>
    with SingleTickerProviderStateMixin {
  static const _speedTabIndex = 1;
  static const _repeaterTabIndex = 3;

  late final TabController _tabController = TabController(
    length: 4,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// The repeater status needs a router login, so it is fetched when the tab is
  /// first opened rather than on every visit to the screen. The live signal
  /// poll runs only while that tab is the visible one.
  void _onTabChanged() {
    if (_tabController.index == _repeaterTabIndex) {
      vm.connectRepeaterOnce();
      vm.startRepeaterLive();
    } else {
      vm.stopRepeaterLive();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Nothing should poll the router while the app is in the background.
    if (state == AppLifecycleState.resumed) {
      if (_tabController.index == _repeaterTabIndex) vm.startRepeaterLive();
    } else if (state != AppLifecycleState.inactive) {
      vm.stopRepeaterLive();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      appBar: DoAppBar(
        title: l10n.wifiManagement,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: [
            Tab(
              icon: const Icon(Icons.settings_ethernet),
              text: l10n.tabReboot,
            ),
            Tab(icon: const Icon(Icons.speed_rounded), text: l10n.tabSpeed),
            Tab(icon: const Icon(Icons.lan_outlined), text: l10n.tabDevices),
            Tab(icon: const Icon(Icons.wifi_tethering), text: l10n.tabRepeater),
          ],
        ),
      ),
      body: Consumer<V>(
        builder: (context, vm, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildWifiTab(l10n, vm),
              _buildSpeedTab(l10n, vm),
              const _LocalNetworkTab(),
              _buildRepeaterTab(l10n, vm),
            ],
          );
        },
      ),
    );
  }

  /// Reboots the router, then switches to the speed test tab once it comes
  /// back online and immediately measures the connection speed.
  Future<void> _handleReboot(V vm) async {
    await vm.reboot();
    if (!mounted) return;
    // Only jump to the speed tab when the reboot cycle finished successfully.
    if (vm.errorMessage != null ||
        vm.activeStep < WifiManagementViewModel.stepLabels.length) {
      return;
    }
    _tabController.animateTo(_speedTabIndex);
    context.showToast(AppLocalizations.of(context).rebootSuccessStartSpeedTest);
    vm.runSpeedTests();
  }

  Widget _buildWifiTab(AppLocalizations l10n, V vm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          _buildConfigSection(l10n, vm),
          if (vm.isBusy || vm.activeStep >= 0) _buildSteps(vm),
          if (vm.successMessage != null)
            _buildAlert(vm.successMessage!, isError: false),
          if (vm.errorMessage != null)
            _buildAlert(vm.errorMessage!, isError: true),
          DoButton(
            isBusy: vm.isBusy,
            onPressed: () => _handleReboot(vm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 8,
              children: [
                const SFIcon(SFIcons.sf_arrow_counterclockwise),
                Text(vm.isBusy ? l10n.processing : l10n.rebootRouter),
              ],
            ),
          ),
          if (kDebugMode && vm.logs.isNotEmpty) _buildLogs(vm),
        ],
      ),
    ).contentConstrainedBox();
  }

  Widget _buildRepeaterTab(AppLocalizations l10n, V vm) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            _buildRepeaterStatus(l10n, vm),
            if (vm.repeaterSuccess != null)
              _buildAlert(vm.repeaterSuccess!, isError: false),
            if (vm.repeaterError != null)
              _buildAlert(vm.repeaterError!, isError: true),
            DoButton(
              isBusy: vm.isScanning,
              onPressed: vm.scanNearbyWifi,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  const SFIcon(SFIcons.sf_dot_radiowaves_left_and_right),
                  Text(
                    vm.isScanning ? l10n.repeaterScanning : l10n.repeaterScan,
                  ),
                ],
              ),
            ),
            if (vm.nearbyWifi != null) _buildNearbyList(l10n, vm),
            if (kDebugMode && vm.logs.isNotEmpty) _buildLogs(vm),
          ],
        ),
      ).contentConstrainedBox(),
    );
  }

  Widget _buildRepeaterStatus(AppLocalizations l10n, V vm) {
    final status = vm.repeaterStatus;
    final isRepeating = status?.isRepeating ?? false;
    final color = isRepeating ? context.colors.success : context.colors.info;

    return AppCard(
      radius: 14,
      color: context.tintOnSurface(color, amount: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 10,
            children: [
              SFIcon(
                isRepeating ? SFIcons.sf_wifi : SFIcons.sf_wifi_slash,
                color: color,
                fontSize: 22,
              ),
              Expanded(
                child: Text(
                  isRepeating
                      ? l10n.repeaterCurrentUpstream
                      : status == null
                      ? l10n.repeaterNeedsLogin
                      : l10n.repeaterNotRepeating,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // The spinner replaces the glyph *inside* the button, so the
              // row keeps its height and the header text keeps its width
              // while a reload runs.
              IconButton(
                onPressed: vm.isRepeaterLoading ? null : vm.connectRepeater,
                visualDensity: VisualDensity.compact,
                tooltip: status == null
                    ? l10n.repeaterConnect
                    : l10n.repeaterReload,
                icon: SizedBox.square(
                  dimension: 20,
                  child: vm.isRepeaterLoading
                      ? const Loading(size: 16, strokeWidth: 2)
                      : SFIcon(
                          status == null
                              ? SFIcons.sf_person_badge_key
                              : SFIcons.sf_arrow_clockwise,
                          fontSize: 16,
                        ),
                ),
              ),
            ],
          ),
          if (isRepeating)
            Text(
              status!.upstreamSsid!,
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          if (isRepeating && status!.signal != null)
            _buildSignalBar(l10n, vm, status.signal!),
          if (status != null)
            Text(
              [
                if (isRepeating && (status.band ?? "").isNotEmpty)
                  _bandLabel(status.band!),
                if (status.localSsids.isNotEmpty)
                  "${l10n.repeaterOwnSsid}: ${status.localSsids.join(", ")}",
              ].join(" · "),
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (isRepeating && vm.isSignalStale)
            Text(
              l10n.repeaterSignalStale,
              style: context.theme.textTheme.labelSmall?.copyWith(
                color: context.colors.warning,
              ),
            ),
        ],
      ),
    );
  }

  /// The live uplink reading: percentage, a bar and a pulsing dot while the
  /// poll is running.
  Widget _buildSignalBar(AppLocalizations l10n, V vm, int signal) {
    final color = _signalColor(signal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        Row(
          spacing: 6,
          children: [
            Text(
              "$signal%",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            if (vm.isLive && !vm.isSignalStale) ...[
              _LivePulse(color: color),
              Text(
                l10n.repeaterLive,
                style: context.theme.textTheme.labelSmall?.copyWith(
                  color: color,
                ),
              ),
            ],
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(Dimens.radiusTiny),
          child: TweenAnimationBuilder(
            // Animating the bar keeps a 3-second tick from looking like a jump.
            tween: Tween<double>(end: (signal / 100).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 400),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor:
                  context.theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyList(AppLocalizations l10n, V vm) {
    final list = vm.nearbyWifi!;
    if (list.isEmpty) {
      return Text(
        l10n.repeaterNearbyEmpty,
        style: context.theme.textTheme.bodySmall,
      );
    }
    final current = vm.repeaterStatus?.upstreamSsid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          spacing: 8,
          children: [
            Text(
              l10n.repeaterNearbyTitle,
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            // A fixed slot, so the header does not move when a background
            // scan starts.
            SizedBox.square(
              dimension: 16,
              child: vm.isBackgroundScanning
                  ? const Loading(size: 14, strokeWidth: 2)
                  : null,
            ),
            const Spacer(),
            Text(
              l10n.repeaterAutoScan,
              style: context.theme.textTheme.labelSmall,
            ),
            Switch(
              value: vm.isAutoScanOn,
              onChanged: (_) => vm.toggleAutoScan(),
            ),
          ],
        ),
        for (final wifi in list)
          _buildNearbyRow(l10n, vm, wifi, isCurrent: wifi.ssid == current),
      ],
    );
  }

  Widget _buildNearbyRow(
    AppLocalizations l10n,
    V vm,
    NearbyWifi wifi, {
    required bool isCurrent,
  }) {
    final subtitle = [
      if ((wifi.band ?? "").isNotEmpty) _bandLabel(wifi.band!),
      if (wifi.channel != null) l10n.repeaterChannel(wifi.channel!),
      wifi.isOpen ? l10n.repeaterOpenNetwork : (wifi.encryption ?? ""),
    ].where((part) => part.isNotEmpty).join(" · ");

    return AppCard(
      radius: 14,
      color: isCurrent
          ? context.tintOnSurface(context.colors.success, amount: 0.12)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: vm.isApplyingUpstream ? null : () => _pickUpstream(vm, wifi),
      child: Row(
        spacing: 12,
        children: [
          SFIcon(
            SFIcons.sf_wifi,
            fontSize: 20,
            color: _signalColor(wifi.signal),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wifi.ssid,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  subtitle,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            SFIcon(
              SFIcons.sf_checkmark_circle_fill,
              color: context.colors.success,
              fontSize: 18,
            ),
          // A fixed slot: a live refresh changing 9% to 100% must not shove
          // the row's text sideways.
          SizedBox(
            width: 42,
            child: Text(
              "${wifi.signal}%",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _signalColor(wifi.signal),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickUpstream(V vm, NearbyWifi wifi) async {
    await showAppModal<void>(
      context,
      builder: (_) => _UpstreamDialog(wifi: wifi, vm: vm),
    );
  }

  String _bandLabel(String band) => switch (band.toLowerCase()) {
    "2g" => "2.4GHz",
    "5g" => "5GHz",
    _ => band,
  };

  /// SF Symbols has no per-strength Wi-Fi glyph, so strength is carried by
  /// colour on the one icon.
  Color _signalColor(int signal) => switch (signal) {
    >= 60 => context.colors.success,
    >= 30 => context.colors.warning,
    _ => context.colors.danger,
  };

  Widget _buildSpeedTab(AppLocalizations l10n, V vm) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: _buildSpeedTestSection(l10n, vm),
    ).contentConstrainedBox();
  }

  Widget _buildSpeedTestSection(AppLocalizations l10n, V vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.connectionSpeedTest,
              style: context.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (SpeedTestServer.internetServers.length > 1)
              _buildServerPicker(vm),
          ],
        ),
        _buildSpeedResultRow(
          title: l10n.lanSpeed,
          subtitle: vm.ip.replaceAll(RegExp(r'https?://'), ''),
          speed: vm.lanSpeed,
          latency: vm.lanLatency,
          isTesting: vm.isTestingLan,
          icon: SFIcons.sf_network,
          color: context.colors.info,
          l10n: l10n,
        ),
        _buildSpeedResultRow(
          title: l10n.internetSpeed,
          subtitle: vm.selectedServer.name,
          speed: vm.internetSpeed,
          latency: vm.internetLatency,
          isTesting: vm.isTestingInternet,
          icon: SFIcons.sf_globe,
          color: context.colors.success,
          l10n: l10n,
        ),
        if (vm.lanSpeed != null &&
            vm.internetSpeed != null &&
            !vm.isTestingLan &&
            !vm.isTestingInternet)
          _buildSpeedAnalysis(vm.lanSpeed!, vm.internetSpeed!),
        DoButton(
          onPressed: vm.runSpeedTests,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 8,
            children: [
              Icon(vm.isTesting ? Icons.stop_rounded : Icons.speed_rounded),
              Text(vm.isTesting ? l10n.stopSpeedTest : l10n.startSpeedTest),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedResultRow({
    required String title,
    String? subtitle,
    required double? speed,
    required int? latency,
    required bool isTesting,
    required IconData icon,
    required Color color,
    required AppLocalizations l10n,
  }) {
    return AppCard(
      radius: 14,
      // A row under test lifts higher instead of taking a thicker outline.
      color: context.tintOnSurface(color, amount: isTesting ? 0.16 : 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        spacing: 14,
        children: [
          SizedBox.square(
            dimension: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SFIcon(icon, color: color, fontSize: 22),
                if (isTesting)
                  const SizedBox.square(
                    dimension: 32,
                    child: Loading(size: 32, strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                speed != null && (speed > 0 || isTesting)
                    ? l10n.speedMbps(speed.toStringAsFixed(1))
                    : "--",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.theme.colorScheme.onSurface,
                ),
              ),
              if (latency != null)
                Text(
                  l10n.ttfbMs(latency),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServerPicker(V vm) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<SpeedTestServer>(
      initialValue: vm.selectedServer,
      onSelected: vm.setSelectedServer,
      tooltip: l10n.selectInternetServer,
      itemBuilder: (context) => SpeedTestServer.internetServers.map((server) {
        return PopupMenuItem(
          value: server,
          child: Row(
            spacing: 8,
            children: [
              if (vm.selectedServer == server)
                Icon(Icons.check, size: 16, color: context.colors.success),
              Text(server.name, style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.surfaces.sunken,
          borderRadius: BorderRadius.circular(Dimens.radiusSmall),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dns_outlined, size: 14),
            const SizedBox(width: 4),
            Text(l10n.serverLabel, style: context.theme.textTheme.labelSmall),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedAnalysis(double lan, double internet) {
    final l10n = AppLocalizations.of(context);
    String analysis;
    Color color;
    if (lan < 10) {
      analysis = l10n.speedAnalysisLanWeak;
      color = context.colors.danger;
    } else if (lan > 50 && internet < 10) {
      analysis = l10n.speedAnalysisInternetSlow;
      color = context.colors.warning;
    } else if (lan > 50 && internet > 50) {
      analysis = l10n.speedAnalysisPerfect;
      color = context.colors.success;
    } else {
      analysis = l10n.speedAnalysisStable;
      color = context.colors.info;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tintOnSurface(color, amount: 0.1),
        borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
      ),
      child: Row(
        spacing: 8,
        children: [
          Icon(Icons.analytics_outlined, color: color, size: 20),
          Expanded(
            child: Text(analysis, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSection(AppLocalizations l10n, V vm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        Text(
          l10n.deviceConfig,
          style: context.theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
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
            helperText: l10n.adminPasswordHelper,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimens.radiusPanel), //
            ),
            suffixIcon: IconButton(
              onPressed: vm.togglePasswordVisible,
              icon: SFIcon(
                vm.showPassword ? SFIcons.sf_eye_slash : SFIcons.sf_eye,
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSteps(V vm) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        Text(l10n.progressTitle, style: context.theme.textTheme.bodySmall),
        for (final (index, label)
            in WifiManagementViewModel.stepLabels.indexed) //
          _buildStepRow(vm, index, label),
        if (vm.isWaitingForOnline) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.radiusTiny),
            child: LinearProgressIndicator(
              // Estimate 90s for a full reboot cycle
              value: (vm.elapsedSeconds / 90).clamp(0.0, 0.99),
              minHeight: 6,
              backgroundColor:
                  context.theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                vm.isTakingTooLong
                    ? context.colors.warning
                    : context.theme.colorScheme.primary,
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
                        ? l10n.routerNoResponse(vm.elapsedSeconds)
                        : l10n.reconnectingEstimate,
                    style: context.theme.textTheme.labelSmall?.copyWith(
                      color: vm.isTakingTooLong
                          ? context.colors.warning
                          : context.theme.colorScheme.primary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: vm.skipWaiting,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    l10n.skipWaiting,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (vm.isTakingTooLong)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l10n.skipWaitingNote,
                style: context.theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
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
        ? context.colors.success
        : context.theme.colorScheme.onSurface.withValues(
            alpha: isRunning ? 1 : 0.4,
          );

    return Row(
      spacing: 8,
      children: [
        SizedBox.square(
          dimension: 18,
          child: isRunning
              ? const Loading(size: 18, strokeWidth: 2)
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
        Expanded(
          child: Text("${index + 1}. $label", style: TextStyle(color: color)),
        ),
        if (isRunning && vm.isWaitingForOnline)
          Text(
            "${vm.elapsedSeconds}s",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }

  Widget _buildAlert(String message, {required bool isError}) {
    final l10n = AppLocalizations.of(context);
    final color = isError
        ? context.theme.colorScheme.error
        : context.colors.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tintOnSurface(color, amount: 0.14),
        borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isError ? l10n.errorLabel : l10n.successLabel,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          Text(message, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildLogs(V vm) {
    final l10n = AppLocalizations.of(context);
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
                  child: Text(
                    l10n.consoleLog,
                    style: context.theme.textTheme.bodySmall,
                  ),
                ),
                SFIcon(
                  vm.showLogs ? SFIcons.sf_chevron_up : SFIcons.sf_chevron_down,
                  fontSize: 14,
                ),
              ],
            ),
          ),
        ),
        if (vm.showLogs)
          Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              // Console keeps its own near-black; the outline goes, since the
              // colour step off the page is already the boundary.
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(Dimens.radiusControlSmall),
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
                              : log.contains("thành công") ||
                                    log.contains("Hoàn tất")
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

/// Local network scan tab. Owns its own [LocalNetworkViewModel] and starts a
/// scan as soon as the tab is first shown.
class _LocalNetworkTab extends StatefulWidget {
  const _LocalNetworkTab();

  @override
  State<_LocalNetworkTab> createState() => _LocalNetworkTabState();
}

class _LocalNetworkTabState extends State<_LocalNetworkTab>
    with AutomaticKeepAliveClientMixin {
  final _vm = LocalNetworkViewModel();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _vm.setCurrentContext(context);
    _vm.initData();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ChangeNotifierProvider.value(
      value: _vm,
      child: const LocalNetworkView(),
    );
  }
}

/// Asks for the upstream Wi-Fi password, then points the repeater at it.
class _UpstreamDialog extends StatefulWidget {
  const _UpstreamDialog({required this.wifi, required this.vm});

  final NearbyWifi wifi;
  final WifiManagementViewModel vm;

  @override
  State<_UpstreamDialog> createState() => _UpstreamDialogState();
}

class _UpstreamDialogState extends State<_UpstreamDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final password = _controller.text;
    if (!widget.wifi.isOpen && password.isEmpty) {
      setState(() => _error = l10n.repeaterPasswordRequired);
      return;
    }
    setState(() => _error = null);
    final applied = await widget.vm.applyUpstream(widget.wifi, password);
    if (!mounted || !applied) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CuteDialog(
      title: l10n.repeaterPickTitle,
      confirmText: l10n.repeaterApplyConfirm,
      onConfirm: _confirm,
      children: [
        Text(
          widget.wifi.ssid,
          style: context.theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (!widget.wifi.isOpen)
          CuteTextField(
            controller: _controller,
            label: l10n.repeaterWifiPassword,
            obscureText: _obscure,
            errorText: _error,
            autofocus: true,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: SFIcon(
                _obscure ? SFIcons.sf_eye : SFIcons.sf_eye_slash,
                fontSize: 18,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          l10n.repeaterApplyWarning,
          style: context.theme.textTheme.bodySmall?.copyWith(
            color: context.colors.warning,
          ),
        ),
      ],
    );
  }
}

/// Slowly breathing dot that marks a value as live.
class _LivePulse extends StatefulWidget {
  const _LivePulse({required this.color});

  final Color color;

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
