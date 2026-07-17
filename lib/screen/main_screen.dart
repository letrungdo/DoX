import 'package:auto_route/auto_route.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/main_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  BottomNavigationBarItem _navItem(SvgGenImage asset, String label) {
    return BottomNavigationBarItem(
      icon: asset.svg(width: 26, height: 26, colorFilter: _inactiveIconFilter),
      activeIcon: asset.svg(width: 26, height: 26),
      label: label,
    );
  }

  /// Route guards don't run for tab routes, so when the app starts directly
  /// on the chicken tab we have to require login here.
  void _requireLoginForInitialChickenTab(BuildContext context, TabsRouter tabsRouter, bool hasLocketTab) {
    if (_checkedInitialAuth) return;
    _checkedInitialAuth = true;

    // Chicken tab index is always 1
    if (tabsRouter.activeIndex != 1 || supabase.auth.currentSession != null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.pushRoute(const AppLoginRoute());
      if (supabase.auth.currentSession == null) {
        tabsRouter.setActiveIndex(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Selector<AppViewModel, bool>(
      selector: (_, vm) => vm.showLocketTab,
      builder: (context, showLocketTab, _) {
        final routes = [
          const NewsRoute(),
          const ChickenRoute(),
          if (showLocketTab) const LocketRoute(),
          const MenuRoute(),
        ];

        return AutoTabsRouter(
          key: ValueKey('main-tabs-$showLocketTab'),
          routes: routes,
          transitionBuilder: (context, child, animation) => FadeTransition(opacity: animation, child: child),
          builder: (context, child) {
            final tabsRouter = AutoTabsRouter.of(context);
            final unselectedColor = Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.65);
            _requireLoginForInitialChickenTab(context, tabsRouter, showLocketTab);

            return Scaffold(
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: tabsRouter.activeIndex,
                onTap: (value) async {
                  // The chicken tab index is 1.
                  if (value == 1 && supabase.auth.currentSession == null) {
                    await context.pushRoute(const AppLoginRoute());
                    if (supabase.auth.currentSession == null) return;
                  }
                  if (value == tabsRouter.activeIndex) {
                    await vm.handleTabReselect(routes[value].routeName);
                    return;
                  }
                  tabsRouter.setActiveIndex(value);
                  storageService.setTabIndex(value);
                },
                items: <BottomNavigationBarItem>[
                  _navItem(Assets.images.newsCute, l10n.news),
                  _navItem(Assets.images.chickCute, l10n.chicken),
                  if (showLocketTab) _navItem(Assets.images.heartCute, l10n.locket),
                  _navItem(Assets.images.menuCute, l10n.menu),
                ],
              ),
              body: child,
            );
          },
        );
      },
    );
  }
}
