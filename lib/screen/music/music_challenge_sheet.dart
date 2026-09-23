import 'dart:convert';

import 'package:do_x/constants/dimens.dart';
import 'package:do_x/constants/env.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/utils/logger.dart';
import 'package:do_x/widgets/dialog/app_modal.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Puts the music service's bot check in front of the user, and answers
/// whether they got through it.
///
/// A like is a write the service's bot protection watches, and every so often
/// it wants the device checked before it lets one through. The check is the
/// protection's own page; the user passes it here, the way they would on the
/// site, and the like is sent again afterwards.
Future<bool> showMusicChallengeSheet(BuildContext context, String url) async {
  final passed = await showAppBottomSheet<bool>(
    context,
    title: context.l10n.musicChallengeTitle,
    scrollable: false,
    builder: (_) => _MusicChallengeView(url: url),
  );
  return passed ?? false;
}

class _MusicChallengeView extends StatefulWidget {
  const _MusicChallengeView({required this.url});

  final String url;

  @override
  State<_MusicChallengeView> createState() => _MusicChallengeViewState();
}

class _MusicChallengeViewState extends State<_MusicChallengeView> {
  static const _siteUrl = 'https://${Envs.musicApiDomain}/';

  bool _isLoading = true;
  bool _passed = false;

  /// The check is framed by a page on the site's own origin, which is where
  /// the site shows it too: the check reports its result to the page that
  /// framed it, and that result is the session cookie the site keeps for it.
  String get _hostPage {
    final src = const HtmlEscape(HtmlEscapeMode.attribute).convert(widget.url);
    return '''
<!doctype html>
<html><head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html, body, iframe { margin: 0; width: 100%; height: 100%; border: 0; }</style>
</head><body>
<iframe src="$src"></iframe>
<script>
window.addEventListener('message', function (event) {
  var host = '';
  try { host = new URL(event.origin).hostname; } catch (_) {}
  if (!/(^|\\.)captcha-delivery\\.com\$/.test(host)) return;
  var data = event.data;
  if (typeof data === 'string') {
    try { data = JSON.parse(data); } catch (_) {}
  }
  console.log('challenge message ' + JSON.stringify(data).slice(0, 300));
  var cookie = data && data.cookie;
  if (typeof cookie === 'string' && cookie.indexOf('datadome=') === 0) {
    document.cookie = cookie;
    window.flutter_inappwebview.callHandler('passed', cookie);
  }
});
</script>
</body></html>
''';
  }

  Future<void> _onPassed(List<dynamic> args) async {
    if (_passed || !mounted) return;
    _passed = true;
    final cookie = args.isEmpty ? '' : args.first.toString();
    // Stored natively as well: the page's own write is enough for the web
    // view that sends the like, but only if the two share a cookie store,
    // which is the platform's call and not ours.
    final value = cookie.split(';').first.substring('datadome='.length);
    try {
      await CookieManager.instance().setCookie(
        url: WebUri(_siteUrl),
        name: 'datadome',
        value: value,
        domain: '.${Envs.musicApiDomain}',
        path: '/',
        isSecure: true,
        sameSite: HTTPCookieSameSitePolicy.LAX,
      );
    } on Object catch (e, st) {
      logger.e('Music challenge cookie not stored', error: e, stackTrace: st);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.musicChallengeHint,
          textAlign: TextAlign.center,
          style: context.textTheme.secondary.size13,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: Dimens.musicChallengeHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.radiusCard),
            child: Stack(
              children: [
                InAppWebView(
                  initialData: InAppWebViewInitialData(
                    data: _hostPage,
                    baseUrl: WebUri(_siteUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    transparentBackground: true,
                  ),
                  onWebViewCreated: (controller) =>
                      controller.addJavaScriptHandler(
                        handlerName: 'passed',
                        callback: _onPassed,
                      ),
                  onConsoleMessage: (_, message) =>
                      logger.d('Music challenge page: ${message.message}'),
                  onLoadStop: (_, _) {
                    if (mounted) setState(() => _isLoading = false);
                  },
                ),
                if (_isLoading) const Center(child: Loading()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
