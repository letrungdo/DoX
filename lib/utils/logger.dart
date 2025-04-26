import 'dart:developer';

import 'package:do_ai/constants/env.dart';

enum Level {
  all(0),
  trace(1000),
  debug(2000),
  info(3000),
  warning(4000),
  error(5000),
  fatal(6000),
  off(10000);

  final int value;

  const Level(this.value);
}

class Logger {
  const Logger({required this.level});
  final Level level;

  void d(String message, {Object? error, StackTrace? stackTrace}) {
    log(
      message, //
      error: error,
      stackTrace: stackTrace,
      level: level.value,
    );
  }

  void e(String message, {Object? error, StackTrace? stackTrace}) {
    log(
      "ERROR: $message", //
      error: error,
      stackTrace: stackTrace,
      level: level.value,
    );
  }
}

final logger = Logger(
  level: Envs.flavor == Flavor.prod ? Level.off : Level.all, //
);
