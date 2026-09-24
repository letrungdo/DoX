import 'package:auto_route/auto_route.dart';
import 'package:do_x/constants/dimens.dart';
import 'package:do_x/extensions/context_extensions.dart';
import 'package:do_x/extensions/text_style_extensions.dart';
import 'package:do_x/extensions/widget_extensions.dart';
import 'package:do_x/router/app_router.gr.dart';
import 'package:do_x/screen/core/screen_state.dart';
import 'package:do_x/screen/music/music_tv_pairing_view.dart';
import 'package:do_x/services/music_auth_service.dart';
import 'package:do_x/utils/device_type.dart';
import 'package:do_x/view_model/music/music_login_view_model.dart';
import 'package:do_x/widgets/app_bar/app_bar_base.dart';
import 'package:do_x/widgets/app_scaffold.dart';
import 'package:do_x/widgets/button/button.dart';
import 'package:do_x/widgets/loading.dart';
import 'package:do_x/widgets/surface/app_card.dart';
import 'package:do_x/widgets/tv_web_navigator.dart';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

/// Signs the Music page in to the music service. Liking a track and the likes
/// tab both speak for an account, and the service answers neither without
/// one.
///
/// The sign-in happens on the service's own page rather than on a form of
/// ours: their sign-in API turns a plain HTTP client away with a captcha
/// before it ever looks at the password. It is opened at its own address
/// rather than through the site, which embeds it in a cross-origin frame that
/// a web view leaves blank as soon as the email step hands over to the
/// password step. What comes back is an authorization code, redeemed here;
/// the token cookie the site sets is read only if that exchange fails.
///
/// A television does not get the page at all: the service's bot check puts a
/// challenge in front of it that cannot be passed from a remote. It shows a QR
/// code instead, for a phone that is signed in to scan — see
/// [MusicTvPairingView].
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

