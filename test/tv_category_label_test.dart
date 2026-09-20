import 'package:do_x/extensions/tv_category_extensions.dart';
import 'package:do_x/l10n/app_localizations_en.dart';
import 'package:do_x/l10n/app_localizations_vi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TV category labels', () {
    final vi = AppLocalizationsVi();
    final en = AppLocalizationsEn();

    test('translate the categories the playlist writes in English', () {
      expect(tvCategoryLabel('Entertainment', vi), 'Giải trí');
      expect(tvCategoryLabel('General', vi), 'Tổng hợp');
      expect(tvCategoryLabel('Sports', vi), 'Thể thao');
      expect(tvCategoryLabel('Entertainment', en), 'Entertainment');
    });

    test('read the category however the playlist cased it', () {
      expect(tvCategoryLabel('KIDS', vi), 'Thiếu nhi');
      expect(tvCategoryLabel(' movies ', vi), 'Phim');
    });

    test(
      'name the uncategorised group instead of showing upstream\'s word',
      () {
        expect(tvCategoryLabel('Undefined', vi), 'Khác');
        expect(tvCategoryLabel('Undefined', en), 'Other');
      },
    );

    test('fall back to the playlist text for a category we do not know', () {
      expect(tvCategoryLabel('Esports', vi), 'Esports');
    });
  });
}
