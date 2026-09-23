import 'dart:async';

import 'package:do_x/constants/env.dart';
import 'package:do_x/services/music_auth_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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

  /// What the service answered with, or `null` when no web view can be had —
  /// the web build has none, and the caller falls back to plain HTTP.
  ///
  /// The request is sent the way the site's own client sends it to a path its
  /// bot protection watches: the protection's session goes along in the
  /// `X-Datadome-ClientId` header (the site runs it header-based, not by
  /// cookie, because the API is on another origin), and a renewed one comes
  /// back in `X-Set-Cookie`, which is kept for the next request.
  Future<MusicWebResponse?> send({
    required String method,
    required String url,
  }) async {
    if (kIsWeb) return null;
    final controller = await _controller();
    if (controller == null) return null;

    try {
      final result = await controller.callAsyncJavaScript(
        functionBody: '''
          const headers = { 'Authorization': authorization };
          const session = document.cookie.split('; ')
              .find((c) => c.startsWith('datadome='));
          if (session) {
            headers['X-Datadome-ClientId'] = session.slice('datadome='.length);
          }
          const response = await fetch(url, {
            method: method,
            credentials: 'include',
            headers: headers,
          });
          const renewed = response.headers.get('x-set-cookie');
          if (renewed && renewed.startsWith('datadome=')) {
            document.cookie = renewed;
          }
          let challenge = null;
          if (response.status === 403) {
            // The bot protection's refusal carries the page to pass its check
            // on; the API's own 403 does not.
            try {
              const body = await response.json();
              if (body && typeof body.url === 'string'
                  && body.url.indexOf('captcha-delivery.com') !== -1) {
                challenge = body.url;
              }
            } catch (_) {}
          }
          return { status: response.status, challenge: challenge };
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
      final value = result?.value;
      if (value is! Map) return null;
      final status = value['status'];
      if (status is! num) return null;
      final challenge = value['challenge'];
      return MusicWebResponse(
        status: status.toInt(),
        challengeUrl: challenge is String ? challenge : null,
      );
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
      // One point square rather than the default: on iOS a headless web view
      // is a real one, the size of the screen unless told otherwise, laid in
      // the app's window where it could take the touches meant for the page.
      initialSize: const Size(1, 1),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        thirdPartyCookiesEnabled: true,
      ),
      onConsoleMessage: (_, message) =>
          logger.d('MusicWebSession page: ${message.message}'),
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

/// The service's answer to a request sent from the web session.
class MusicWebResponse {
  const MusicWebResponse({required this.status, this.challengeUrl});

  final int status;

  /// The bot protection's check, when that is what refused the request. The
  /// user has to pass it before the request can go through.
  final String? challengeUrl;
}
