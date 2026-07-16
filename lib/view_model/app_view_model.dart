import 'package:do_x/services/storage_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';

class AppViewModel extends CoreViewModel {
  ThemeMode _themeMode = storageService.getThemeMode();
  ThemeMode get themeMode => _themeMode;

  Locale? _locale = storageService.getLocale() != null ? Locale(storageService.getLocale()!) : null;
  Locale? get locale => _locale;

  bool _showLocketTab = storageService.getShowLocketTab();
  bool get showLocketTab => _showLocketTab;

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
}
