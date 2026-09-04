import 'package:flutter/foundation.dart';

/// Lets the movie overlay host ask the embedded detail screen to leave full
/// screen without coupling route arguments to the deferred screen library.
class MovieDetailController {
  VoidCallback? _exitFullScreen;

  void exitFullScreen() => _exitFullScreen?.call();

  void attach(VoidCallback callback) => _exitFullScreen = callback;

  void detach(VoidCallback callback) {
    if (_exitFullScreen == callback) _exitFullScreen = null;
  }
}
