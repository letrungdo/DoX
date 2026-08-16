import 'dart:async';

import 'package:do_x/services/notification_service.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:do_x/services/supabase_service.dart';
import 'package:do_x/utils/logger.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers this device for the pushes the server sends when an owner who
/// shared their chicken data records a sale or an expense.
///
/// Registration is deliberately lazy. A device is registered — and the system
/// permission prompt shown — only once the signed-in account actually has
/// somebody else's data shared with it, so an account that never receives a
/// share is never asked for a permission it has no use for.
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

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

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
      _openChickenActivity,
    );
    try {
      final launchMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (launchMessage != null) _openChickenActivity(launchMessage);
    } catch (e) {
      logger.e('read the launch push failed', error: e);
    }
  }

  void _openChickenActivity(RemoteMessage message) {
    if (message.data['type'] != 'chicken_activity') return;
    final ownerId = message.data['owner_id'] as String?;
    if (ownerId == null) return;
    notificationService.openSharedActivity(ownerId);
  }

  /// Called whenever the set of data sources is known. [hasSharedData] is false
  /// for an account that only sees its own records, which has nothing to be
  /// notified about.
  Future<void> syncRegistration({required bool hasSharedData}) async {
    if (!isSupported) return;
    if (!hasSharedData) {
      await unregister();
      return;
    }

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
      logger.e('register for chicken push failed', error: e);
    }
  }

  Future<bool> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken != null) return true;
      await Future.delayed(const Duration(seconds: 1));
    }
    logger.d('no APNs token yet, skipping chicken push registration');
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
      logger.e('unregister chicken push failed', error: e);
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
        logger.e('refresh chicken push token failed', error: e);
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
      notificationService.showSharedActivity(
        title: title,
        body: notification?.body ?? '',
        ownerId: message.data['owner_id'] as String?,
      );
    });
  }

  @visibleForTesting
  void dispose() {
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
