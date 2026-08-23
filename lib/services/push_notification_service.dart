import 'dart:async';

import 'package:do_x/services/notification_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers this device for the pushes the server sends: a storm warning,
/// which goes to everyone, and shared-chicken activity, which goes to the
/// accounts a dataset is shared with.
///
/// Every signed-in device registers, because a storm alert concerns any reader
/// whatever else they use the app for. Registration needs a session — a token
/// row belongs to an account — so [start] both registers now and follows the
/// session from there.
///
/// The token is a property of the device install, not of the account: signing
/// out removes it so the next person on this phone does not get pushes about
/// data they cannot see.
class PushNotificationService {
  String? _token;
  bool _listening = false;
  bool _listeningForTaps = false;
  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Everything this service does at launch: catch the tap that may have
  /// started the app, register this device if somebody is signed in, and keep
  /// the registration in step with the session from then on.
  Future<void> start() async {
    if (!isSupported) return;
    await listenForTaps();

    _authSubscription ??= supabase.auth.onAuthStateChange.listen((state) {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.userUpdated:
          unawaited(syncRegistration());
        case AuthChangeEvent.signedOut:
          // The token is dropped before the sign-out, while the session is
          // still there; this only clears what we remember of it.
          _token = null;
        default:
          break;
      }
    });

    // A session restored from disk is already there by the time we get here, so
    // it produces no event to react to.
    if (supabase.auth.currentSession != null) await syncRegistration();
  }

  /// Starts listening for taps on a push the system drew itself, in the
  /// background or with the app closed. Independent of registration: a
  /// notification can be tapped long before the app knows what is shared with
  /// this account, and the launch message would otherwise be missed.
  Future<void> listenForTaps() async {
    if (!isSupported || _listeningForTaps) return;
    _listeningForTaps = true;

    // iOS hides a push that arrives while the app is open unless it is asked
    // not to. Firebase Messaging is the notification centre's delegate, so it
    // decides this for local notifications too — without it, nothing at all
    // showed up in the foreground.
    if (_isIOS) {
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );
      } catch (e) {
        logger.e('set foreground push presentation failed', error: e);
      }
    }

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      handleTappedPush,
    );
    try {
      final launchMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (launchMessage != null) handleTappedPush(launchMessage);
    } catch (e) {
      logger.e('read the launch push failed', error: e);
    }
  }

  /// A tapped push, wherever it was tapped. Anything the server did not label
  /// with a screen to open just brings the app to the front.
  @visibleForTesting
  void handleTappedPush(RemoteMessage message) {
    switch (message.data['type']) {
      case 'storm_news':
        notificationService.openStormAlert();
      case 'chicken_activity':
        final ownerId = message.data['owner_id'] as String?;
        if (ownerId == null) return;
        notificationService.openSharedActivity(ownerId);
      default:
        break;
    }
  }

  /// Registers this device against the signed-in account, asking for the
  /// notification permission the first time. Does nothing without a session:
  /// there would be no account to hang the token on.
  Future<void> syncRegistration() async {
    if (!isSupported) return;
    if (supabase.auth.currentSession == null) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      // On iOS the FCM token is derived from the APNs one, which arrives from
      // Apple a moment after launch — asking for it too early throws. It never
      // arrives at all on a simulator, where the next sign-in or refresh is a
      // good enough time to try again.
      if (_isIOS && !await _waitForApnsToken()) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _register(token);
      _listen();
    } catch (e) {
      // A device with no Play Services, or an APNs registration that timed out:
      // the app works without push, so this stays a log line.
      logger.e('register for push failed', error: e);
    }
  }

  Future<bool> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null) return true;
      await Future.delayed(const Duration(seconds: 1));
    }
    logger.d('no APNs token yet, skipping push registration');
    return false;
  }

  /// Drops this device's token. Call it *before* signing out, while the session
  /// that authorises the call is still there.
  Future<void> unregister() async {
    final token = _token;
    _token = null;
    if (token == null) return;
    try {
      await supabase.rpc('unregister_device_token', params: {'p_token': token});
    } catch (e) {
      logger.e('unregister push failed', error: e);
    }
  }

  Future<void> _register(String token) async {
    await supabase.rpc(
      'register_device_token',
      params: {
        'p_token': token,
        'p_platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        'p_locale': _languageCode,
      },
    );
    _token = token;
  }

  void _listen() {
    if (_listening) return;
    _listening = true;

    // Firebase rotates a token on its own schedule; a stale one is a silently
    // undelivered notification.
    _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) async {
      try {
        await _register(token);
      } catch (e) {
        logger.e('refresh push token failed', error: e);
      }
    });

    // Backgrounded, the system draws the notification itself. In the foreground
    // Android hands the message to the app instead, so draw it here. iOS shows
    // it itself, now that the presentation options above allow it — drawing a
    // copy would show the same sale twice.
    _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (_isIOS) return;
      final notification = message.notification;
      final title = notification?.title;
      if (title == null) return;
      final body = notification?.body ?? '';
      if (message.data['type'] == 'storm_news') {
        notificationService.showStormAlert(title: title, body: body);
        return;
      }
      notificationService.showSharedActivity(
        title: title,
        body: body,
        ownerId: message.data['owner_id'] as String?,
      );
    });
  }

  @visibleForTesting
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _refreshSubscription?.cancel();
    _messageSubscription?.cancel();
    _openedSubscription?.cancel();
    _listening = false;
    _listeningForTaps = false;
  }

  String get _languageCode =>
      storageService.getLocale() ??
      PlatformDispatcher.instance.locale.languageCode;
}

final pushNotificationService = PushNotificationService();
