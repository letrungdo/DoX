import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;

class LocalNetworkDevice {
  const LocalNetworkDevice({
    required this.ipAddress,
    this.hostName,
    this.deviceName,
    this.openPorts = const [],
    this.isCurrentDevice = false,
    this.isRouter = false,
  });

  final String ipAddress;
  final String? hostName;
  final String? deviceName;
  final List<int> openPorts;
  final bool isCurrentDevice;
  final bool isRouter;
}

class LocalNetworkScanException implements Exception {
  const LocalNetworkScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Discovers devices that respond on common TCP service ports in the current
/// IPv4 /24 network and in a reachable configured router subnet. This is
/// intentionally router-independent, so it also works when the router does not
/// expose its DHCP client list.
class LocalNetworkService {
  static const _ports = <int>[80, 443, 22, 53, 445, 554, 8000, 8080, 9100];
  static const _batchSize = 24;
  int _scanGeneration = 0;

  void cancelScan() => _scanGeneration++;

  Future<List<LocalNetworkDevice>> scan({
    String? routerUrl,
    void Function(LocalNetworkDevice device)? onDeviceFound,
    void Function(int scanned, int total)? onProgress,
  }) async {
    final generation = ++_scanGeneration;
    final localAddresses = await _localIpv4Addresses();
    if (localAddresses.isEmpty) {
      throw const LocalNetworkScanException(
        'Không tìm thấy địa chỉ IPv4 nội bộ. Hãy kết nối Wi-Fi rồi thử lại.',
      );
    }

    final routerIp = _hostFromUrl(routerUrl);
    final localIp = localAddresses.firstWhere(
      (address) => routerIp != null && _subnet(address) == _subnet(routerIp),
      orElse: () => localAddresses.first,
    );
    final localSubnet = _subnet(localIp);
    final subnets = <String>{localSubnet};

    // A configured router can be on an upstream/downstream routed subnet. Only
    // expand the scan when that router is actually reachable, avoiding blind
    // scans of arbitrary private networks.
    if (routerIp != null && _subnet(routerIp) != localSubnet) {
      final reachableRouter = await _probe(
        routerIp,
        localIp: localIp,
        routerIp: routerIp,
      );
      if (reachableRouter != null) subnets.add(_subnet(routerIp));
    }

    final devices = <String, LocalNetworkDevice>{};
    var scanned = 0;
    final total = subnets.length * 254;
    onProgress?.call(0, total);

    for (final subnet in subnets) {
      for (var start = 1; start <= 254; start += _batchSize) {
        if (generation != _scanGeneration) return devices.values.toList();
        final end = (start + _batchSize - 1).clamp(1, 254);
        final results = await Future.wait([
          for (var suffix = start; suffix <= end; suffix++)
            _probe('$subnet.$suffix', localIp: localIp, routerIp: routerIp),
        ]);

        for (final device in results.nonNulls) {
          devices[device.ipAddress] = device;
          onDeviceFound?.call(device);
        }
        scanned += results.length;
        onProgress?.call(scanned, total);
      }
    }

    final result = devices.values.toList()
      ..sort((a, b) => _ipValue(a.ipAddress).compareTo(_ipValue(b.ipAddress)));
    return result;
  }

  Future<List<String>> _localIpv4Addresses() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final wifiAddresses = <String>[];
    final otherAddresses = <String>[];
    for (final interface in interfaces) {
      final name = interface.name.toLowerCase();
      final isWifi =
          name == 'en0' || name.contains('wlan') || name.contains('wifi');
      for (final address in interface.addresses) {
        if (!_isPrivateIpv4(address.address)) continue;
        (isWifi ? wifiAddresses : otherAddresses).add(address.address);
      }
    }
    return [...wifiAddresses, ...otherAddresses];
  }

  Future<LocalNetworkDevice?> _probe(
    String ip, {
    required String localIp,
    required String? routerIp,
  }) async {
    final isCurrentDevice = ip == localIp;
    final isRouter = ip == routerIp;
    final openPorts = <int>[];

    if (!isCurrentDevice) {
      await Future.wait(
        _ports.map((port) async {
          Socket? socket;
          try {
            socket = await Socket.connect(
              ip,
              port,
              timeout: const Duration(milliseconds: 260),
            );
            openPorts.add(port);
          } on SocketException {
            // A closed or filtered port is expected for most addresses.
          } on TimeoutException {
            // The host did not answer this port within the scan window.
          } finally {
            socket?.destroy();
          }
        }),
      );
    }

    if (!isCurrentDevice && openPorts.isEmpty) return null;

    String? hostName;
    try {
      final reversed = await InternetAddress(
        ip,
      ).reverse().timeout(const Duration(milliseconds: 350));
      if (reversed.host != ip) hostName = reversed.host;
    } on Object {
      // Reverse DNS is optional and is commonly unavailable on home networks.
    }

    final deviceName = await _httpDeviceName(ip, openPorts);

    return LocalNetworkDevice(
      ipAddress: ip,
      hostName: hostName,
      deviceName: deviceName,
      openPorts: openPorts..sort(),
      isCurrentDevice: isCurrentDevice,
      isRouter: isRouter,
    );
  }

  Future<String?> _httpDeviceName(String ip, List<int> openPorts) async {
    int? webPort;
    for (final port in const <int>[80, 8080, 8000, 443]) {
      if (openPorts.contains(port)) {
        webPort = port;
        break;
      }
    }
    if (webPort == null) return null;

    final isSecure = webPort == 443;
    final uri = Uri(
      scheme: isSecure ? 'https' : 'http',
      host: ip,
      port: webPort,
    );
    final client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 450)
      ..badCertificateCallback = (_, _, _) => true;
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(milliseconds: 500));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'DoX Local Network Discovery',
      );
      final response = await request.close().timeout(
        const Duration(milliseconds: 500),
      );
      final bytes = <int>[];
      await for (final chunk in response.timeout(
        const Duration(milliseconds: 650),
      )) {
        final remaining = 32768 - bytes.length;
        if (remaining <= 0) break;
        bytes.addAll(
          chunk.length <= remaining ? chunk : chunk.sublist(0, remaining),
        );
        if (bytes.length == 32768) break;
      }
      final body = const Utf8Decoder(allowMalformed: true).convert(bytes);
      final title = html_parser.parse(body).querySelector('title')?.text.trim();
      if (title == null || title.isEmpty || title.length > 80) return null;
      return title.replaceAll(RegExp(r'\s+'), ' ');
    } on Object {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  String? _hostFromUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.contains('://')
        ? value.trim()
        : 'http://${value.trim()}';
    final host = Uri.tryParse(normalized)?.host;
    return host != null && _isPrivateIpv4(host) ? host : null;
  }

  bool _isPrivateIpv4(String value) {
    final parts = value.split('.').map(int.tryParse).toList();
    if (parts.length != 4 ||
        parts.any((part) => part == null || part < 0 || part > 255)) {
      return false;
    }
    final first = parts[0]!;
    final second = parts[1]!;
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }

  String _subnet(String ip) => ip.substring(0, ip.lastIndexOf('.'));

  int _ipValue(String ip) => ip
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .fold(0, (value, part) => (value << 8) + part);
}
