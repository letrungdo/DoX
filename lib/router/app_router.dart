import 'package:auto_route/auto_route.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/store/app_data.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class _AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => RouteType.material();

  @override
  List<AutoRoute> get routes {
    final initialTabIndex = storageService.getTabIndex();

    return [
      CustomRoute(
        path: '/',
        initial: true,
        page: MainRoute.page,
        transitionsBuilder: TransitionsBuilders.fadeIn,
        children: [
          AutoRoute(initial: initialTabIndex == 0, path: 'news', page: NewsRoute.page),
          AutoRoute(initial: initialTabIndex == 1, path: 'chicken', page: ChickenRoute.page),
          AutoRoute(
            path: 'locket',
            initial: initialTabIndex == 2,
            page: locketTab.page,
            children: [
              AutoRoute(
                path: '',
                page: LocketRoute.page,
                guards: [
                  AutoRouteGuard.simple((resolver, _) {
                    if (appData.user?.idToken != null) {
                      resolver.next();
                    } else {
                      resolver.redirectUntil(LoginRoute());
                    }
                  }),
                ],
              ),
              CustomRoute(path: 'login', page: LoginRoute.page, transitionsBuilder: TransitionsBuilders.fadeIn),
              AutoRoute(path: 'account', page: AccountRoute.page),
              AutoRoute(path: 'trimmer', page: TrimmerRoute.page),
            ],
          ),
          AutoRoute(initial: initialTabIndex == 3, path: 'menu', page: MenuRoute.page),
        ],
      ),
      AutoRoute(path: '/chicken/:batchId', page: ChickenBatchDetailRoute.page),
      AutoRoute(path: '/chicken-statistics', page: ChickenStatisticsRoute.page),
      AutoRoute(path: '/cock-sales', page: CockSalesRoute.page),
      RedirectRoute(path: '*', redirectTo: '/'),
    ];
  }
}

const locketTab = EmptyShellRoute('LocketTab');

final appRouter = _AppRouter();
