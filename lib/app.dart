import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.dart';
import 'package:do_x/router/navigator_observer.dart';
import 'package:do_x/router/notification_routing.dart';
import 'package:do_x/services/location_service.dart';
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
  late final _notificationRouting = NotificationRouting(
    appVm: appVm,
    chickenVm: chickenVm,
  );

  @override
  void initState() {
    super.initState();
    appVm.setCurrentContext(context);
    appVm.initState();
    chickenVm.setCurrentContext(context);
    chickenVm.initState();
    _notificationRouting.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      webSocketService
          .connect(); // Ensure socket connects immediately on app launch
      macOSStatusBarService.init(webSocketService);
    });
  }

  @override
  void dispose() {
    _notificationRouting.dispose();
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
