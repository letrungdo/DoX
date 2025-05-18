import 'dart:async';

import 'package:camera/camera.dart';
import 'package:do_x/app.dart';
import 'package:do_x/constants/env.dart';
import 'package:do_x/firebase_options.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/utils/app_info.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utils/logger.dart';

late List<CameraDescription> cameras;

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
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown, //
      ]);
      await Future.wait([
        storageService.init(),
        appInfo.init(),
        Firebase.initializeApp(
          // name: DefaultFirebaseOptions.currentPlatform.projectId,
          options: kIsWeb ? DefaultFirebaseOptions.currentPlatform : null,
        ),
        secureStorage.getAccount(),
        _initCamera(),
      ]);

      runApp(const MyApp());
    },
    (error, stack) {
      logger.e("___App error!!", error: error, stackTrace: stack);
    },
  );
}

Future<void> _initCamera() async {
  try {
    cameras = await availableCameras();
  } catch (e) {
    logger.e(e.toString(), error: e);
  }
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
