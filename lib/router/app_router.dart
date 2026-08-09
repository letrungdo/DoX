import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/enum/app_page.dart';
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

/// Requires the MyLife account (separate from the Supabase one).
final _myLifeAuthGuard = AutoRouteGuard.simple((resolver, _) {
  if (appData.user?.idToken != null) {
    resolver.next();
  } else {
    resolver.redirectUntil(LoginRoute());
  }
});

@AutoRouterConfig(replaceInRouteName: 'Screen|Page,Route')
class _AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => RouteType.material();

  @override
  List<AutoRoute> get routes {
    // Every movable page is declared twice: once as a tab child of MainRoute,
    // and once on the root stack under [_pushPrefix]. Which one a
    // `pushRoute`/tab switch resolves to is decided by the router that handles
    // it, so the same PageRouteInfo works in both placements and the user can
    // move a page between the bottom bar and the menu freely.
    final initialTab = _initialTab();

    return [
      CustomRoute(
        path: '/',
        initial: true,
        page: MainRoute.page,
        transitionsBuilder: TransitionsBuilders.fadeIn,
        children: [
          AutoRoute(
            initial: initialTab == AppPage.news,
            path: 'news',
            page: newsTab.page,
            children: [
              AutoRoute(path: '', page: NewsRoute.page),
              AutoRoute(path: 'detail', page: MarketDetailRoute.page),
            ],
          ),
          AutoRoute(
            initial: initialTab == AppPage.chicken,
            path: 'chicken',
            page: chickenTab.page,
            guards: [_supabaseAuthGuard],
            children: [
              AutoRoute(path: '', page: ChickenRoute.page),
              AutoRoute(path: ':batchId', page: ChickenBatchDetailRoute.page),
              AutoRoute(path: 'statistics', page: ChickenStatisticsRoute.page),
              AutoRoute(path: 'settings', page: ChickenSettingsRoute.page),
              AutoRoute(path: 'cock-sales', page: CockSalesRoute.page),
              AutoRoute(
                path: 'global-expenses',
                page: GlobalExpensesRoute.page,
              ),
            ],
          ),
          AutoRoute(
            path: 'myLife',
            initial: initialTab == AppPage.myLife,
            page: myLifeTab.page,
            children: [
              AutoRoute(
                path: '',
                page: MyLifeRoute.page,
                guards: [_myLifeAuthGuard],
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
            initial: initialTab == AppPage.electric,
            path: 'electric',
            page: ElectricRoute.page,
          ),
          AutoRoute(
            initial: initialTab == AppPage.lunar,
            path: 'lunar',
            page: LunarRoute.page,
          ),
          AutoRoute(
            initial: initialTab == AppPage.wifi,
            path: 'wifi',
            page: WifiManagementRoute.page,
          ),
          AutoRoute(
            initial: initialTab == AppPage.fengShui,
            path: 'feng-shui',
            page: FengShuiCompassRoute.page,
          ),
          AutoRoute(
            initial: initialTab == AppPage.movie,
            path: 'movie',
            page: MovieRoute.page,
          ),
          AutoRoute(
            initial: initialTab == AppPage.menu,
            path: 'menu',
            page: MenuRoute.page,
          ),
        ],
      ),
      AutoRoute(path: '/login', page: AppLoginRoute.page),
      AutoRoute(
        path: '/account',
        page: AppAccountRoute.page,
        guards: [_supabaseAuthGuard],
      ),
      // Neither of these is guarded: both are reached *without* a session, by
      // someone on their way to one. A guard would bounce them to the login
      // form they came from.
      AutoRoute(path: '/account/password', page: UpdatePasswordRoute.page),
      AutoRoute(path: '/login/code', page: VerifyOtpRoute.page),
      AutoRoute(path: '/settings', page: SettingsRoute.page),
      ..._pushableFeatureRoutes,
      RedirectRoute(path: '*', redirectTo: '/'),
    ];
  }

  /// Root-stack copies of the feature pages, used when a page lives in the
  /// menu and is pushed on top of the bottom bar instead of being a tab.
  /// Their sub-pages are here too, so a pushed page navigates within the root
  /// stack the same way it navigates inside its tab.
  List<AutoRoute> get _pushableFeatureRoutes => [
    AutoRoute(path: '$_pushPrefix/news', page: NewsRoute.page),
    AutoRoute(path: '$_pushPrefix/news/detail', page: MarketDetailRoute.page),
    AutoRoute(
      path: '$_pushPrefix/chicken',
      page: ChickenRoute.page,
      guards: [_supabaseAuthGuard],
    ),
    AutoRoute(
      path: '$_pushPrefix/chicken/:batchId',
      page: ChickenBatchDetailRoute.page,
    ),
    AutoRoute(
      path: '$_pushPrefix/chicken/statistics',
      page: ChickenStatisticsRoute.page,
    ),
    AutoRoute(
      path: '$_pushPrefix/chicken/settings',
      page: ChickenSettingsRoute.page,
    ),
    AutoRoute(
      path: '$_pushPrefix/chicken/cock-sales',
      page: CockSalesRoute.page,
    ),
    AutoRoute(
      path: '$_pushPrefix/chicken/global-expenses',
      page: GlobalExpensesRoute.page,
    ),
    AutoRoute(
      path: '$_pushPrefix/myLife',
      page: MyLifeRoute.page,
      guards: [_myLifeAuthGuard],
    ),
    CustomRoute(
      path: '$_pushPrefix/myLife/login',
      page: LoginRoute.page,
      transitionsBuilder: TransitionsBuilders.fadeIn,
    ),
    AutoRoute(path: '$_pushPrefix/myLife/account', page: AccountRoute.page),
    AutoRoute(path: '$_pushPrefix/myLife/trimmer', page: TrimmerRoute.page),
    AutoRoute(path: '$_pushPrefix/electric', page: ElectricRoute.page),
    AutoRoute(
      path: '$_pushPrefix/electric/settings',
      page: ElectricSettingsRoute.page,
    ),
    AutoRoute(path: '$_pushPrefix/lunar', page: LunarRoute.page),
    AutoRoute(path: '/wifi-management', page: WifiManagementRoute.page),
    AutoRoute(path: '/feng-shui-compass', page: FengShuiCompassRoute.page),
    AutoRoute(
      path: '/movie',
      page: MovieRoute.page,
      guards: [_supabaseAuthGuard],
    ),
    AutoRoute(
      path: '/movie/detail',
      page: MovieDetailRoute.page,
      guards: [_supabaseAuthGuard],
    ),
  ];

  /// The tab to mark as initial: the one the user was last on, as long as it
  /// is still in the bottom bar.
  AppPage _initialTab() {
    final tabs = AppPage.tabsFromStorage();
    var tab = AppPage.byName(storageService.getActiveTabPage());
    if (tab == null) {
      // Upgrading from the index-based key: resolve it against today's bar.
      final legacyIndex = storageService.getLegacyTabIndex();
      if (legacyIndex >= 0 && legacyIndex < tabs.length) {
        tab = tabs[legacyIndex];
      }
    }
    return (tab != null && tabs.contains(tab)) ? tab : tabs.first;
  }
}

/// Path prefix keeping the root-stack copies of tab pages from colliding with
/// the tab URLs.
const _pushPrefix = '/p';

const newsTab = EmptyShellRoute('NewsTab');
const myLifeTab = EmptyShellRoute('MyLifeTab');
const chickenTab = EmptyShellRoute('ChickenTab');

final appRouter = _AppRouter();
