import 'package:do_x/services/storage_service.dart';

/// Result of reading the user's page layout: the bottom-bar pages in order,
/// and the menu pages in order. [AppPage.menu] is in neither — it is pinned.
typedef PageLayout = ({List<AppPage> tabs, List<AppPage> menu});

/// Every page the user can place either in the bottom tab bar or in the menu.
///
/// [menu] is the one exception: it is always the last bottom tab, so Settings
/// and the menu-placed pages stay reachable whatever the user configures.
enum AppPage {
  news,
  chicken,
  myLife,
  electric,
  lunar,
  wifi,
  fengShui,
  movie,
  menu;

  /// Past this the bottom bar's labels start to collide; [menu] sits on top of
  /// the limit as the always-pinned last tab.
  static const maxTabs = 5;

  /// Pages the user can move between the bottom bar and the menu.
  static List<AppPage> get movable =>
      values.where((page) => page != AppPage.menu).toList();

  /// Where a page lands when the stored layout doesn't mention it — a fresh
  /// install, or a page added by a newer app version.
  bool get isTabByDefault => switch (this) {
    news || chicken || electric || lunar || menu => true,
    _ => false,
  };

  /// Pages needing the shared Supabase account. Route guards don't run for tab
  /// routes, so the tab bar has to enforce this itself.
  bool get requiresSupabaseAuth => this == chicken || this == movie;

  static AppPage? byName(String? name) =>
      values.where((page) => page.name == name).firstOrNull;

  /// The stored layout, repaired: unknown names are dropped, a page listed
  /// twice keeps its first spot, and anything the layout never mentioned falls
  /// back to its default placement.
  static PageLayout layoutFromStorage() {
    final storedTabs = storageService.getTabPages();
    final storedMenu = storageService.getMenuPages();
    if (storedTabs == null && storedMenu == null) return _migrateLegacyLayout();
    return sanitize(storedTabs, storedMenu);
  }

  /// Bottom bar pages in user order, including the pinned [menu] tab — for use
  /// before the view models exist (router setup).
  static List<AppPage> tabsFromStorage() {
    return [...layoutFromStorage().tabs, AppPage.menu];
  }

  static PageLayout sanitize(
    List<String>? storedTabs,
    List<String>? storedMenu,
  ) {
    final tabs = <AppPage>[];
    final menu = <AppPage>[];

    void addAll(List<AppPage> target, List<String>? names) {
      for (final name in names ?? const <String>[]) {
        final page = byName(name);
        // The menu tab is pinned, so it never appears in either list.
        if (page == null || page == AppPage.menu) continue;
        if (tabs.contains(page) || menu.contains(page)) continue;
        target.add(page);
      }
    }

    addAll(tabs, storedTabs);
    addAll(menu, storedMenu);
    for (final page in movable) {
      if (tabs.contains(page) || menu.contains(page)) continue;
      final asTab = page.isTabByDefault && tabs.length < maxTabs;
      (asTab ? tabs : menu).add(page);
    }
    if (tabs.length > maxTabs) {
      menu.insertAll(0, tabs.sublist(maxTabs));
      tabs.removeRange(maxTabs, tabs.length);
    }
    return (tabs: tabs, menu: menu);
  }

  /// Layout for users upgrading from the tab-order + visibility-switch
  /// settings that preceded this: the tabs they kept visible stay tabs in the
  /// same order, the ones they hid join the pages the menu already listed.
  static PageLayout _migrateLegacyLayout() {
    final legacyOrder = storageService.getLegacyTabOrder();
    if (legacyOrder == null) return sanitize(null, null);

    final legacyVisible = {
      AppPage.myLife: storageService.getLegacyShowMyLifeTab(),
      AppPage.electric: storageService.getLegacyShowElectricTab(),
      AppPage.lunar: storageService.getLegacyShowLunarTab(),
    };
    final tabs = <String>[];
    final menu = <String>[];
    for (final name in legacyOrder) {
      final page = byName(name);
      if (page == null || page == AppPage.menu) continue;
      ((legacyVisible[page] ?? true) ? tabs : menu).add(name);
    }
    // Pages that only ever lived in the menu before this feature existed.
    menu.addAll([wifi.name, fengShui.name, movie.name]);
    return sanitize(tabs, menu);
  }
}
