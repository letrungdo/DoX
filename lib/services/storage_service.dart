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

  int getTabIndex() {
    return prefs.getInt(StorageKey.tabIndex) ?? 1;
  }

  Future<bool> setTabIndex(int index) {
    return prefs.setInt(StorageKey.tabIndex, index);
  }

  String? getRouterIp() {
    return prefs.getString(StorageKey.routerIp);
  }

  Future<bool> setRouterIp(String value) {
    return prefs.setString(StorageKey.routerIp, value);
  }

  bool getChickenNotificationsEnabled() {
    return prefs.getBool(StorageKey.chickenNotifications) ?? false;
  }

  Future<bool> setChickenNotificationsEnabled(bool value) {
    return prefs.setBool(StorageKey.chickenNotifications, value);
  }

  String? getLocale() {
    return prefs.getString(StorageKey.locale);
  }

  Future<bool> setLocale(String value) {
    return prefs.setString(StorageKey.locale, value);
  }

  bool getShowLocketTab() {
    return prefs.getBool(StorageKey.showLocketTab) ?? false;
  }

  Future<bool> setShowLocketTab(bool value) {
    return prefs.setBool(StorageKey.showLocketTab, value);
  }

  bool getShowElectricTab() {
    return prefs.getBool(StorageKey.showElectricTab) ?? true;
  }

  Future<bool> setShowElectricTab(bool value) {
    return prefs.setBool(StorageKey.showElectricTab, value);
  }

  bool getShowLunarTab() {
    return prefs.getBool(StorageKey.showLunarTab) ?? true;
  }

  Future<bool> setShowLunarTab(bool value) {
    return prefs.setBool(StorageKey.showLunarTab, value);
  }

  /// Bottom tab order as [AppTab] names; null when the user never reordered.
  List<String>? getTabOrder() {
    return prefs.getStringList(StorageKey.tabOrder);
  }

  Future<bool> setTabOrder(List<String> value) {
    return prefs.setStringList(StorageKey.tabOrder, value);
  }

  bool getElectricReminderEnabled() {
    return prefs.getBool(StorageKey.electricReminder) ?? false;
  }

  Future<bool> setElectricReminderEnabled(bool value) {
    return prefs.setBool(StorageKey.electricReminder, value);
  }
}

final storageService = _StorageService();
