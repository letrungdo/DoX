import 'package:do_x/model/tv_country.dart';
import 'package:do_x/services/tv_catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Entries in the shape `iptv-org/api` publishes them, plus the two kinds of
/// row a catalogue can carry that the picker must not show.
const _countries = '''
[
  {"name":"Japan","code":"JP","languages":["jpn"],"flag":"🇯🇵"},
  {"name":"Vietnam","code":"VN","languages":["vie"],"flag":"🇻🇳"},
  {"name":"Albania","code":"AL","languages":["sqi"],"flag":"🇦🇱"},
  {"name":"","code":"XX","languages":[],"flag":""},
  "not an object"
]
''';

void main() {
  group('TV catalogue', () {
    test('lists Vietnam first and the rest by name', () {
      final countries = tvCatalogService.parseCountries(_countries);

      expect(countries.map((country) => country.code), ['VN', 'AL', 'JP']);
    });

    test('drops entries the picker could not show', () {
      final countries = tvCatalogService.parseCountries(_countries);

      expect(countries.any((country) => country.code == 'XX'), isFalse);
      expect(countries, hasLength(3));
    });

    test('carries what the page needs off one entry', () {
      final vietnam = tvCatalogService
          .parseCountries(_countries)
          .firstWhere((country) => country.code == TvCountry.vietnam.code);

      // The playlist file is the code lower-cased, and the flag is the only
      // artwork the catalogue has.
      expect(vietnam.playlistCode, 'vn');
      expect(vietnam.label, '🇻🇳 Vietnam');
    });
  });
}
