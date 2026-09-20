import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/device_type.dart';

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
  imageEditor,
  asset,
  menu;

  /// Past this the bottom bar's labels start to collide; [menu] sits on top of
  /// the limit as the always-pinned last tab.
  static const maxTabs = 5;

  /// Pages a television has nothing to run them on: My Life is a photo diary
  /// shot on the phone's camera, the compass needs a magnetometer, and the
  /// image editor is built around cropping with two fingers. Listing them on a
  /// set-top box only gives the remote somewhere useless to go.
  static const _phoneOnly = <AppPage>[myLife, fengShui, imageEditor];

  /// Whether this page is worth showing on the device the app is running on.
  bool get isAvailable => !(deviceType.isTv && _phoneOnly.contains(this));

  /// Pages the user can move between the bottom bar and the menu.
  static List<AppPage> get movable =>
      values.where((page) => page != AppPage.menu && page.isAvailable).toList();

  /// The bottom bar a fresh install starts with, in the order it shows them.
  ///
  /// [menu] is absent because it is pinned as the last tab, so this is also the
  /// list that has to stay within [maxTabs].
  static const defaultTabs = <AppPage>[news, movie, chicken, electric, lunar];

  /// Where a page lands when the stored layout doesn't mention it — a fresh
  /// install, or a page added by a newer app version.
  bool get isTabByDefault => this == menu || defaultTabs.contains(this);

  /// Pages needing the shared Supabase account. Route guards don't run for tab
  /// routes, so the tab bar has to enforce this itself.
  bool get requiresSupabaseAuth =>
      this == chicken || this == movie || this == asset;

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
        // The menu tab is pinned, so it never appears in either list. A page
        // the device cannot run is dropped here too, so a layout saved on a
        // phone does not put it back on a television.
        if (page == null || page == AppPage.menu || !page.isAvailable) continue;
        if (tabs.contains(page) || menu.contains(page)) continue;
        target.add(page);
      }
    }

    addAll(tabs, storedTabs);
    addAll(menu, storedMenu);
    // Anything the stored layout never mentioned, placed where it belongs by
    // default. The default tabs go first and in their own order, so a page the
    // user has never seen lands beside the ones it was meant to sit with
    // rather than wherever the enum happens to declare it.
    for (final page in defaultTabs) {
      if (tabs.contains(page) || menu.contains(page)) continue;
      if (!page.isAvailable) continue;
      if (tabs.length < maxTabs) tabs.add(page);
    }
    for (final page in movable) {
      if (tabs.contains(page) || menu.contains(page)) continue;
      menu.add(page);
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
    menu.addAll([wifi.name, fengShui.name]);
    return sanitize(tabs, menu);
  }
}
