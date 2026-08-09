import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/screen/settings/page_layout_editor.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the editor with a known layout and returns its view model.
Future<AppViewModel> _pump(
  WidgetTester tester, {
  required List<AppPage> tabs,
  required List<AppPage> menu,
}) async {
  await storageService.setTabPages(tabs.map((e) => e.name).toList());
  await storageService.setMenuPages(menu.map((e) => e.name).toList());

  final appVm = AppViewModel();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChangeNotifierProvider.value(
        value: appVm,
        child: const Scaffold(
          body: SingleChildScrollView(child: PageLayoutEditor()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return appVm;
}

/// Drags the handle of the row showing [page] by [dy] pixels.
Future<void> _dragPage(WidgetTester tester, AppPage page, double dy) async {
  final handle = find.descendant(
    of: find.ancestor(
      of: find.byKey(ValueKey(page)),
      matching: find.byType(ReorderableDelayedDragStartListener),
    ),
    matching: find.byIcon(Icons.drag_handle_rounded),
  );
  final target = handle.evaluate().isEmpty
      ? find.descendant(
          of: find.byKey(ValueKey(page)),
          matching: find.byIcon(Icons.drag_handle_rounded),
        )
      : handle;

  final gesture = await tester.startGesture(tester.getCenter(target.first));
  // A few small steps: the reorder list only picks the drop slot up as the
  // pointer travels over it.
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(Offset(0, dy / 10));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    // `storageService` holds a `late` prefs field, so it is initialised once
    // for the whole file and each test just rewrites the stored layout.
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await storageService.init();
  });

  testWidgets('dragging a menu page up past the header makes it a tab', (
    tester,
  ) async {
    final appVm = await _pump(
      tester,
      tabs: [AppPage.news, AppPage.chicken],
      menu: [AppPage.movie, AppPage.wifi],
    );

    // Far enough up to clear both tab rows and the MENU header.
    await _dragPage(tester, AppPage.movie, -220);

    expect(appVm.tabPages, contains(AppPage.movie));
    expect(appVm.menuPages, isNot(contains(AppPage.movie)));
  });

  testWidgets('dragging a tab down past the header sends it to the menu', (
    tester,
  ) async {
    final appVm = await _pump(
      tester,
      tabs: [AppPage.news, AppPage.chicken],
      menu: [AppPage.movie, AppPage.wifi],
    );

    await _dragPage(tester, AppPage.news, 220);

    expect(appVm.menuPages, contains(AppPage.news));
    expect(appVm.tabPages, isNot(contains(AppPage.news)));
  });

  testWidgets('a drag inside a group only reorders it', (tester) async {
    final appVm = await _pump(
      tester,
      tabs: [AppPage.news, AppPage.chicken, AppPage.electric],
      menu: [AppPage.movie],
    );
    // Pages the stored layout never mentioned fall back to their default
    // placement, so read the counts rather than assuming them.
    final tabCount = appVm.tabPages.length;
    final menuCount = appVm.menuPages.length;

    await _dragPage(tester, AppPage.news, 60);

    expect(appVm.tabPages, contains(AppPage.news));
    expect(appVm.tabPages.first, isNot(AppPage.news));
    expect(appVm.tabPages.length, tabCount);
    expect(appVm.menuPages.length, menuCount);
  });

  testWidgets('the layout editor offers no move buttons', (tester) async {
    await _pump(tester, tabs: [AppPage.news], menu: [AppPage.movie]);

    // Dragging replaced them; a stray arrow would mean the old UI came back.
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
  });
}
