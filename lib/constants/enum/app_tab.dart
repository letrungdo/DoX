import 'package:do_x/services/storage_service.dart';

/// Bottom navigation tabs. [values] order is the default tab order; the user
/// can reorder and hide some tabs in Settings.
enum AppTab {
  news,
  chicken,
  locket,
  electric,
  lunar,
  menu;

  /// True for tabs the user can hide in Settings.
  bool get isHideable =>
      this == AppTab.locket || this == AppTab.electric || this == AppTab.lunar;

  /// Restores a stored order, dropping unknown names and appending any tab
  /// missing from it (e.g. tabs added in a newer app version).
  static List<AppTab> sanitizeOrder(List<String>? stored) {
    final result = <AppTab>[];
    for (final name in stored ?? const <String>[]) {
      final tab = AppTab.values.where((t) => t.name == name).firstOrNull;
      if (tab != null && !result.contains(tab)) result.add(tab);
    }
    for (final tab in AppTab.values) {
      if (!result.contains(tab)) result.add(tab);
    }
    return result;
  }

  /// Visible tabs in user order, straight from storage — for use before the
  /// view models exist (router setup).
  static List<AppTab> visibleFromStorage() {
    final order = sanitizeOrder(storageService.getTabOrder());
    final showLocket = storageService.getShowLocketTab();
    final showElectric = storageService.getShowElectricTab();
    final showLunar = storageService.getShowLunarTab();
    return order.where((tab) {
      return switch (tab) {
        AppTab.locket => showLocket,
        AppTab.electric => showElectric,
        AppTab.lunar => showLunar,
        _ => true,
      };
    }).toList();
  }
}
