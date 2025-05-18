import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.dart';
import 'package:do_x/router/navigator_observer.dart';
import 'package:do_x/services/auth_service.dart';
import 'package:do_x/services/location_service.dart';
import 'package:do_x/services/locket_service.dart';
import 'package:do_x/services/upload_service.dart';
import 'package:do_x/services/weather_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/view_model/app_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final appVm = AppViewModel();

  @override
  void initState() {
    super.initState();
    appVm.setCurrentContext(context);
    appVm.initState();
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
      ],
      child: Selector<AppViewModel, ThemeMode>(
        selector: (p0, p1) => p1.themeMode,
        builder: (context, themeMode, _) {
          return MaterialApp.router(
            title: 'Do X',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            locale: AppLocalizations.supportedLocales.first,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: appRouter.config(navigatorObservers: () => [MyObserver()]),
          );
        },
      ),
    );
  }
}
