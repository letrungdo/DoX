import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/services/notification_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';

class AppViewModel extends CoreViewModel {
  ThemeMode _themeMode = storageService.getThemeMode();
  ThemeMode get themeMode => _themeMode;

  Locale? _locale = storageService.getLocale() != null
      ? Locale(storageService.getLocale()!)
      : null;
  Locale? get locale => _locale;

  PageLayout _layout = AppPage.layoutFromStorage();

  DateTime? _electricMonthToHighlight;
  DateTime? get electricMonthToHighlight => _electricMonthToHighlight;

  /// Pages the user put in the bottom bar, in order, without the pinned menu
  /// tab — this is the list Settings edits.
  List<AppPage> get tabPages => List.unmodifiable(_layout.tabs);

  /// Pages the user left in the menu, in order.
  List<AppPage> get menuPages => List.unmodifiable(_layout.menu);

  /// What the bottom bar actually renders: the user's tabs plus the always
  /// pinned menu tab, so Settings is reachable in any layout.
  List<AppPage> get visibleTabs => [..._layout.tabs, AppPage.menu];

  bool get canAddTab => _layout.tabs.length < AppPage.maxTabs;

  /// Moves [page] into the bottom bar at [index] (appended when omitted).
  /// Returns false when the bar is already full.
  bool movePageToTabs(AppPage page, {int? index}) {
    if (page == AppPage.menu || _layout.tabs.contains(page)) return false;
    if (!canAddTab) return false;
    final tabs = List.of(_layout.tabs);
    final menu = List.of(_layout.menu)..remove(page);
    tabs.insert((index ?? tabs.length).clamp(0, tabs.length), page);
    _saveLayout(tabs, menu);
    return true;
  }

  /// Moves [page] out of the bottom bar and into the menu at [index]
  /// (appended when omitted).
  void movePageToMenu(AppPage page, {int? index}) {
    if (page == AppPage.menu || _layout.menu.contains(page)) return;
    final tabs = List.of(_layout.tabs)..remove(page);
    final menu = List.of(_layout.menu);
    menu.insert((index ?? menu.length).clamp(0, menu.length), page);
    _saveLayout(tabs, menu);
  }

  void reorderTabPages(int oldIndex, int newIndex) {
    final tabs = List.of(_layout.tabs);
    tabs.insert(newIndex, tabs.removeAt(oldIndex));
    _saveLayout(tabs, _layout.menu);
  }

  void reorderMenuPages(int oldIndex, int newIndex) {
    final menu = List.of(_layout.menu);
    menu.insert(newIndex, menu.removeAt(oldIndex));
    _saveLayout(_layout.tabs, menu);
  }

  void _saveLayout(List<AppPage> tabs, List<AppPage> menu) {
    _layout = AppPage.sanitize(
      tabs.map((e) => e.name).toList(),
      menu.map((e) => e.name).toList(),
    );
    notifyListeners();
    storageService.setTabPages(_layout.tabs.map((e) => e.name).toList());
    storageService.setMenuPages(_layout.menu.map((e) => e.name).toList());
  }

  void toggleThemeMode() {
    switch (themeMode) {
      case ThemeMode.system:
        _themeMode = ThemeMode.light;
        break;
      case ThemeMode.light:
        _themeMode = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        _themeMode = ThemeMode.system;
        break;
    }
    notifyListeners();
    storageService.setThemeMode(themeMode);
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    storageService.setThemeMode(mode);
  }

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
    storageService.setLocale(locale.languageCode);
  }

  void requestElectricMonth(DateTime month) {
    _electricMonthToHighlight = DateTime(month.year, month.month);
    notifyListenersSafe();
  }

  bool get electricReminderEnabled =>
      storageService.getElectricReminderEnabled();

  /// Returns false when the notification permission was denied.
  Future<bool> setElectricReminderEnabled(bool enabled) async {
    if (enabled && !await notificationService.requestPermission()) return false;
    try {
      if (enabled) {
        await notificationService.scheduleMonthlyElectricReminder();
      } else {
        await notificationService.cancelMonthlyElectricReminder();
      }
      await storageService.setElectricReminderEnabled(enabled);
      notifyListenersSafe();
      return true;
    } catch (e) {
      logger.e('update electric reminder setting failed', error: e);
      notifyListenersSafe();
      return false;
    }
  }
}
