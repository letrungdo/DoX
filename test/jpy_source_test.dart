import 'package:do_x/model/fx/jpy_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('best JPY source', () {
    test('picks the provider paying the most đồng per yen', () {
      final best = JpySource.best({
        'google_jpy_vnd': 166.426596,
        'smile_jpy_vnd': 165.7,
        'moneygram_jpy_vnd': 165.844,
        'dcom_jpy_vnd': 166.0,
      })!;

      expect(best.source, JpySource.google);
      expect(best.source.label, 'Google');
      expect(best.rate, 166.426596);
    });

    test('a provider that failed to fetch drops out of the comparison', () {
      // Google is the usual winner; with its row missing the answer has to be
      // the best of what is left, not "no rate".
      final best = JpySource.best({
        'smile_jpy_vnd': 165.7,
        'dcom_jpy_vnd': 166.0,
      })!;

      expect(best.source, JpySource.dcom);
    });

    test('a tie keeps the first provider rather than flickering', () {
      final best = JpySource.best({
        'google_jpy_vnd': 166.0,
        'dcom_jpy_vnd': 166.0,
      })!;

      expect(best.source, JpySource.google);
    });

    test('no rates yet means no winner, not a zero', () {
      expect(JpySource.best(const {}), isNull);
      expect(JpySource.best(const {'usdt_vnd': 25823}), isNull);
    });

    test('every source names a row the fx table actually carries', () {
      const published = {
        'google_jpy_vnd',
        'smile_jpy_vnd',
        'moneygram_jpy_vnd',
        'dcom_jpy_vnd',
      };

      for (final source in JpySource.values) {
        expect(published, contains(source.code));
      }
    });
  });
}
