import 'package:auto_route/auto_route.dart';
import 'package:do_x/router/app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class _AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => RouteType.material();

  @override
  List<AutoRoute> get routes => [
    CustomRoute(
      path: "/",
      page: InitRoute.page, //
      transitionsBuilder: TransitionsBuilders.fadeIn,
    ),
    CustomRoute(
      path: '/login', //
      page: LoginRoute.page,
      transitionsBuilder: TransitionsBuilders.fadeIn,
    ),
    CustomRoute(
      path: '/main',
      page: MainRoute.page,
      transitionsBuilder: TransitionsBuilders.fadeIn,
      children: [
        AutoRoute(path: 'locket', page: LocketRoute.page), //
        AutoRoute(path: 'menu', page: MenuRoute.page),
      ],
    ),
  ];
}

final appRouter = _AppRouter();
