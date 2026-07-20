import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/enum/app_tab.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/store/app_data.dart';

/// Requires the shared Supabase account. Apply to any feature route that
/// reads/writes Supabase data.
final _supabaseAuthGuard = AutoRouteGuard.simple((resolver, _) {
  if (supabase.auth.currentSession != null) {
    resolver.next();
  } else {
    resolver.redirectUntil(const AppLoginRoute());
  }
});

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class _AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => RouteType.material();

  @override
  List<AutoRoute> get routes {
    // The stored index is a position in the user-ordered visible tab list, so
    // resolve it to a tab id before marking a child route as initial.
    final visibleTabs = AppTab.visibleFromStorage();
    final initialTabIndex = storageService.getTabIndex();
    final initialTab =
        (initialTabIndex >= 0 && initialTabIndex < visibleTabs.length)
        ? visibleTabs[initialTabIndex]
        : AppTab.news;

    return [
      CustomRoute(
        path: '/',
        initial: true,
        page: MainRoute.page,
        transitionsBuilder: TransitionsBuilders.fadeIn,
        children: [
          AutoRoute(
            initial: initialTab == AppTab.news,
            path: 'news',
            page: NewsRoute.page,
          ),
          AutoRoute(
            initial: initialTab == AppTab.chicken,
            path: 'chicken',
            page: chickenTab.page,
            guards: [_supabaseAuthGuard],
            children: [
              AutoRoute(path: '', page: ChickenRoute.page),
              AutoRoute(path: ':batchId', page: ChickenBatchDetailRoute.page),
              AutoRoute(path: 'statistics', page: ChickenStatisticsRoute.page),
              AutoRoute(path: 'cock-sales', page: CockSalesRoute.page),
              AutoRoute(
                path: 'global-expenses',
                page: GlobalExpensesRoute.page,
              ),
            ],
          ),
          AutoRoute(
            path: 'locket',
            initial: initialTab == AppTab.locket,
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
              CustomRoute(
                path: 'login',
                page: LoginRoute.page,
                transitionsBuilder: TransitionsBuilders.fadeIn,
              ),
              AutoRoute(path: 'account', page: AccountRoute.page),
              AutoRoute(path: 'trimmer', page: TrimmerRoute.page),
            ],
          ),
          AutoRoute(
            initial: initialTab == AppTab.electric,
            path: 'electric',
            page: ElectricRoute.page,
          ),
          AutoRoute(
            initial: initialTab == AppTab.lunar,
            path: 'lunar',
            page: LunarRoute.page,
          ),
          AutoRoute(
            initial: initialTab == AppTab.menu,
            path: 'menu',
            page: MenuRoute.page,
          ),
        ],
      ),
      AutoRoute(path: '/login', page: AppLoginRoute.page),
      AutoRoute(path: '/wifi-management', page: WifiManagementRoute.page),
      AutoRoute(
        path: '/feng-shui-compass',
        page: FengShuiCompassRoute.page,
      ),
      AutoRoute(path: '/settings', page: SettingsRoute.page),
      RedirectRoute(path: '*', redirectTo: '/'),
    ];
  }
}

const locketTab = EmptyShellRoute('LocketTab');
const chickenTab = EmptyShellRoute('ChickenTab');

final appRouter = _AppRouter();
