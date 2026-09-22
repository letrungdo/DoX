import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:do_x/constants/env.dart';
import 'package:do_x/model/music_account.dart';
import 'package:do_x/services/secure_storage_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// One sign-in attempt: the page to open, and the PKCE secret the code that
/// comes back has to be redeemed with.
class MusicSignInRequest {
  const MusicSignInRequest({required this.url, required this.verifier});

  final String url;
  final String verifier;
}

/// Why a sign-in produced no usable account. Each one leaves the user with
/// something different to do, so the screen turns each into its own message.
enum MusicAuthError {
  /// The token the sign-in page handed us is not accepted by the API.
  rejected,

  /// The request never reached the music service.
  network,
  unknown,
}

class MusicAuthException implements Exception {
  const MusicAuthException(this.kind, [this.detail]);

  final MusicAuthError kind;
  final String? detail;

  @override
  String toString() => 'MusicAuthException($kind, $detail)';
}

/// Holds the token the Music page calls the personal endpoints
/// with — likes, and the listening history.
///
/// The token is taken from a real sign-in page rather than from the
/// credentials directly. The service's own sign-in API answers a plain HTTP
/// client with a captcha challenge (`403`, `geo.captcha-delivery.com`) before
/// it ever looks at the password, so a native email/password form cannot
/// produce a token however carefully it copies the web client's request. What
/// does work is the page itself: the user signs in there, the service leaves
/// the token in its `oauth_token` cookie, and [signInWithToken] takes it from
/// there.
class MusicAuthService extends ChangeNotifier {
  static const clientId = 'Pb72ranhoyt6gw7hM7TkzUItXlMWSNSo';

  static const _domain = Envs.musicApiDomain;
  static const _apiBase = 'https://api-v2.$_domain';

  static const _authPage = 'https://secure.$_domain/web-auth';
  static const _tokenUrl = 'https://secure.$_domain/oauth/token';

  /// Where the sign-in page sends the browser once it is done. Nothing is
  /// served from it as far as we are concerned — it is the carrier of the
  /// authorization code.
  static const redirectUri = 'https://$_domain/signin/callback';

  /// The cookie's domain, and where a completed sign-in ends up.
  static const siteUrl = 'https://$_domain';

  /// The cookie the service keeps the signed-in token in.
  static const tokenCookieName = 'oauth_token';

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );

  MusicAccount? _account;
  MusicAccount? get account => _account;

  bool get isSignedIn => _account?.isValid ?? false;

  /// The sign-in page, addressed as its own page rather than as the frame
  /// the site embeds it in: a cross-origin frame inside a web view loses
  /// its storage the moment the email step hands over to the password step,
  /// and the user is left looking at a blank panel.
  MusicSignInRequest buildSignInRequest({bool darkTheme = false}) {
    final verifier = _randomUrlSafe(64);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final state = base64Url
        .encode(
          utf8.encode(
            jsonEncode({'client_id': clientId, 'nonce': _randomUrlSafe(36)}),
          ),
        )
        .replaceAll('=', '');

    final url = Uri.parse(_authPage).replace(
      queryParameters: {
        'client_id': clientId,
        'device_id': _randomDeviceId(),
        'theme': darkTheme ? 'dark' : 'light',
        'ui_evo': 'true',
        'tracking': 'local',
        'redirect_uri': redirectUri,
        'state': state,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      },
    );
    return MusicSignInRequest(url: url.toString(), verifier: verifier);
  }

  /// Redeems the code the sign-in page came back with. Preferred over reading
  /// the cookie: it is ours as soon as the redirect happens, without waiting
  /// on the site to load and do the same exchange itself.
  Future<MusicAccount> signInWithCode({
    required String code,
    required String verifier,
  }) async {
    final String token;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _tokenUrl,
        queryParameters: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
        },
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'code_verifier': verifier,
          'redirect_uri': redirectUri,
          'client_id': clientId,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      token = response.data?['access_token']?.toString() ?? '';
    } on DioException catch (e) {
      throw _mapError(e);
    }

    if (token.isEmpty) {
      throw const MusicAuthException(
        MusicAuthError.rejected,
        'token exchange returned no access_token',
      );
    }
    return signInWithToken(token);
  }

  /// Reads the stored account once at startup. Safe to call again; it only
  /// notifies when something actually changed.
  Future<void> restore() async {
    if (_account != null) return;
    final stored = await secureStorage.getMusicAccount();
    if (stored == null) return;
    _account = stored;
    notifyListeners();
  }

  /// Takes the token the sign-in page left behind and makes it this device's
  /// account. The `/me` call is not a formality: every personal endpoint is
  /// addressed by the user id, so a token we cannot name an owner for is of no
  /// use and must not be stored.
  Future<MusicAccount> signInWithToken(String oauthToken) async {
    final account = await _fetchAccount(oauthToken);
    _account = account;
    await secureStorage.saveMusicAccount(account);
    notifyListeners();
    return account;
  }

  Future<void> signOut() async {
    _account = null;
    await secureStorage.clearMusicAccount();
    notifyListeners();
  }

  Future<MusicAccount> _fetchAccount(String accessToken) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_apiBase/me',
        queryParameters: {'client_id': clientId},
        options: Options(headers: {'Authorization': 'OAuth $accessToken'}),
      );

      final id = response.data?['id']?.toString() ?? '';
      if (id.isEmpty) {
        throw const MusicAuthException(
          MusicAuthError.rejected,
          '/me returned no id',
        );
      }
      return MusicAccount(
        accessToken: accessToken,
        userId: id,
        username:
            response.data?['username']?.toString() ??
            response.data?['full_name']?.toString() ??
            '',
        avatarUrl: response.data?['avatar_url']?.toString() ?? '',
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  String _randomUrlSafe(int bytes) {
    final random = Random.secure();
    return base64Url
        .encode(List.generate(bytes, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  /// Four dash-separated six-digit groups, the shape the sign-in page uses.
  String _randomDeviceId() {
    final random = Random.secure();
    return List.generate(
      4,
      (_) => random.nextInt(1000000).toString().padLeft(6, '0'),
    ).join('-');
  }

  MusicAuthException _mapError(DioException e) {
    final status = e.response?.statusCode;
    logger.e(
      'MusicAuthService request failed',
      error: e,
      stackTrace: e.stackTrace,
    );
    if (status == null) {
      return MusicAuthException(MusicAuthError.network, e.message);
    }
    if (status == 401 || status == 403) {
      return MusicAuthException(MusicAuthError.rejected, 'HTTP $status');
    }
    return MusicAuthException(MusicAuthError.unknown, 'HTTP $status');
  }
}

final musicAuth = MusicAuthService();
