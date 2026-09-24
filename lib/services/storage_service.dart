import 'dart:io';

import 'package:do_x/constants/enum/market_code.dart';
import 'package:do_x/constants/storage.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StorageService {
  SharedPreferences? _prefs;

  SharedPreferences get prefs => _prefs!;

  /// Opens the store, and does nothing if it is already open.
  ///
  /// Called twice on purpose: once before the first frame, because the splash
  /// has to be painted in the theme the app is about to open in, and once
  /// again among the other initializers, which is where a failed first
  /// attempt gets its second chance.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
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

  /// Whether chicken dates are shown on the lunar calendar. Defaults to true
  /// because the recorded data (and the user) work in lunar dates.
  bool getChickenLunarDisplay() {
    return prefs.getBool(StorageKey.chickenLunarDisplay) ?? true;
  }

  Future<bool> setChickenLunarDisplay(bool value) {
    return prefs.setBool(StorageKey.chickenLunarDisplay, value);
  }

  /// Cached chicken data as a JSON string; see [ChickenViewModel].
  String? getChickenCache() {
    return prefs.getString(StorageKey.chickenCache);
  }

  Future<bool> setChickenCache(String value) {
    return prefs.setString(StorageKey.chickenCache, value);
  }

  Future<bool> clearChickenCache() {
    return prefs.remove(StorageKey.chickenCache);
  }

  /// Chicken writes that have not reached the server yet, as a JSON string;
  /// see [ChickenSyncQueue].
  String? getChickenSyncQueue() {
    return prefs.getString(StorageKey.chickenSyncQueue);
  }

  Future<bool> setChickenSyncQueue(String value) {
    return prefs.setString(StorageKey.chickenSyncQueue, value);
  }

  Future<bool> clearChickenSyncQueue() {
    return prefs.remove(StorageKey.chickenSyncQueue);
  }

  /// Selected chicken-data owner, stored as user-scoped JSON by the view model.
  String? getChickenDataSourceSelection() {
    return prefs.getString(StorageKey.chickenDataSourceSelection);
  }

  Future<bool> setChickenDataSourceSelection(String value) {
    return prefs.setString(StorageKey.chickenDataSourceSelection, value);
  }

  Future<bool> clearChickenDataSourceSelection() {
    return prefs.remove(StorageKey.chickenDataSourceSelection);
  }

  String? getLocale() {
    return prefs.getString(StorageKey.locale);
  }

  Future<bool> setLocale(String value) {
    return prefs.setString(StorageKey.locale, value);
  }

  String? getMovieBaseUrl() {
    return prefs.getString(StorageKey.movieBaseUrl);
  }

  Future<bool> setMovieBaseUrl(String value) {
    return prefs.setString(StorageKey.movieBaseUrl, value);
  }

  String? getPrimaryMovieServer() {
    try {
      return prefs.getString(StorageKey.primaryMovieServer);
    } catch (_) {
      return null;
    }
  }

  Future<bool> setPrimaryMovieServer(String value) {
    return prefs.setString(StorageKey.primaryMovieServer, value);
  }

  List<String> getMovieServers() {
    try {
      return prefs.getStringList(StorageKey.movieServers) ?? [];
    } catch (_) {
      // If the key exists but is not a list (e.g. legacy string), return empty and allow overwrite
      return [];
    }
  }

  Future<bool> setMovieServers(List<String> values) {
    return prefs.setStringList(StorageKey.movieServers, values);
  }

  String? getMovieServerLabels() {
    try {
      return prefs.getString(StorageKey.movieServerLabels);
    } catch (_) {
      return null;
    }
  }

  Future<bool> setMovieServerLabels(String value) {
    return prefs.setString(StorageKey.movieServerLabels, value);
  }

  /// Where each saved server currently redirects to, as a JSON object keyed by
  /// the address the user typed.
  String? getMovieResolvedServers() {
    try {
      return prefs.getString(StorageKey.movieResolvedServers);
    } catch (_) {
      return null;
    }
  }

  Future<bool> setMovieResolvedServers(String value) {
    return prefs.setString(StorageKey.movieResolvedServers, value);
  }

  String? getMovieCategories() {
    return prefs.getString(StorageKey.movieCategories);
  }

  Future<bool> setMovieCategories(String value) {
    return prefs.setString(StorageKey.movieCategories, value);
  }

  String? getMovieLabel() {
    return prefs.getString(StorageKey.movieLabel);
  }

  Future<bool> setMovieLabel(String value) {
    return prefs.setString(StorageKey.movieLabel, value);
  }

  String? getMovieSiteType() {
    return prefs.getString(StorageKey.movieSiteType);
  }

  Future<bool> setMovieSiteType(String value) {
    return prefs.setString(StorageKey.movieSiteType, value);
  }

  /// The stored playlist, but only when it is the one [source] asked for —
  /// the slot holds a single country, so another country's copy is no answer.
  Future<String?> getTvPlaylist(String source) async {
    if (prefs.getString(StorageKey.tvPlaylistSource) != source) return null;
    final file = await _tvPlaylistFile();
    if (file != null) {
      try {
        if (await file.exists()) return await file.readAsString();
      } on Object catch (e) {
        logger.d('StorageService could not read the TV playlist', error: e);
      }
    }
    // Where there is no file to read, and for a copy stored before the
    // playlist moved out of the preferences.
    return prefs.getString(StorageKey.tvPlaylist);
  }

  /// Stores the playlist together with its source and the moment it arrived,
  /// so its age can be judged without parsing it.
  ///
  /// The body goes to a file of its own rather than into the preferences: a
  /// country's playlist runs to hundreds of kilobytes, and the preferences
  /// are one file read whole at launch and written whole on every change.
  Future<bool> setTvPlaylist(String source, String value) async {
    await prefs.setString(StorageKey.tvPlaylistSource, source);
    await prefs.setString(
      StorageKey.tvPlaylistSavedAt,
      DateTime.now().toIso8601String(),
    );
    final file = await _tvPlaylistFile();
    if (file != null) {
      try {
        // Written beside the file and moved over it, so a write cut short
        // leaves the last whole copy rather than half of this one.
        final partial = File('${file.path}.partial');
        await partial.writeAsString(value, flush: true);
        await partial.rename(file.path);
        // The copy an older version kept in the preferences is now stale.
        await prefs.remove(StorageKey.tvPlaylist);
        return true;
      } on Object catch (e) {
        logger.d('StorageService could not write the TV playlist', error: e);
      }
    }
    return prefs.setString(StorageKey.tvPlaylist, value);
  }

  /// Where the stored playlist lives, or null where there is no file system
  /// to keep it on — the web, or a platform without the plugin — in which
  /// case the preferences hold it as they used to.
  Future<File?> _tvPlaylistFile() => _tvPlaylistFileLookup ??= () async {
    if (kIsWeb) return null;
    try {
      final directory = await getApplicationSupportDirectory();
      return File('${directory.path}/$_tvPlaylistFileName');
    } on Object catch (e) {
      logger.d('StorageService has no support directory', error: e);
      return null;
    }
  }();

  /// Looked up once: the directory does not move while the app runs.
  Future<File?>? _tvPlaylistFileLookup;

  static const _tvPlaylistFileName = 'tv_playlist.txt';

  /// Keeps the stored playlist in [directory], or in the preferences when it
  /// is null.
  ///
  /// For tests: a test has no support directory of its own to write to, and
  /// a widget test's clock never lets real file I/O finish.
  @visibleForTesting
  void debugSetTvPlaylistDirectory(Directory? directory) {
    _tvPlaylistFileLookup = SynchronousFuture(
      directory == null ? null : File('${directory.path}/$_tvPlaylistFileName'),
    );
  }

  DateTime? getTvPlaylistSavedAt(String source) {
    if (prefs.getString(StorageKey.tvPlaylistSource) != source) return null;
    final raw = prefs.getString(StorageKey.tvPlaylistSavedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// The country code the TV page was left on, if the user ever changed it.
  String? getTvCountry() => prefs.getString(StorageKey.tvCountry);

  Future<bool> setTvCountry(String value) {
    return prefs.setString(StorageKey.tvCountry, value);
  }

  /// On unless turned off. Read through the null check because the Music page
  /// can be built by a test that never opened the store.
  bool getMusicVideoEnabled() =>
      _prefs?.getBool(StorageKey.musicVideoEnabled) ?? true;

  Future<bool> setMusicVideoEnabled(bool value) async {
    return await _prefs?.setBool(StorageKey.musicVideoEnabled, value) ?? false;
  }

  String? getTvCountries() => prefs.getString(StorageKey.tvCountries);

  Future<bool> setTvCountries(String value) async {
    await prefs.setString(
      StorageKey.tvCountriesSavedAt,
      DateTime.now().toIso8601String(),
    );
    return prefs.setString(StorageKey.tvCountries, value);
  }

  DateTime? getTvCountriesSavedAt() {
    final raw = prefs.getString(StorageKey.tvCountriesSavedAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Bottom bar pages as `AppPage` names, in user order; null until the user
  /// changes the layout for the first time.
  List<String>? getTabPages() {
    return prefs.getStringList(StorageKey.tabPages);
  }

  Future<bool> setTabPages(List<String> value) {
    return prefs.setStringList(StorageKey.tabPages, value);
  }

  /// Menu pages as `AppPage` names, in user order; null until the user changes
  /// the layout for the first time.
  List<String>? getMenuPages() {
    return prefs.getStringList(StorageKey.menuPages);
  }

  Future<bool> setMenuPages(List<String> value) {
    return prefs.setStringList(StorageKey.menuPages, value);
  }

  /// Name of the bottom tab to open on launch; null before the user ever
  /// switched tabs (or when upgrading from the index-based key).
  String? getActiveTabPage() {
    return prefs.getString(StorageKey.activeTabPage);
  }

  Future<bool> setActiveTabPage(String value) {
    return prefs.setString(StorageKey.activeTabPage, value);
  }

  /// Pre-layout tab order, read once to migrate an upgrading install.
  List<String>? getLegacyTabOrder() {
    return prefs.getStringList(StorageKey.tabOrder);
  }

  /// Pre-layout active tab, as a position in the bottom bar. Only read as a
  /// fallback for [getActiveTabPage]; 1 is where the app used to start.
  int getLegacyTabIndex() {
    return prefs.getInt(StorageKey.tabIndex) ?? 1;
  }

  /// Pre-layout visibility switches, read once to migrate an upgrading
  /// install. Defaults match what those settings shipped with.
  bool getLegacyShowMyLifeTab() {
    return prefs.getBool(StorageKey.showMyLifeTab) ?? false;
  }

  bool getLegacyShowElectricTab() {
    return prefs.getBool(StorageKey.showElectricTab) ?? true;
  }

  bool getLegacyShowLunarTab() {
    return prefs.getBool(StorageKey.showLunarTab) ?? true;
  }

  bool getElectricReminderEnabled() {
    return prefs.getBool(StorageKey.electricReminder) ?? false;
  }

  Future<bool> setElectricReminderEnabled(bool value) {
    return prefs.setBool(StorageKey.electricReminder, value);
  }

  /// Markets shown on the news page. Unknown codes (a symbol the API dropped,
  /// or an install rolled back to an older build) are filtered out on read, and
  /// an empty result falls back to the defaults so the card is never blank.
  List<MarketCode> getMarketCodes() {
    final raw = prefs.getStringList(StorageKey.marketCodes);
    if (raw == null) return MarketCode.defaults;
    final codes = raw.map(MarketCode.from).nonNulls.toList();
    return codes.isEmpty ? MarketCode.defaults : codes;
  }

  Future<bool> setMarketCodes(List<MarketCode> value) {
    return prefs.setStringList(
      StorageKey.marketCodes,
      value.map((e) => e.code).toList(),
    );
  }

  // --- Pending background app update ---------------------------------------

  String? getPendingUpdateVersion() {
    return prefs.getString(StorageKey.pendingUpdateVersion);
  }

  String? getPendingUpdateUrl() {
    return prefs.getString(StorageKey.pendingUpdateUrl);
  }

  String? getPendingUpdateNotes() {
    return prefs.getString(StorageKey.pendingUpdateNotes);
  }

  bool getPendingUpdateDone() {
    return prefs.getBool(StorageKey.pendingUpdateDone) ?? false;
  }

  Future<void> savePendingUpdate({
    required String version,
    required String url,
    String? notes,
    bool done = false,
  }) async {
    await prefs.setString(StorageKey.pendingUpdateVersion, version);
    await prefs.setString(StorageKey.pendingUpdateUrl, url);
    if (notes != null) {
      await prefs.setString(StorageKey.pendingUpdateNotes, notes);
    } else {
      await prefs.remove(StorageKey.pendingUpdateNotes);
    }
    await prefs.setBool(StorageKey.pendingUpdateDone, done);
  }

  Future<void> setPendingUpdateDone(bool done) {
    return prefs.setBool(StorageKey.pendingUpdateDone, done);
  }

  Future<void> clearPendingUpdate() async {
    await prefs.remove(StorageKey.pendingUpdateVersion);
    await prefs.remove(StorageKey.pendingUpdateUrl);
    await prefs.remove(StorageKey.pendingUpdateNotes);
    await prefs.remove(StorageKey.pendingUpdateDone);
  }
}

final storageService = _StorageService();
