import 'package:do_x/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await storageService.init();
  });

  test('a fresh install opens in dark', () {
    expect(storageService.getThemeMode(), ThemeMode.dark);
  });

  test('a picked theme, system included, is kept', () async {
    for (final mode in ThemeMode.values) {
      await storageService.setThemeMode(mode);
      expect(storageService.getThemeMode(), mode);
    }
  });
}
