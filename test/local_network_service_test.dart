import 'package:do_x/services/local_network_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyLocalNetworkDevice', () {
    test('recognizes Apple device names', () {
      expect(
        classifyLocalNetworkDevice(name: "Do's iPhone"),
        LocalNetworkDeviceType.phone,
      );
      expect(
        classifyLocalNetworkDevice(name: "Do's MacBook Pro"),
        LocalNetworkDeviceType.computer,
      );
      expect(
        classifyLocalNetworkDevice(name: "Do's iPad"),
        LocalNetworkDeviceType.tablet,
      );
    });

    test('recognizes Bonjour and camera fingerprints', () {
      expect(
        classifyLocalNetworkDevice(serviceType: '_workstation._tcp'),
        LocalNetworkDeviceType.computer,
      );
      expect(
        classifyLocalNetworkDevice(openPorts: const [554]),
        LocalNetworkDeviceType.camera,
      );
      expect(
        classifyLocalNetworkDevice(name: 'Camera ONVIF'),
        LocalNetworkDeviceType.camera,
      );
    });
  });
}
