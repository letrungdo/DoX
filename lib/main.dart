import 'dart:async';

import 'package:do_x/app.dart';
import 'package:do_x/firebase_options.dart';
import 'package:do_x/services/auth_flow_service.dart';
import 'package:do_x/services/notification_service.dart';
import 'package:do_x/services/push_notification_service.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/theme/app_theme.dart';
import 'package:do_x/utils/app_info.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/logger.dart';

void main() {
  runZonedGuarded(
    () async {
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
      //
      // The one thing waited on first is the stored theme: the loading screen
      // is the first thing anyone sees, and painting it light in front of
      // someone who chose dark is a white flash on every launch. Reading one
      // key out of the preferences file is the shortest wait there is, and a
      // launch that cannot read it opens the way the device is set.
      runApp(
        AppBootstrap(
          initialize: _initializeApp,
          themeMode: await _storedThemeMode(),
        ),
      );
    },
    (error, stack) {
      logger.e("___App error!!", error: error, stackTrace: stack);
    },
  );
}

/// The theme the app was last set to, or the default dark one when that
/// cannot be read.
Future<ThemeMode> _storedThemeMode() async {
  try {
    await storageService.init();
    return storageService.getThemeMode();
  } on Object catch (e, st) {
    logger.e('Could not read the stored theme', error: e, stackTrace: st);
    return ThemeMode.dark;
  }
}

Future<void> _initializeApp() async {
  final initializers = <Future<void>>[
    storageService.init(),
    appInfo.init(),
    // Resolved before the first frame: whether this is a television decides
    // how focus is drawn, and a widget cannot await that while building.
    deviceType.init(),
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

  if (deviceType.isTv) {
    // Flutter only paints focus highlights once it has decided the user is on
    // a keyboard, which it infers from the last input it saw. A remote's D-pad
    // does not flip that switch on its own, so without this the selected
    // control on a TV is drawn exactly like every other one and the user has
    // no idea what the OK button will press.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  }

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
    this.themeMode = ThemeMode.dark,
    super.key,
  });

  final Future<void> Function() initialize;
  final Widget app;

  /// The theme the app will open in, so the loading screen is already in it.
  final ThemeMode themeMode;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<void> _initialization = widget.initialize();

  /// Whether the loading screen is a dark one.
  ///
  /// The platform's own brightness rather than a `MediaQuery`: this is the
  /// first widget of the app and there is no `MaterialApp` above it to have
  /// put one in place.
  bool get _isDark => switch (widget.themeMode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark,
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return widget.app;
        }
        // Straight off the theme the app is about to build with, rather
        // than a colour of its own: anything else is a flash of the wrong
        // shade at the moment the real app takes over.
        final theme = _isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
        return Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: theme.scaffoldBackgroundColor,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Image(
                    image: AssetImage('assets/images/app_icon.png'),
                    width: 72,
                    height: 72,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: theme.colorScheme.primary,
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
