import 'package:do_x/constants/dimens.dart';
import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/router/app_router.dart';
import 'package:do_x/router/navigator_observer.dart';
import 'package:do_x/services/auth_service.dart';
import 'package:do_x/services/locket_service.dart';
import 'package:do_x/services/upload_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()), //
        Provider<LocketService>(create: (_) => LocketService()),
        Provider<UploadService>(create: (_) => UploadService()),
      ],
      child: MaterialApp.router(
        title: 'Do X',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true, //
        ),
        locale: AppLocalizations.supportedLocales.first,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: appRouter.config(navigatorObservers: () => [MyObserver()]),
        builder: (context, child) {
          if (kIsWeb) {
            return Center(
              child: SizedBox(
                width: Dimens.webMaxWidth, //
                child: child,
              ),
            );
          }
          return child!;
        },
      ),
    );
  }
}
