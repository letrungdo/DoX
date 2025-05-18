import 'package:do_x/services/storage_service.dart';
import 'package:do_x/view_model/core/core_view_model.dart';
import 'package:flutter/material.dart';

class AppViewModel extends CoreViewModel {
  ThemeMode _themeMode = storageService.getThemeMode();
  ThemeMode get themeMode => _themeMode;

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
}
