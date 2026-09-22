import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/services/music_auth_service.dart';
import 'package:do_x/view_model/tv/music_login_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/neu/neu_card.dart';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

/// Signs the Music page in to the music service. Liking a track, the likes
/// tab and the history tab all speak for an account, and the service answers
/// none of them without one.
///
/// The sign-in happens on the service's own page rather than on a form of
/// ours: their sign-in API turns a plain HTTP client away with a captcha
/// before it ever looks at the password. It is opened at its own address
/// rather than through the site, which embeds it in a cross-origin frame that
/// a web view leaves blank as soon as the email step hands over to the
/// password step. What comes back is an authorization code, redeemed here;
/// the token cookie the site sets is read only if that exchange fails.
@RoutePage()
class MusicLoginScreen extends StatefulScreen implements AutoRouteWrapper {
  const MusicLoginScreen({super.key});

  @override
  State<MusicLoginScreen> createState() => _MusicLoginScreenState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MusicLoginViewModel(),
      child: this,
    );
  }
}

/// Makes the service's sign-in page sit in the app rather than in a panel of
/// its own.
///
/// Two things are wrong with it as served. It runs its form edge to edge below
/// its desktop breakpoint, so on a phone the fields touch both sides of the
/// screen; and it paints its own background, which shows up as a slab of a
/// different colour wherever the page does not cover the screen. Neither is
/// fixable from the Flutter side — padding the web view only insets the page's
/// own background and leaves that band behind — so the page is handed the
/// app's gutter and the app's background instead.
String _pageStyleScript(Color background) {
  final hex = (background.toARGB32() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0');
  final gutter = Dimens.pagePadding.toInt();
  return '''
(function () {
  var style = document.getElementById('do-x-style')
      || document.createElement('style');
  style.id = 'do-x-style';
  style.textContent =
      'html, body.ui-evo-body, body.ui-evo-body .connect-form'
      + ' { background: #$hex !important; }'
      + 'body.ui-evo-body main { padding-left: ${gutter}px;'
      + ' padding-right: ${gutter}px; box-sizing: border-box; }';
  document.documentElement.appendChild(style);
})();
''';
}

class _MusicLoginScreenState
    extends ScreenState<MusicLoginScreen, MusicLoginViewModel> {
  /// Set once a token has been picked up, so the cookie checks that keep
  /// arriving while the page finishes loading do not start a second sign-in.
  bool _claimingToken = false;

  /// The signed-in account is shown instead of the page it was obtained from;
  /// this is how the user asks for the page back to sign in as somebody else.
  bool _showSignInPage = false;

  /// Built once per attempt: the code the page hands back can only be redeemed
  /// with the secret the page was opened with.
  MusicSignInRequest? _signInRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewModel = context.watch<MusicLoginViewModel>();
    final showAccount = viewModel.isSignedIn && !_showSignInPage;

    return AppScaffold(
      appBar: DoAppBar(title: l10n.musicLoginTitle),
      body: showAccount
          ? _buildAccount(viewModel)
          : _buildSignInPage(viewModel),
    );
  }

  Widget _buildAccount(MusicLoginViewModel viewModel) {
    final l10n = context.l10n;
    final name = viewModel.accountName;
    return SingleChildScrollView(
      child: Padding(
        padding: Dimens.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.cloud_done_rounded,
              size: 56,
              color: context.theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            NeuCard(
              radius: Dimens.radiusCard,
              depth: 0.5,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.account_circle_rounded,
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name.isEmpty
                          ? l10n.musicLoginTitle
                          : l10n.musicSignedInAs(name),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DoButton(onPressed: _signOut, text: l10n.logout),
            TextButton(
              onPressed: _startOver,
              child: Text(l10n.musicSwitchAccount),
            ),
          ],
        ),
      ).contentConstrainedBox(),
    );
  }

  Widget _buildSignInPage(MusicLoginViewModel viewModel) {
    // The web build has no in-app browser to sign in with, and cannot read
    // the site's cookies from its own page either.
    if (kIsWeb) {
      return Padding(
        padding: Dimens.screenPadding,
        child: Center(
          child: Text(
            context.l10n.musicLoginWebUnsupported,
            textAlign: TextAlign.center,
            style: context.textTheme.secondary.size13,
          ),
        ),
      );
    }

    final request = _signInRequest ??= musicAuth.buildSignInRequest(
      darkTheme: context.theme.brightness == Brightness.dark,
    );
    final errorMessage = viewModel.errorMessage;
    final pageBackground = context.theme.scaffoldBackgroundColor;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Dimens.pagePadding,
            8,
            Dimens.pagePadding,
            12,
          ),
          child: Text(
            context.l10n.musicLoginSubtitle,
            textAlign: TextAlign.center,
            style: context.textTheme.secondary.size13,
          ),
        ),
        if (errorMessage != null)
          Container(
            width: double.infinity,
            color: context.theme.colorScheme.errorContainer,
            padding: const EdgeInsets.symmetric(
              horizontal: Dimens.pagePadding,
              vertical: 10,
            ),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        Expanded(
          child: InAppWebView(
            key: ValueKey(request.url),
            initialUrlRequest: URLRequest(url: WebUri(request.url)),
            initialUserScripts: UnmodifiableListView([
              UserScript(
                source: _pageStyleScript(pageBackground),
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
            ]),
            initialSettings: InAppWebViewSettings(
              // Deliberately no user agent of our own. Claiming to be a
              // desktop browser from inside a phone's web view is exactly the
              // mismatch the service's bot protection blocks on, and the page
              // works fine as whatever the device really is.
              javaScriptEnabled: true,
              thirdPartyCookiesEnabled: true,
              // Until the page has been styled — and while it loads at all —
              // what shows through is the app's own surface, not a white
              // rectangle.
              transparentBackground: true,
            ),
            // The redirect carries the code, and is caught before it is even
            // loaded; the load/history hooks are the fallback that reads the
            // cookie if redeeming the code does not work out.
            shouldOverrideUrlLoading: (_, action) async {
              final url = action.request.url?.toString() ?? '';
              if (await _claimCode(url)) {
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
            onLoadStop: (controller, url) async {
              // Android leaves the document-start script out on web view
              // versions that do not support one, so put the gutter back the
              // slow way too — running it twice changes nothing.
              await controller.evaluateJavascript(
                source: _pageStyleScript(pageBackground),
              );
              if (await _claimCode(url?.toString() ?? '')) return;
              await _claimToken();
            },
            onUpdateVisitedHistory: (_, url, _) async {
              if (await _claimCode(url?.toString() ?? '')) return;
              await _claimToken();
            },
          ),
        ),
      ],
    );
  }

  /// True once [url] has been recognised as the redirect the sign-in ends on
  /// and its code has been redeemed, so the web view can stop there.
  Future<bool> _claimCode(String url) async {
    if (_claimingToken || !mounted || url.isEmpty) return false;
    if (!url.startsWith(MusicAuthService.redirectUri)) return false;
    final code = Uri.tryParse(url)?.queryParameters['code'] ?? '';
    final verifier = _signInRequest?.verifier;
    if (code.isEmpty || verifier == null) return false;

    _claimingToken = true;
    final signedIn = await vm.signInWithCode(code: code, verifier: verifier);
    if (!mounted) return signedIn;
    if (signedIn) {
      context.router.maybePop(true);
      return true;
    }
    // Let the redirect run after all: the site performs the same
    // exchange itself, and [_claimToken] can pick the token up from there.
    _claimingToken = false;
    return false;
  }

  Future<void> _claimToken() async {
    if (_claimingToken || !mounted) return;
    final cookie = await CookieManager.instance().getCookie(
      url: WebUri(MusicAuthService.siteUrl),
      name: MusicAuthService.tokenCookieName,
    );
    final raw = cookie?.value?.toString() ?? '';
    if (raw.isEmpty || !mounted) return;

    _claimingToken = true;
    final token = raw.contains('%') ? Uri.decodeComponent(raw) : raw;
    final signedIn = await vm.signInWithToken(token);
    if (!mounted) return;
    if (signedIn) {
      context.router.maybePop(true);
    } else {
      // Leave the page where it is: the message says what happened, and the
      // next navigation is free to try again.
      _claimingToken = false;
    }
  }

  Future<void> _signOut() async {
    await vm.signOut();
    await _clearSignInPage();
    if (mounted) setState(() => _showSignInPage = false);
  }

  /// Signing in as somebody else means the page must forget who it is, or it
  /// hands back the account that is already stored.
  Future<void> _startOver() async {
    await _clearSignInPage();
    if (mounted) setState(() => _showSignInPage = true);
  }

  Future<void> _clearSignInPage() async {
    _claimingToken = false;
    _signInRequest = null;
    if (kIsWeb) return;
    await CookieManager.instance().deleteCookies(
      url: WebUri(MusicAuthService.siteUrl),
    );
  }
}
