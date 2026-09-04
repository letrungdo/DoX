import 'dart:async';

import 'package:do_x/app.dart';
import 'package:do_x/firebase_options.dart';
import 'package:do_x/services/auth_flow_service.dart';
import 'package:do_x/services/notification_service.dart';
import 'package:do_x/services/push_notification_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/app_info.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/logger.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      debugPrint = (String? message, {int? wrapWidth}) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('dox_log: $message');
        }
      };
      logger.d("init log");
      _catchAllError();
      // No `setPreferredOrientations` call at all: the app rotates freely, and
      // the set of orientations it allows is declared per platform (iOS's
      // Info.plist, Android's manifest). Asking for every orientation here
      // instead would install a preference during launch that iOS only starts
      // honouring after the first rotation — so the very first turn of the
      // device did nothing. Pages lay themselves out for landscape via
      // `AppScaffold`, which insets the body past a side notch.
      //
      // Draw behind the status bar and the (gesture) navigation bar so the
      // app's own background/bottom nav colour shows through instead of the
      // system's default bar colour.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Paint a Flutter loading screen immediately. Previously runApp was
      // called only after every plugin had initialized, leaving a blank page
      // throughout that work (especially noticeable on a cold web load).
      runApp(AppBootstrap(initialize: _initializeApp));
    },
    (error, stack) {
      logger.e("___App error!!", error: error, stackTrace: stack);
    },
  );
}

Future<void> _initializeApp() async {
  final initializers = <Future<void>>[
    storageService.init(),
    appInfo.init(),
    secureStorage.getAccount(),
    initSupabase(),
  ];

  // Neither local notifications nor Firebase Messaging is used by the web
  // app. Avoid initializing Firebase there: it adds work to the critical path
  // without enabling a feature. Native platforms keep their launch behavior.
  if (!kIsWeb) {
    initializers.addAll([
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      notificationService.init(),
    ]);
  }

  await Future.wait(initializers);

  // Listen before MyApp builds so auth links received during Supabase startup
  // can still route to the right screen.
  authFlowService.start();
  if (!kIsWeb) {
    unawaited(pushNotificationService.start());
    if (storageService.getElectricReminderEnabled()) {
      // Recreating an existing reminder does not need to delay the first UI.
      unawaited(notificationService.scheduleMonthlyElectricReminder());
    }
  }
}

@visibleForTesting
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({
    required this.initialize,
    this.app = const MyApp(),
    super.key,
  });

  final Future<void> Function() initialize;
  final Widget app;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<void> _initialization = widget.initialize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.app;
        }
        return const Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: Color(0xFFF4F0E8),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image(
                    image: AssetImage('assets/images/app_icon.png'),
                    width: 72,
                    height: 72,
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF715C3A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

void _catchAllError() {
  if (kDebugMode) return;
  FlutterError.onError = (details) {
    logger.e(details.exceptionAsString(), stackTrace: details.stack);
    if (kReleaseMode && !kIsWeb && Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e("__PlatformDispatcher Error!!", error: error, stackTrace: stack);
    if (kReleaseMode && !kIsWeb && Firebase.apps.isNotEmpty) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };
}
