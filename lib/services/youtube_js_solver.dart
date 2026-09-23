// The solver builds on the package's EJS classes, which it does not export;
// the package is pinned in pubspec.yaml for that reason.
// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:io';

import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:youtube_explode_dart/src/reverse_engineering/challenges/ejs/base_ejs_solver.dart';
import 'package:youtube_explode_dart/src/reverse_engineering/challenges/ejs/ejs.dart';

/// Solves YouTube's stream challenges in an offscreen web view.
///
/// The streams worth playing — the adaptive ones, up to 1080p — come with two
/// puzzles written in the player's JavaScript: a signature to decipher and an
/// `n` parameter to transform, without which the link is refused. yt-dlp's
/// EJS scripts solve both, but they need a JavaScript engine, and the one
/// `youtube_explode_dart` ships with runs Deno as a separate process, which a
/// phone or a television does not have. A web view is an engine the app
/// already carries, so the scripts run there.
///
/// Loaded on first use and kept for as long as the app runs: the scripts and
/// the preprocessed player are the slow part, and they are the same for every
/// video until YouTube ships a new player.
class WebViewJsSolver extends BaseEJSSolver {
  /// Where a headless web view can be had.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  HeadlessInAppWebView? _page;
  Future<InAppWebViewController>? _ready;

  @override
  Future<String> executeJavaScript(String jsCode) async {
    final controller = await (_ready ??= _open().catchError((Object e) {
      // Tried afresh on the next video rather than failing every one after.
      _ready = null;
      throw e;
    }));
    final result = await controller.evaluateJavascript(source: jsCode);
    if (result is! String) {
      throw StateError('Solver answered ${result.runtimeType}, not JSON');
    }
    return result;
  }

  Future<InAppWebViewController> _open() async {
    final modules = await EJSBuilder.getJSModules();
    final loaded = Completer<InAppWebViewController>();
    final page = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(
        data: '<!doctype html><html></html>',
      ),
      // One point square rather than the default: on iOS a headless web view
      // is a real one, the size of the screen unless told otherwise, sitting
      // in the app's window.
      initialSize: const Size(1, 1),
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      onConsoleMessage: (_, message) =>
          logger.d('WebViewJsSolver page: ${message.message}'),
      onLoadStop: (controller, _) {
        if (!loaded.isCompleted) loaded.complete(controller);
      },
    );
    await _page?.dispose();
    _page = page;
    await page.run();
    final controller = await loaded.future.timeout(const Duration(seconds: 20));
    // Defines `jsc`, the solver every later call goes through.
    await controller.evaluateJavascript(source: '$modules\ntrue;');
    return controller;
  }

  @override
  void dispose() {
    _ready = null;
    unawaited(_page?.dispose());
    _page = null;
  }
}
