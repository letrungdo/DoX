import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/constants/enum/app_tab.dart';
import 'package:do_x/router/app_router.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/router/navigator_observer.dart';
import 'package:do_x/services/location_service.dart';
import 'package:do_x/services/notification_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/locket/auth_service.dart';
import 'package:do_x/services/locket/locket_service.dart';
import 'package:do_x/services/locket/upload_service.dart';
import 'package:do_x/services/weather_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:do_x/view_model/chicken_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openElectricNotification();
    });
  }

  void _openElectricNotification() {
    final month = notificationService.electricNotificationMonth.value;
    if (month == null) return;
    notificationService.electricNotificationMonth.value = null;

    appVm.requestElectricMonth(month);
    if (!appVm.showElectricTab) appVm.setShowElectricTab(true);
    final electricIndex = appVm.visibleTabs.indexOf(AppTab.electric);
    if (electricIndex >= 0) storageService.setTabIndex(electricIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appRouter.navigate(const MainRoute(children: [ElectricRoute()]));
    });
  }

  @override
  void dispose() {
    notificationService.electricNotificationMonth.removeListener(
      _openElectricNotification,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()), //
        Provider<LocketService>(create: (_) => LocketService()),
        Provider<UploadService>(create: (_) => UploadService()),
        Provider<WeatherService>(create: (_) => WeatherService()),
        Provider<LocationService>(create: (_) => LocationService()),
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
          );
        },
      ),
    );
  }
}