/// Gives the service's sign-in page the app's background.
///
/// The page paints its own, which shows up as a slab of a different colour
/// around a form that never fills the screen. Colouring the web view from the
/// Flutter side does not reach it — the page's own background is drawn on top
/// — so the colour is handed to the page itself.
String _pageStyleScript(Color background) {
  final hex = (background.toARGB32() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0');
  return '''
(function () {
  var style = document.getElementById('do-x-style')
      || document.createElement('style');
  style.id = 'do-x-style';
  style.textContent =
      'html, body.ui-evo-body, body.ui-evo-body .connect-form'
      + ' { background: #$hex !important; }';
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

  /// The sign-in page takes its time to arrive, and a web view shows nothing
  /// at all until it does. Without this the screen is an empty rectangle for
  /// several seconds and looks broken.
  bool _isPageLoading = true;

  /// The window the sign-in page opened for a social provider, if one is up.
  /// "Continue with Google" and its neighbours are `window.open` calls: left
  /// unhandled, the page they ask for lands in the web view that opened them
  /// and the sign-in form is replaced by an empty `about:blank`.
  int? _popupWindowId;

  /// The provider's window opens on a blank page and reaches its own sign-in
  /// screen a moment later, so it needs the same cover as the page below it.
  bool _isPopupLoading = true;

  /// What drives each web view from the remote — see [TvWebNavigator]. The
  /// page's own controls are not Flutter's to focus, so without this a
  /// television can see the sign-in form and reach nothing in it.
  final _pageNavigator = GlobalKey<TvWebNavigatorState>();
  final _popupNavigator = GlobalKey<TvWebNavigatorState>();
  InAppWebViewController? _pageWebView;
  InAppWebViewController? _popupWebView;

  void _setPopupLoading(bool value) {
    if (!mounted || _isPopupLoading == value) return;
    setState(() => _isPopupLoading = value);
  }

  void _setPageLoading(bool value) {
    if (!mounted || _isPageLoading == value) return;
    setState(() => _isPageLoading = value);
  }

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
            AppCard(
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
            if (_canPairTv) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.router.push(const MusicTvPairRoute()),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(l10n.musicPairTvTitle),
              ),
            ],
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

    if (deviceType.isTv) {
      return MusicTvPairingView(
        onToken: _claimPairedToken,
        errorMessage: viewModel.errorMessage,
        isSigningIn: viewModel.isBusy,
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
        // The gutter is the web view's own: now that the page carries the
        // app's background, insetting it no longer shows a band of the wrong
        // colour down each side.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Dimens.pagePadding),
            child: Stack(
              children: [
                TvWebNavigator(
                  key: const ValueKey('tv-music-login'),
                  autofocus: true,
                  controller: () => _pageWebView,
                  child: InAppWebView(
                    key: ValueKey(request.url),
                    onWebViewCreated: (controller) => _pageWebView = controller,
                    initialUrlRequest: URLRequest(url: WebUri(request.url)),
                    initialUserScripts: UnmodifiableListView([
                      UserScript(
                        source: _pageStyleScript(pageBackground),
                        injectionTime:
                            UserScriptInjectionTime.AT_DOCUMENT_START,
                      ),
                    ]),
                    initialSettings: InAppWebViewSettings(
                      // Deliberately no user agent of our own. Claiming to be a
                      // desktop browser from inside a phone's web view is exactly
                      // the mismatch the service's bot protection blocks on, and
                      // the page works fine as whatever the device really is.
                      javaScriptEnabled: true,
                      thirdPartyCookiesEnabled: true,
                      // A social provider is signed in to through a window the
                      // page opens; Android serves one only when the web view is
                      // told to expect it.
                      supportMultipleWindows: true,
                      javaScriptCanOpenWindowsAutomatically: true,
                      // Until the page has been styled — and while it loads at
                      // all — what shows through is the app's own surface, not a
                      // white rectangle.
                      transparentBackground: true,
                    ),
                    // The redirect carries the code, and is caught before it is
                    // even loaded; the load/history hooks are the fallback that
                    // reads the cookie if redeeming the code does not work out.
                    shouldOverrideUrlLoading: (_, action) async {
                      final url = action.request.url?.toString() ?? '';
                      if (await _claimCode(url)) {
                        return NavigationActionPolicy.CANCEL;
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                    onLoadStop: (controller, url) async {
                      // Android leaves the document-start script out on web view
                      // versions that do not support one, so colour the page the
                      // slow way too — running it twice changes nothing.
                      await controller.evaluateJavascript(
                        source: _pageStyleScript(pageBackground),
                      );
                      _setPageLoading(false);
                      // A new document has no element the remote was on, so the
                      // page is aimed at its first one again.
                      await _pageNavigator.currentState?.onPageLoaded();
                      if (await _claimCode(url?.toString() ?? '')) return;
                      await _claimToken();
                    },
                    onUpdateVisitedHistory: (_, url, _) async {
                      if (await _claimCode(url?.toString() ?? '')) return;
                      await _claimToken();
                    },
                    onLoadStart: (_, _) => _setPageLoading(true),
                    onCreateWindow: (_, action) async {
                      setState(() {
                        _popupWindowId = action.windowId;
                        _isPopupLoading = true;
                      });
                      return true;
                    },
                    // The provider closes its own window when it is done, which is
                    // the sign-in page's cue to carry on underneath.
                    onCloseWindow: (_) => _closePopup(),
                    // Both failures still end the wait: an error page is a page,
                    // and leaving the spinner up over it hides what went wrong.
                    onReceivedError: (_, _, _) => _setPageLoading(false),
                    onReceivedHttpError: (_, _, _) => _setPageLoading(false),
                  ),
                ),
                if (_isPageLoading)
                  Positioned.fill(
                    child: ColoredBox(
                      color: pageBackground,
                      child: const Center(child: Loading()),
                    ),
                  ),
                if (_popupWindowId != null)
                  Positioned.fill(child: _buildPopup(pageBackground)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The provider's own window, on top of the sign-in page that opened it.
  /// Closed by the provider itself, or by the user when they change their mind
  /// — without a way out, a provider that refuses to sign in inside an app's
  /// web view leaves the screen stuck on its error.
  Widget _buildPopup(Color background) {
    return ColoredBox(
      color: background,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: context.l10n.close,
              icon: const Icon(Icons.close_rounded),
              onPressed: _closePopup,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                TvWebNavigator(
                  key: const ValueKey('tv-music-login-popup'),
                  autofocus: true,
                  controller: () => _popupWebView,
                  child: InAppWebView(
                    windowId: _popupWindowId,
                    onWebViewCreated: (controller) =>
                        _popupWebView = controller,
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      thirdPartyCookiesEnabled: true,
                      transparentBackground: true,
                    ),
                    // The provider can hand the code straight back, without the
                    // page underneath ever seeing the redirect.
                    shouldOverrideUrlLoading: (_, action) async {
                      final url = action.request.url?.toString() ?? '';
                      if (await _claimCode(url)) {
                        return NavigationActionPolicy.CANCEL;
                      }
                      return NavigationActionPolicy.ALLOW;
                    },
                    onLoadStart: (_, _) => _setPopupLoading(true),
                    onLoadStop: (_, url) async {
                      final current = url?.toString() ?? '';
                      // The window is opened blank and told where to go a moment
                      // later, so that first load settling is not the provider's
                      // page arriving — uncovering it there shows nothing at all.
                      if (current.isNotEmpty && current != 'about:blank') {
                        _setPopupLoading(false);
                      }
                      await _popupNavigator.currentState?.onPageLoaded();
                      if (await _claimCode(current)) return;
                      await _claimToken();
                    },
                    onReceivedError: (_, _, _) => _setPopupLoading(false),
                    onReceivedHttpError: (_, _, _) => _setPopupLoading(false),
                    onCloseWindow: (_) => _closePopup(),
                  ),
                ),
                if (_isPopupLoading)
                  Positioned.fill(
                    child: ColoredBox(
                      color: background,
                      child: const Center(child: Loading()),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _closePopup() {
    if (!mounted || _popupWindowId == null) return;
    _popupWebView = null;
    setState(() => _popupWindowId = null);
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

  /// A phone with a camera, signed in here, can sign a television in.
  bool get _canPairTv =>
      !kIsWeb &&
      !deviceType.isTv &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// The token a phone handed this television over the QR code. Answers with
  /// the account's name for the phone to show, or `null` when it was no good.
  Future<String?> _claimPairedToken(String token) async {
    if (_claimingToken || !mounted) return null;
    _claimingToken = true;
    final signedIn = await vm.signInWithToken(token);
    final name = musicAuth.account?.username ?? '';
    if (!mounted) return signedIn ? name : null;
    if (!signedIn) {
      _claimingToken = false;
      return null;
    }
    // After the phone has had its answer: leaving takes the listener down.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.router.maybePop(true);
    });
    return name;
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
    _popupWindowId = null;
    _pageWebView = null;
    _popupWebView = null;
    if (kIsWeb) return;
    await CookieManager.instance().deleteCookies(
      url: WebUri(MusicAuthService.siteUrl),
    );
  }
}
