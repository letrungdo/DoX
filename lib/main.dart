import 'dart:async';
import 'dart:io';

import 'package:do_ai/app.dart';
import 'package:do_ai/constants/env.dart';
import 'package:do_ai/firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'utils/logger.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      if (kReleaseMode) {
        debugPrint = (String? message, {int? wrapWidth}) {
          if (Envs.isDev) {
            // ignore: avoid_print
            print('kcmsr_log: $message');
          }
        };
      }
      logger.d("init log");
      _catchAllError();

      await Firebase.initializeApp(
        name:
            kIsWeb
                ? null
                : Platform.isAndroid
                ? DefaultFirebaseOptions.currentPlatform.appId
                : null,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity, //
        appleProvider: AppleProvider.deviceCheck,
      );

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
