import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/extensions/app_page_extensions.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/store/immersive_mode.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/main_view_model.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/update_download_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The icon pair and label one tab is drawn with, shared by the phone's bottom
/// bar and the television's side rail so a tab cannot end up looking like two
/// different tabs on two devices.
typedef _NavVisuals = ({Widget icon, Widget activeIcon, String label});

@RoutePage()
class MainScreen extends StatefulScreen implements AutoRouteWrapper {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MainViewModel(), //
      child: this,
    );
  }
}

class _MainScreenState extends ScreenState<MainScreen, MainViewModel> {
  bool _checkedInitialAuth = false;

  static const _inactiveIconFilter = ColorFilter.matrix([
    0.138,
    0.465,
    0.047,
    0,
    0,
    0.138,
    0.465,
    0.047,
    0,
    0,
    0.138,
    0.465,
    0.047,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  /// Selected tabs keep full color; inactive SVGs become dark grayscale while
  /// preserving the original light and dark details.
  _NavVisuals _navItem(SvgGenImage asset, String label) => (
    icon: asset.svg(width: 26, height: 26, colorFilter: _inactiveIconFilter),
    activeIcon: asset.svg(width: 26, height: 26),
    label: label,
  );

  /// Nav item backed by a Material [IconData] for tabs without a cute SVG.
  _NavVisuals _navItemIcon(IconData icon, String label) => (
    icon: Icon(icon, size: 26, color: Colors.grey),
    activeIcon: Icon(
      icon,
      size: 26,
      color: Theme.of(context).colorScheme.primary,
    ),
    label: label,
  );

  _NavVisuals _navVisualsOf(AppPage page, AppLocalizations l10n) {
    final label = page.tabLabel(l10n);
    return switch (page) {
      AppPage.news => _navItem(Assets.images.newsCute, label),
      AppPage.chicken => _navItem(Assets.images.chickCute, label),
      AppPage.myLife => _navItem(Assets.images.heartCute, label),
      AppPage.electric => _navItem(Assets.images.lampCute, label),
      AppPage.menu => _navItem(Assets.images.menuCute, label),
      _ => _navItemIcon(page.icon, label),
    };
  }

  BottomNavigationBarItem _navItemOf(AppPage page, AppLocalizations l10n) {
    final visuals = _navVisualsOf(page, l10n);
    return BottomNavigationBarItem(
      icon: visuals.icon,
      activeIcon: visuals.activeIcon,
      label: visuals.label,
    );
  }

  /// The same tab, drawn for the rail a television navigates with.
  NavigationRailDestination _railDestinationOf(
    AppPage page,
    AppLocalizations l10n,
  ) {
    final visuals = _navVisualsOf(page, l10n);
    return NavigationRailDestination(
      icon: visuals.icon,
      selectedIcon: visuals.activeIcon,
      label: Text(visuals.label),
    );
  }

  /// [BottomNavigationBar] reserves the whole home-indicator inset below its
  /// items, which on iOS leaves them floating a finger's width above the edge.
  /// Keeping half of it still clears the indicator while pulling the bar down
  /// into the safe area.
  Widget _tightenSafeArea(BuildContext context, Widget bar) {
    final mediaQuery = MediaQuery.of(context);
    final inset = mediaQuery.viewPadding.bottom;
    if (inset <= 0) return bar;

    final reduced = inset / 2;
    return MediaQuery(
      data: mediaQuery.copyWith(
        viewPadding: mediaQuery.viewPadding.copyWith(bottom: reduced),
        padding: mediaQuery.padding.copyWith(bottom: reduced),
      ),
      child: bar,
    );
  }

  /// Full-screen video asks for the whole screen, so the bar disappears
  /// instead of eating the bottom of the player.
  Widget _hideWhileImmersive(Widget bar) {
    return ValueListenableBuilder<bool>(
      valueListenable: immersiveMode,
      builder: (context, isImmersive, child) =>
          isImmersive ? const SizedBox.shrink() : child!,
      child: bar,
    );
  }

  /// Route guards don't run for tab routes, so when the app starts directly on
  /// a tab that needs the Supabase account we have to require login here.
  void _requireLoginForInitialTab(
    BuildContext context,
    TabsRouter tabsRouter,
    List<AppPage> tabs,
  ) {
    if (_checkedInitialAuth) return;
    _checkedInitialAuth = true;

    final index = tabsRouter.activeIndex;
    if (index < 0 || index >= tabs.length) return;
    if (!tabs[index].requiresSupabaseAuth) return;
    if (supabase.auth.currentSession != null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.pushRoute(const AppLoginRoute());
      if (supabase.auth.currentSession == null) {
        tabsRouter.setActiveIndex(0);
      }
    });
  }

  Future<void> _onTabSelected(
    BuildContext context, {
    required TabsRouter tabsRouter,
    required List<AppPage> tabs,
    required List<PageRouteInfo> routes,
    required int value,
  }) async {
    final page = tabs[value];
    if (page.requiresSupabaseAuth && supabase.auth.currentSession == null) {
      await context.pushRoute(const AppLoginRoute());
      if (supabase.auth.currentSession == null) return;
    }
    if (value == tabsRouter.activeIndex) {
      // If the tab has a detail screen pushed on its nested stack, re-tapping
      // goes back one level instead of reloading the tab's root.
      final innerRouter = tabsRouter.stackRouterOfIndex(value);
      if (innerRouter != null && innerRouter.canPop()) {
        await innerRouter.maybePop();
        return;
      }
      await vm.handleTabReselect(routes[value].routeName);
      return;
    }
    tabsRouter.setActiveIndex(value);
    storageService.setActiveTabPage(page.name);
    // Switching to another tab re-fetches that tab's data, wherever the user
    // had scrolled it to.
    await vm.handleTabSwitch(routes[value].routeName);
  }

  /// The tab switcher a television gets, down the left edge instead of along
  /// the bottom.
  ///
  /// Not a style choice — it is the only placement a remote can actually use. A
  /// bar under the content is only reachable by walking the D-pad *past* every
  /// row of the page, which on a feed of a few hundred articles means it is not
  /// reachable at all. Beside the content it sits level with whatever row is
  /// focused, so one press of LEFT lands on it from anywhere in the list.
  Widget _buildTabRail(
    BuildContext context, {
    required TabsRouter tabsRouter,
    required List<AppPage> tabs,
    required List<PageRouteInfo> routes,
    required AppLocalizations l10n,
  }) {
    return ColoredBox(
      color: context.neu.base,
      // The tab host does not inset its own body (each tab is a full page that
      // insets itself), so the rail has to clear the TV's overscan band on the
      // left itself. Not on the right: that edge is the seam with the content.
      child: SafeArea(
        right: false,
        child: NavigationRail(
          selectedIndex: tabsRouter.activeIndex.clamp(0, routes.length - 1),
          onDestinationSelected: (value) => _onTabSelected(
            context,
            tabsRouter: tabsRouter,
            tabs: tabs,
            routes: routes,
            value: value,
          ),
          // Every label on show: a television is read from across a room, and
          // there is no hovering or long-pressing an icon to find out what it
          // is.
          labelType: NavigationRailLabelType.all,
          destinations: tabs
              .map((tab) => _railDestinationOf(tab, l10n))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Selector<AppViewModel, List<AppPage>>(
      selector: (_, vm) => vm.visibleTabs,
      shouldRebuild: (previous, next) => !listEquals(previous, next),
      builder: (context, tabs, _) {
        final routes = tabs.map((page) => page.route).toList();

        return AutoTabsRouter(
          key: ValueKey('main-tabs-${tabs.map((e) => e.name).join('-')}'),
          routes: routes,
          transitionBuilder: (context, child, animation) =>
              FadeTransition(opacity: animation, child: child),
          builder: (context, child) {
            final tabsRouter = AutoTabsRouter.of(context);
            _requireLoginForInitialTab(context, tabsRouter, tabs);

            final isTv = deviceType.isTv;
            final content = Stack(
              children: [
                child,
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: const UpdateDownloadToast(),
                ),
              ],
            );

            return AppScaffold(
              // Each tab is a full page with its own app bar, so it applies its
              // own side insets; consuming them here would inset it twice.
              bodyHorizontal: false,
              // Flush with the scaffold, no shade: an upward shadow here read as
              // a seam across the whole screen instead of a lifted bar.
              bottomNavigationBar: isTv
                  ? null
                  : _hideWhileImmersive(
                      _tightenSafeArea(
                        context,
                        ColoredBox(
                          color: context.neu.base,
                          child: BottomNavigationBar(
                            currentIndex: tabsRouter.activeIndex.clamp(
                              0,
                              routes.length - 1,
                            ),
                            onTap: (value) => _onTabSelected(
                              context,
                              tabsRouter: tabsRouter,
                              tabs: tabs,
                              routes: routes,
                              value: value,
                            ),
                            items: tabs
                                .map((tab) => _navItemOf(tab, l10n))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
              body: !isTv
                  ? content
                  : Row(
                      children: [
                        _hideWhileImmersive(
                          _buildTabRail(
                            context,
                            tabsRouter: tabsRouter,
                            tabs: tabs,
                            routes: routes,
                            l10n: l10n,
                          ),
                        ),
                        // The rail has already spent the left inset; leaving it
                        // in the media query would inset the page a second time
                        // against the rail's own edge.
                        Expanded(
                          child: MediaQuery.removePadding(
                            context: context,
                            removeLeft: true,
                            child: content,
                          ),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}
