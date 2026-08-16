import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:flutter/material.dart';

/// Presentation of a page, shared by the bottom bar, the menu and Settings so
/// a page reads the same wherever the user placed it.
extension AppPageX on AppPage {
  /// Short form for the bottom bar, where a long name would be truncated or
  /// crowd its neighbours. Falls back to [label] wherever it already fits.
  String tabLabel(AppLocalizations l10n) => switch (this) {
    AppPage.wifi => l10n.wifiShort,
    AppPage.fengShui => l10n.compass,
    AppPage.lunar => l10n.lunarTab,
    AppPage.imageEditor => l10n.imageEditorTab,
    _ => label(l10n),
  };

  /// Full name, used in the menu and in Settings.
  String label(AppLocalizations l10n) => switch (this) {
    AppPage.news => l10n.news,
    AppPage.chicken => l10n.chicken,
    AppPage.myLife => l10n.myLife,
    AppPage.electric => l10n.electricity,
    AppPage.lunar => l10n.lunarCalendar,
    AppPage.wifi => l10n.wifiManagement,
    AppPage.fengShui => l10n.fengShuiCompass,
    AppPage.movie => l10n.movie,
    AppPage.imageEditor => l10n.imageEditor,
    AppPage.menu => l10n.menu,
  };

  IconData get icon => switch (this) {
    AppPage.news => Icons.newspaper_rounded,
    AppPage.chicken => Icons.egg_alt_rounded,
    AppPage.myLife => Icons.favorite_rounded,
    AppPage.electric => Icons.electric_bolt_rounded,
    AppPage.lunar => Icons.calendar_month_rounded,
    AppPage.wifi => Icons.wifi_rounded,
    AppPage.fengShui => Icons.explore_rounded,
    AppPage.movie => Icons.movie_rounded,
    AppPage.imageEditor => Icons.auto_fix_high_rounded,
    AppPage.menu => Icons.menu_rounded,
  };

  /// The route for this page. The same route resolves to the tab child when
  /// the page sits in the bottom bar, and to the root-stack entry when it is
  /// pushed from the menu — auto_route picks whichever router can handle it.
  PageRouteInfo get route => switch (this) {
    AppPage.news => const NewsRoute(),
    AppPage.chicken => const ChickenRoute(),
    AppPage.myLife => const MyLifeRoute(),
    AppPage.electric => const ElectricRoute(),
    AppPage.lunar => const LunarRoute(),
    AppPage.wifi => const WifiManagementRoute(),
    AppPage.fengShui => const FengShuiCompassRoute(),
    AppPage.movie => const MovieRoute(),
    AppPage.imageEditor => const ImageEditorRoute(),
    AppPage.menu => const MenuRoute(),
  };
}
