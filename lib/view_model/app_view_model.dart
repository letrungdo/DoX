import 'package:do_x/constants/enum/app_tab.dart';
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

  bool _showLocketTab = storageService.getShowLocketTab();
  bool get showLocketTab => _showLocketTab;

  bool _showElectricTab = storageService.getShowElectricTab();
  bool get showElectricTab => _showElectricTab;

  bool _showLunarTab = storageService.getShowLunarTab();
  bool get showLunarTab => _showLunarTab;

  List<AppTab> _tabOrder = AppTab.sanitizeOrder(storageService.getTabOrder());

  DateTime? _electricMonthToHighlight;
  DateTime? get electricMonthToHighlight => _electricMonthToHighlight;

  /// Full user-defined order, including hidden tabs (for the Settings list).
  List<AppTab> get tabOrder => _tabOrder;

  /// Tabs actually shown in the bottom bar, in user order.
  List<AppTab> get visibleTabs {
    return _tabOrder.where((tab) {
      return switch (tab) {
        AppTab.locket => _showLocketTab,
        AppTab.electric => _showElectricTab,
        AppTab.lunar => _showLunarTab,
        _ => true,
      };
    }).toList();
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

  void setShowLocketTab(bool value) {
    _showLocketTab = value;
    notifyListeners();
    storageService.setShowLocketTab(value);
  }

  void setShowElectricTab(bool value) {
    _showElectricTab = value;
    notifyListeners();
    storageService.setShowElectricTab(value);
  }

  void setShowLunarTab(bool value) {
    _showLunarTab = value;
    notifyListeners();
    storageService.setShowLunarTab(value);
  }

  void setTabOrder(List<AppTab> value) {
    _tabOrder = List.of(value);
    notifyListeners();
    storageService.setTabOrder(_tabOrder.map((e) => e.name).toList());
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
