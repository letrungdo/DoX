import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:nsd/nsd.dart' as nsd;

enum LocalNetworkDeviceType { unknown, phone, tablet, computer, camera, router }

LocalNetworkDeviceType classifyLocalNetworkDevice({
  String? name,
  String? hostName,
  List<int> openPorts = const [],
  String? serviceType,
  bool isCurrentDevice = false,
  bool isRouter = false,
}) {
  if (isRouter) return LocalNetworkDeviceType.router;
  if (isCurrentDevice) return LocalNetworkDeviceType.phone;

  final identity = '${name ?? ''} ${hostName ?? ''}'.toLowerCase();
  if (RegExp(
    r'camera|ipcam|onvif|hikvision|dahua|ezviz|imou|reolink|tapo|xiaoyi|yi cam',
  ).hasMatch(identity)) {
    return LocalNetworkDeviceType.camera;
  }
  if (RegExp(r'ipad|tablet|galaxy tab').hasMatch(identity)) {
    return LocalNetworkDeviceType.tablet;
  }
  if (RegExp(
    r'iphone|ipod|android|pixel|galaxy|redmi|oppo|vivo|oneplus|phone',
  ).hasMatch(identity)) {
    return LocalNetworkDeviceType.phone;
  }
  if (RegExp(
    r'macbook|imac|mac mini|mac pro|windows|desktop|laptop|notebook|chromebook',
  ).hasMatch(identity)) {
    return LocalNetworkDeviceType.computer;
  }

  if (serviceType == '_apple-mobdev2._tcp') {
    return LocalNetworkDeviceType.phone;
  }
  if (serviceType == '_workstation._tcp' || serviceType == '_smb._tcp') {
    return LocalNetworkDeviceType.computer;
  }
  if (openPorts.any(const {554, 8554, 34567, 37777}.contains)) {
    return LocalNetworkDeviceType.camera;
  }
  return LocalNetworkDeviceType.unknown;
}

class LocalNetworkDevice {
  const LocalNetworkDevice({
    required this.ipAddress,
    this.hostName,
    this.deviceName,
    this.macAddress,
    this.modelName,
    this.openPorts = const [],
    this.deviceType = LocalNetworkDeviceType.unknown,
    this.isCurrentDevice = false,
    this.isRouter = false,
  });

  final String ipAddress;
  final String? hostName;
  final String? deviceName;
  final String? macAddress;
  final String? modelName;
  final List<int> openPorts;
  final LocalNetworkDeviceType deviceType;
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
  // Besides common network services, include ports frequently exposed by
  // ONVIF/RTSP cameras and popular camera firmwares. A number of cameras do
  // not answer ICMP, mDNS, or reverse DNS, so an open service port may be the
  // only reliable way to discover them from a phone.
  static const _ports = <int>[
    22,
    53,
    80,
    81,
    88,
    443,
    445,
    554,
    5000,
    8000,
    8080,
    8081,
    8554,
    8899,
    9000,
    9100,
    34567,
    37777,
  ];
  static const _bonjourServiceTypes = <String>[
    '_http._tcp',
    '_workstation._tcp',
    '_airplay._tcp',
    '_raop._tcp',
    '_companion-link._tcp',
    '_apple-mobdev2._tcp',
    '_device-info._tcp',
    '_smb._tcp',
  ];
  // Each address probes all ports concurrently. Keeping the outer concurrency
  // bounded avoids socket exhaustion while scanning two batches at a time
  // compared with the previous setting.
  static const _batchSize = 48;
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
    final bonjourDevices = _discoverBonjourDevices(
      localIp: localIp,
      routerIp: routerIp,
    );
    final udpDevices = _discoverCameraUdpDevices(
      localIp: localIp,
      routerIp: routerIp,
    );

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

    if (generation == _scanGeneration) {
      for (final discoveredDevices in [
        await bonjourDevices,
        await udpDevices,
      ]) {
        for (final device in discoveredDevices) {
          final merged = _mergeDevice(devices[device.ipAddress], device);
          devices[device.ipAddress] = merged;
          onDeviceFound?.call(merged);
        }
      }
    }

