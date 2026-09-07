import 'package:do_x/constants/enum/app_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppPage.sanitize', () {
    test('keeps the stored placement and order of both sections', () {
      // Every movable page is accounted for, so nothing falls back to its
      // default placement — and the menu is stored in an order the enum does
      // not have, so a pass proves the stored order is the one that survives.
      final storedTabs = [AppPage.movie, AppPage.news];
      final storedMenu = AppPage.movable
          .where((page) => !storedTabs.contains(page))
          .toList()
          .reversed
          .toList();

      final layout = AppPage.sanitize(
        storedTabs.map((page) => page.name).toList(),
        storedMenu.map((page) => page.name).toList(),
      );

      expect(layout.tabs, storedTabs);
      expect(layout.menu, storedMenu);
    });

    test('a page the stored layout never mentions falls back to the menu', () {
      final layout = AppPage.sanitize(
        ['news'],
        // 'imageEditor' is not a tab by default, so it belongs in the menu.
        AppPage.movable
            .where(
              (page) => page != AppPage.news && page != AppPage.imageEditor,
            )
            .map((page) => page.name)
            .toList(),
      );

      expect(layout.tabs, [AppPage.news]);
      expect(layout.menu.last, AppPage.imageEditor);
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
