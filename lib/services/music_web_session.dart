import 'dart:async';

import 'package:do_x/constants/env.dart';
import 'package:do_x/services/music_auth_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Sends a write to the music API from inside a web view, as the site itself
/// would.
///
/// Liking a track is refused with `403` when it is sent by the app's HTTP
/// client — the service's bot protection lets the matching delete through but
/// not the like, and the public API does not take this token at all. What it
/// does accept is the browser the user signed in with: that web view solved
/// the protection's challenge, holds the cookie it handed out, and carries the
/// fingerprint the cookie was issued for. So the request is made there, from a
/// page on the site's own origin, and only its status comes back.
///
/// The page is a lazily loaded, offscreen one, kept for as long as the app
/// runs: the first like pays for it and the rest are a `fetch` away.
class MusicWebSession {
  static const _origin = 'https://${Envs.musicApiDomain}';

  /// Smallest document on the origin. Nothing on it is used — it is there to
  /// give the `fetch` a page of the site to run from.
  static const _pageUrl = '$_origin/robots.txt';

  HeadlessInAppWebView? _page;
  Future<InAppWebViewController?>? _pending;

  /// The status the service answered with, or `null` when no web view can be
  /// had — the web build has none, and the caller falls back to plain HTTP.
  Future<int?> send({required String method, required String url}) async {
    if (kIsWeb) return null;
    final controller = await _controller();
    if (controller == null) return null;

    try {
      final result = await controller.callAsyncJavaScript(
        functionBody: '''
          const response = await fetch(url, {
            method: method,
            credentials: 'include',
            headers: { 'Authorization': authorization },
          });
          return response.status;
        ''',
        arguments: {
          'url': url,
          'method': method,
          'authorization': musicAuth.account?.authorizationHeader ?? '',
        },
      );
      if (result?.error != null) {
        logger.e('MusicWebSession $method failed: ${result?.error}');
        return null;
      }
      final status = result?.value;
      return status is num ? status.toInt() : null;
    } on Object catch (e, st) {
      logger.e('MusicWebSession $method threw', error: e, stackTrace: st);
      return null;
    }
  }

  /// Drops the page, so the next request loads one with the cookies of
  /// whoever is signed in now.
  Future<void> reset() async {
    final page = _page;
    _page = null;
    _pending = null;
    await page?.dispose();
  }

  Future<InAppWebViewController?> _controller() {
    return _pending ??= _open();
  }

  Future<InAppWebViewController?> _open() async {
    final loaded = Completer<InAppWebViewController?>();
    final page = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_pageUrl)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        thirdPartyCookiesEnabled: true,
      ),
      onLoadStop: (controller, _) {
        if (!loaded.isCompleted) loaded.complete(controller);
      },
      // A page that will not load is a request that cannot be made; the caller
      // is told so rather than left waiting on it.
      onReceivedError: (_, _, _) {
        if (!loaded.isCompleted) loaded.complete(null);
      },
    );
    _page = page;

    try {
      await page.run();
      return await loaded.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );
    } on Object catch (e, st) {
      logger.e('MusicWebSession could not open', error: e, stackTrace: st);
      return null;
    }
  }
}

final musicWebSession = MusicWebSession();
