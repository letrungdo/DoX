import 'package:auto_route/auto_route.dart';
import 'package:do_x/gen/assets.gen.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/view_model/main_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
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

  /// Route guards don't run for tab routes, so when the app starts directly
  /// on the chicken tab we have to require login here.
  void _requireLoginForInitialChickenTab(BuildContext context, TabsRouter tabsRouter) {
    if (_checkedInitialAuth) return;
    _checkedInitialAuth = true;
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
    return AutoTabsRouter(
      routes: [
        const NewsRoute(),
        const ChickenRoute(),
        const LocketRoute(), //
        const MenuRoute(),
      ],
      transitionBuilder: (context, child, animation) => FadeTransition(
        opacity: animation,
        // the passed child is technically our animated selected-tab page
        child: child,
      ),
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);
        _requireLoginForInitialChickenTab(context, tabsRouter);
        return Scaffold(
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: tabsRouter.activeIndex,
            onTap: (value) async {
              // The chicken tab needs the Supabase account; route guards don't
              // run on tab switches, so require login here.
              if (value == 1 && supabase.auth.currentSession == null) {
                await context.pushRoute(const AppLoginRoute());
                if (supabase.auth.currentSession == null) return;
              }
              tabsRouter.setActiveIndex(value);
              storageService.setTabIndex(value);
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.amber[800],
            unselectedFontSize: 12,
            selectedFontSize: 12,
            enableFeedback: true,
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'News'),
              BottomNavigationBarItem(
                icon: Builder(
                  builder: (context) => Assets.images.chicken.svg(
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(IconTheme.of(context).color!, BlendMode.srcIn),
                  ),
                ),
                label: 'Chicken',
              ),
              BottomNavigationBarItem(icon: SFIcon(SFIcons.sf_heart_fill, fontSize: 22), label: 'Locket'),
              BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'),
            ],
          ),
          body: child,
        );
      },
    );
  }
}
