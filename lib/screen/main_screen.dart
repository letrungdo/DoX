import 'package:auto_route/auto_route.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
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
  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      routes: [
        const LocketRoute(), //
        const NewsRoute(),
      ],
      transitionBuilder:
          (context, child, animation) => FadeTransition(
            opacity: animation,
            // the passed child is technically our animated selected-tab page
            child: child,
          ),
      builder: (context, child) {
        final tabsRouter = AutoTabsRouter.of(context);
        return Scaffold(
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: tabsRouter.activeIndex,
            onTap: tabsRouter.setActiveIndex,
            // selectedItemColor: Colors.amber[800],
            items: <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.image), label: 'Locket'),
              BottomNavigationBarItem(icon: Icon(Icons.newspaper), label: 'News'),
            ],
          ),
          body: child,
        );
      },
    );
  }
}
