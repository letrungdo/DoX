import 'package:do_x/services/router_repeater_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouterRepeaterService.uplinkSignalPercent', () {
    test('doubles the rssi offset wifiap_signal reports', () {
      // Measured on ROM 2.25.124: an uplink at -82 dBm reads 19 on
      // wifiap_signal and 32-43 on wifi_list.
      expect(RouterRepeaterService.uplinkSignalPercent(19), 38);
      expect(RouterRepeaterService.uplinkSignalPercent(24), 48);
    });

    test('converts a raw negative dBm the same way', () {
      expect(RouterRepeaterService.uplinkSignalPercent(-82), 36);
      expect(RouterRepeaterService.uplinkSignalPercent(-50), 100);
    });

    test('stays inside 0-100', () {
      expect(RouterRepeaterService.uplinkSignalPercent(0), 0);
      expect(RouterRepeaterService.uplinkSignalPercent(-120), 0);
      expect(RouterRepeaterService.uplinkSignalPercent(90), 100);
    });
  });
}
