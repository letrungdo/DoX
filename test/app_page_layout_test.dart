import 'package:do_x/constants/enum/app_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPage.sanitize', () {
    test('keeps the stored placement and order of both sections', () {
      final layout = AppPage.sanitize(
        ['movie', 'news'],
        ['lunar', 'chicken', 'electric', 'locket', 'wifi', 'fengShui'],
      );

      expect(layout.tabs, [AppPage.movie, AppPage.news]);
      expect(layout.menu, [
        AppPage.lunar,
        AppPage.chicken,
        AppPage.electric,
        AppPage.locket,
        AppPage.wifi,
        AppPage.fengShui,
      ]);
    });

    test('places every page exactly once, whatever the stored data says', () {
      // 'ufo' no longer exists, 'news' is listed twice, 'movie' not at all.
      final layout = AppPage.sanitize(
        ['news', 'ufo', 'news'],
        ['news', 'lunar'],
      );

      final all = [...layout.tabs, ...layout.menu];
      expect(all.toSet(), AppPage.movable.toSet());
      expect(all.length, AppPage.movable.length);
      expect(layout.tabs.first, AppPage.news);
    });

    test('never puts the pinned menu tab in either section', () {
      final layout = AppPage.sanitize(['menu', 'news'], ['menu']);

      expect(layout.tabs, isNot(contains(AppPage.menu)));
      expect(layout.menu, isNot(contains(AppPage.menu)));
    });

    test('overflowing tabs spill into the menu', () {
      final layout = AppPage.sanitize(
        AppPage.movable.map((page) => page.name).toList(),
        null,
      );

      expect(layout.tabs.length, AppPage.maxTabs);
      expect(layout.menu, AppPage.movable.sublist(AppPage.maxTabs));
    });

    test('an empty tab bar is allowed — the menu tab stays pinned', () {
      final layout = AppPage.sanitize(
        [],
        AppPage.movable.map((page) => page.name).toList(),
      );

      expect(layout.tabs, isEmpty);
      expect(layout.menu.length, AppPage.movable.length);
    });
  });
}
