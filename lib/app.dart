import 'package:auto_route/auto_route.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/constants/enum/app_page.dart';
import 'package:do_x/router/app_router.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/router/navigator_observer.dart';
import 'package:do_x/services/location_service.dart';
import 'package:do_x/services/notification_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/my_life/auth_service.dart';
import 'package:do_x/services/my_life/my_life_service.dart';
import 'package:do_x/services/my_life/upload_service.dart';
import 'package:do_x/services/weather_service.dart';
import 'package:do_x/services/macos_status_bar_service.dart';
import 'package:do_x/services/web_socket/web_socket_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:toastification/toastification.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final appVm = AppViewModel();
  final chickenVm = ChickenViewModel();

  @override
  void initState() {
    super.initState();
    appVm.setCurrentContext(context);
    appVm.initState();
    chickenVm.setCurrentContext(context);
    chickenVm.initState();
    notificationService.electricNotificationMonth.addListener(
      _openElectricNotification,
    );
    notificationService.sharedActivityOwnerId.addListener(
      _openSharedChickenNotification,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openElectricNotification();
      // A push that launched the app is read asynchronously, so it can land
      // either side of the listener above.
      _openSharedChickenNotification();
      webSocketService
          .connect(); // Ensure socket connects immediately on app launch
      macOSStatusBarService.init(webSocketService);
    });
  }

  void _openElectricNotification() {
    final month = notificationService.electricNotificationMonth.value;
    if (month == null) return;
    notificationService.electricNotificationMonth.value = null;

    appVm.requestElectricMonth(month);
    _afterFrame(() => _showPage(AppPage.electric, const ElectricRoute()));
  }

  /// A tapped shared-activity push opens the chicken page on the data of the
  /// account that recorded the sale or the expense.
  void _openSharedChickenNotification() {
    final ownerId = notificationService.sharedActivityOwnerId.value;
    if (ownerId == null) return;
    notificationService.sharedActivityOwnerId.value = null;

    _afterFrame(() {
      _showPage(AppPage.chicken, const ChickenRoute());
      // After the navigation, so the page is already on screen while the
      // owner's records load in behind it.
      chickenVm.selectOwner(ownerId);
    });
  }

  /// Runs [action] once the frame in progress is done — the app can be mid
  /// build when a notification arrives.
  ///
  /// The frame has to be *asked for*: an app sitting idle in the foreground,
  /// which is exactly where a tapped banner finds it, draws no frames at all,
  /// so a plain post-frame callback would wait until something else woke the
  /// engine up — in practice the next time the app was resumed.
  void _afterFrame(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Brings [page] to the front from wherever the app was, for a notification
  /// that names it. Never stacks a second copy of a page already open.
  ///
  /// A page is a tab only while the user keeps it in the bottom bar, otherwise
  /// it lives in the menu and is pushed. Switching tab goes through the tabs
  /// router, the way the bottom bar itself does: a tab can be a child of a
  /// shell route, which `navigate` resolves to the root-stack copy of the page
  /// instead of to the tab.
  void _showPage(AppPage page, PageRouteInfo route) {
    final index = appVm.visibleTabs.indexOf(page);
    final tabsRouter = appRouter.innerRouterOf<TabsRouter>(MainRoute.name);
    if (index < 0 || tabsRouter == null) {
      // From the menu the page is pushed — unless it is already open, in which
      // case come back to it rather than stack a second copy of it.
      if (appRouter.stackData.any((data) => data.name == route.routeName)) {
        appRouter.popUntilRouteWithName(route.routeName);
      } else {
        appRouter.push(route);
      }
      return;
    }

    storageService.setActiveTabPage(page.name);
    // Anything sitting on top of the bottom bar — a pushed page, a settings
    // screen — would otherwise hide the tab we just switched to.
    appRouter.popUntilRouteWithName(MainRoute.name);
    tabsRouter.setActiveIndex(index);
    // A tab keeps its own stack, so it can still be showing a detail page from
    // last time.
    tabsRouter.stackRouterOfIndex(index)?.popUntilRoot();
  }

  @override
  void dispose() {
    notificationService.electricNotificationMonth.removeListener(
      _openElectricNotification,
    );
    notificationService.sharedActivityOwnerId.removeListener(
      _openSharedChickenNotification,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()), //
        Provider<MyLifeService>(create: (_) => MyLifeService()),
        Provider<UploadService>(create: (_) => UploadService()),
        Provider<WeatherService>(create: (_) => WeatherService()),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<WebSocketService>.value(value: webSocketService),
        ChangeNotifierProvider(create: (_) => appVm),
        ChangeNotifierProvider(create: (_) => chickenVm),
      ],
      child: Selector<AppViewModel, (ThemeMode, Locale?)>(
        selector: (p0, p1) => (p1.themeMode, p1.locale),
        builder: (context, data, _) {
          return MaterialApp.router(
            title: 'Do X',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: data.$1,
            locale: data.$2 ?? AppLocalizations.supportedLocales.first,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: appRouter.config(
              navigatorObservers: () => [MyObserver()],
            ),
            // The system navigation bar style is resolved from the region at
            // the bottom of the screen, which an AppBar never covers, so it has
            // to be annotated at the root of the app.
            builder: (context, child) {
              final style = Theme.of(context).appBarTheme.systemOverlayStyle;
              if (child == null || style == null) {
                return ToastificationWrapper(
                  child: child ?? const SizedBox.shrink(),
                );
              }
              return ToastificationWrapper(
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: style,
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
