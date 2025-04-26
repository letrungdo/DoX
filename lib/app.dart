import 'package:do_ai/l10n/app_localizations.dart';
import 'package:do_ai/routes.dart';
import 'package:do_ai/services/auth_service.dart';
import 'package:do_ai/services/locket_service.dart';
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
      ],
      child: MaterialApp.router(
        title: 'Do AI',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
        locale: AppLocalizations.supportedLocales.first,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: routerConfig,
      ),
    );
  }
}
