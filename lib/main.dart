import 'dart:async';

import 'package:do_x/app.dart';
import 'package:do_x/firebase_options.dart';
import 'package:do_x/services/notification_service.dart';
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
      await Future.wait([
        storageService.init(),
        appInfo.init(),
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
        secureStorage.getAccount(),
        initSupabase(),
        notificationService.init(),
      ]);
      if (storageService.getElectricReminderEnabled()) {
        await notificationService.scheduleMonthlyElectricReminder();
      }

      runApp(const MyApp());
    },
    (error, stack) {
      logger.e("___App error!!", error: error, stackTrace: stack);
    },
  );
}

void _catchAllError() {
  if (kDebugMode) return;
  FlutterError.onError = (details) {
    logger.e(details.exceptionAsString(), stackTrace: details.stack);
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e("__PlatformDispatcher Error!!", error: error, stackTrace: stack);
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };
}
