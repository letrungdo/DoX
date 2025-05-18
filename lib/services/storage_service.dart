import 'package:do_x/constants/storage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StorageService {
  late final SharedPreferences prefs;

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
  }

  ThemeMode getThemeMode() {
    final raw = prefs.getString(StorageKey.themeMode);
    return switch (raw) {
      "dark" => ThemeMode.dark,
      "light" => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  Future<bool> setThemeMode(ThemeMode value) {
    return prefs.setString(StorageKey.themeMode, value.name);
  }
}

final storageService = _StorageService();
