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
    // The page is only reachable as a tab when the user kept it in the bottom
    // bar; otherwise it lives in the menu and has to be pushed.
    final isTab = appVm.tabPages.contains(AppPage.electric);
    if (isTab) storageService.setActiveTabPage(AppPage.electric.name);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isTab) {
        appRouter.navigate(const MainRoute(children: [ElectricRoute()]));
      } else {
        appRouter.push(const ElectricRoute());
      }
    });
  }

  /// A tapped shared-activity push opens the chicken page on the data of the
  /// account that recorded the sale or the expense.
  void _openSharedChickenNotification() {
    final ownerId = notificationService.sharedActivityOwnerId.value;
    if (ownerId == null) return;
    notificationService.sharedActivityOwnerId.value = null;

    // As with the electric reminder: the page is a tab only while the user
    // keeps it in the bottom bar, otherwise it lives in the menu.
    final isTab = appVm.tabPages.contains(AppPage.chicken);
    if (isTab) storageService.setActiveTabPage(AppPage.chicken.name);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isTab) {
        appRouter.navigate(const MainRoute(children: [ChickenRoute()]));
      } else {
        appRouter.push(const ChickenRoute());
      }
      // After the navigation, so the page is already on screen while the
      // owner's records load in behind it.
      chickenVm.selectOwner(ownerId);
    });
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