    final result = devices.values.toList()
      ..sort((a, b) => _ipValue(a.ipAddress).compareTo(_ipValue(b.ipAddress)));
    return result;
  }

  Future<List<LocalNetworkDevice>> _discoverBonjourDevices({
    required String localIp,
    required String? routerIp,
  }) async {
    final discoveries = <nsd.Discovery, String>{};
    try {
      await Future.wait(
        _bonjourServiceTypes.map((serviceType) async {
          try {
            final discovery = await nsd.startDiscovery(
              serviceType,
              ipLookupType: nsd.IpLookupType.v4,
            );
            discoveries[discovery] = serviceType;
          } on Object {
            // A service type may be unavailable or blocked on one platform.
          }
        }),
      );
      if (discoveries.isEmpty) return const [];

      await Future<void>.delayed(const Duration(milliseconds: 2600));
      final devices = <String, LocalNetworkDevice>{};
      for (final entry in discoveries.entries) {
        final discovery = entry.key;
        final serviceType = entry.value;
        for (final service in discovery.services) {
          final name = _bonjourDeviceName(service);
          final hostName = _cleanBonjourHost(service.host);
          final addresses = service.addresses ?? const <InternetAddress>[];
          for (final address in addresses) {
            final ip = address.address;
            if (address.type != InternetAddressType.IPv4 ||
                !_isPrivateIpv4(ip)) {
              continue;
            }
            final device = LocalNetworkDevice(
              ipAddress: ip,
              hostName: hostName,
              deviceName: name,
              openPorts: service.port == null ? const [] : [service.port!],
              deviceType: classifyLocalNetworkDevice(
                name: name,
                hostName: hostName,
                serviceType: serviceType,
                isCurrentDevice: ip == localIp,
                isRouter: ip == routerIp,
              ),
              isCurrentDevice: ip == localIp,
              isRouter: ip == routerIp,
            );
            devices[ip] = _mergeDevice(devices[ip], device);
          }
        }
      }
      return devices.values.toList();
    } on Object {
      return const [];
    } finally {
      await Future.wait(
        discoveries.keys.map((discovery) async {
          try {
            await nsd.stopDiscovery(discovery);
          } on Object {
            // Discovery may already have stopped after a network change.
          }
        }),
      );
    }
  }

  /// Sends the two discovery probes commonly supported by IP cameras:
  /// ONVIF WS-Discovery and UPnP/SSDP. Their replies are unicast back to this
  /// socket, so cameras can still be found when every TCP service is filtered.
  Future<List<LocalNetworkDevice>> _discoverCameraUdpDevices({
    required String localIp,
    required String? routerIp,
  }) async {
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    final devices = <String, LocalNetworkDevice>{};
    try {
      // Bind to Wi-Fi instead of 0.0.0.0 so iOS does not accidentally select
      // a cellular or VPN route for the multicast probes.
      socket = await RawDatagramSocket.bind(InternetAddress(localIp), 0);
      socket.broadcastEnabled = true;
      subscription = socket.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          Datagram? datagram;
          while ((datagram = socket?.receive()) != null) {
            final response = datagram!;
            final ip = response.address.address;
            if (!_isPrivateIpv4(ip) || ip == localIp) continue;
            final body = const Utf8Decoder(
              allowMalformed: true,
            ).convert(response.data);
            final isOnvif =
                body.contains('ProbeMatches') ||
                body.toLowerCase().contains('onvif.org');
            devices[ip] = _mergeDevice(
              devices[ip],
              LocalNetworkDevice(
                ipAddress: ip,
                deviceName:
                    _cameraNameFromDiscovery(body) ??
                    (isOnvif ? 'Camera ONVIF' : null),
                deviceType: isOnvif
                    ? LocalNetworkDeviceType.camera
                    : LocalNetworkDeviceType.unknown,
                isRouter: ip == routerIp,
              ),
            );
          }
        },
        // UDP discovery is optional. A route may disappear while Wi-Fi or a
        // VPN changes, so consume the socket event and let other scans run.
        onError: (Object _) {},
      );

      const ssdpProbe =
          'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 2\r\n'
          'ST: ssdp:all\r\n\r\n';
      final messageId = DateTime.now().microsecondsSinceEpoch;
      final onvifProbe =
          '<?xml version="1.0" encoding="UTF-8"?>'
          '<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope" '
          'xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing" '
          'xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery" '
          'xmlns:dn="http://www.onvif.org/ver10/network/wsdl">'
          '<e:Header><w:MessageID>uuid:$messageId</w:MessageID>'
          '<w:To e:mustUnderstand="true">urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>'
          '<w:Action e:mustUnderstand="true">http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action>'
          '</e:Header><e:Body><d:Probe><d:Types>dn:NetworkVideoTransmitter</d:Types>'
          '</d:Probe></e:Body></e:Envelope>';
      final multicastAddress = InternetAddress('239.255.255.250');
      _trySendUdp(socket, ssdpProbe, multicastAddress, 1900);
      _trySendUdp(socket, onvifProbe, multicastAddress, 3702);
      await Future<void>.delayed(const Duration(milliseconds: 2800));
      return devices.values.toList();
    } on Object {
      return const [];
    } finally {
      await subscription?.cancel();
      socket?.close();
    }
  }

  void _trySendUdp(
    RawDatagramSocket socket,
    String payload,
    InternetAddress address,
    int port,
  ) {
    try {
      socket.send(utf8.encode(payload), address, port);
    } on SocketException {
      // TCP, Bonjour, and router discovery remain available.
    }
  }

  String? _cameraNameFromDiscovery(String response) {
    final scopes = RegExp(
      r'<(?:\w+:)?Scopes[^>]*>(.*?)</(?:\w+:)?Scopes>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(response)?.group(1);
    if (scopes == null) return null;
    for (final scope in scopes.split(RegExp(r'\s+'))) {
      final match = RegExp(
        r'onvif://www\.onvif\.org/name/(.+)$',
        caseSensitive: false,
      ).firstMatch(scope);
      if (match == null) continue;
      try {
        final name = Uri.decodeComponent(
          match.group(1)!,
        ).replaceAll('+', ' ').trim();
        if (name.isNotEmpty && name.length <= 80) return name;
      } on FormatException {
        // Ignore malformed ONVIF scope values.
      }
    }
    return null;
  }

  LocalNetworkDevice _mergeDevice(
    LocalNetworkDevice? existing,
    LocalNetworkDevice incoming,
  ) {
    if (existing == null) return incoming;
    final ports = {...existing.openPorts, ...incoming.openPorts}.toList()
      ..sort();
    return LocalNetworkDevice(
      ipAddress: existing.ipAddress,
      hostName: incoming.hostName ?? existing.hostName,
      deviceName: incoming.deviceName ?? existing.deviceName,
      macAddress: incoming.macAddress ?? existing.macAddress,
      modelName: incoming.modelName ?? existing.modelName,
      openPorts: ports,
      deviceType: incoming.deviceType != LocalNetworkDeviceType.unknown
          ? incoming.deviceType
          : existing.deviceType,
      isCurrentDevice: existing.isCurrentDevice || incoming.isCurrentDevice,
      isRouter: existing.isRouter || incoming.isRouter,
    );
  }

  String? _bonjourDeviceName(nsd.Service service) {
    final serviceName = _cleanBonjourName(service.name);
    if (serviceName != null && !_looksAnonymous(serviceName)) {
      return serviceName;
    }
    final hostName = _cleanBonjourHost(service.host);
    return hostName != null && !_looksAnonymous(hostName) ? hostName : null;
  }

  String? _cleanBonjourName(String? value) {
    if (value == null) return null;
    var name = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    name = name.replaceFirst(RegExp(r'^[0-9a-fA-F]{12}@'), '');
    if (name.isEmpty || name.length > 80) return null;
    return name;
  }

  String? _cleanBonjourHost(String? value) {
    if (value == null) return null;
    final host = value.trim().replaceFirst(
      RegExp(r'\.local\.?$', caseSensitive: false),
      '',
    );
    return host.isEmpty || host.length > 80 ? null : host;
  }

  bool _looksAnonymous(String value) {
    final compact = value.replaceAll(RegExp(r'[-_:]'), '');
    return RegExp(r'^[0-9a-fA-F]{12,}$').hasMatch(compact) ||
        RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(value);
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
    var hostResponded = isCurrentDevice;

    if (!isCurrentDevice) {
      await Future.wait(
        _ports.map((port) async {
          Socket? socket;
          try {
            socket = await Socket.connect(
              ip,
              port,
              timeout: const Duration(milliseconds: 400),
            );
            openPorts.add(port);
            hostResponded = true;
          } on SocketException catch (error) {
            // ECONNREFUSED means the IP answered immediately but this specific
            // port is closed. It still proves that the device is present.
            if (_isConnectionRefused(error)) hostResponded = true;
          } on TimeoutException {
            // The host did not answer this port within the scan window.
          } finally {
            socket?.destroy();
          }
        }),
      );
    }

    if (!hostResponded) return null;

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
    final deviceType = classifyLocalNetworkDevice(
      name: deviceName,
      hostName: hostName,
      openPorts: openPorts,
      isCurrentDevice: isCurrentDevice,
      isRouter: isRouter,
    );

    return LocalNetworkDevice(
      ipAddress: ip,
      hostName: hostName,
      deviceName: deviceName,
      openPorts: openPorts..sort(),
      deviceType: deviceType,
      isCurrentDevice: isCurrentDevice,
      isRouter: isRouter,
    );
  }

  bool _isConnectionRefused(SocketException error) {
    final code = error.osError?.errorCode;
    return code == 61 || // Darwin/iOS
        code == 111 || // Linux/Android
        code == 10061; // Windows
  }

  Future<String?> _httpDeviceName(String ip, List<int> openPorts) async {
    int? webPort;
    for (final port in const <int>[
      80,
      81,
      88,
      8080,
      8081,
      8000,
      5000,
      8899,
      443,
    ]) {
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
