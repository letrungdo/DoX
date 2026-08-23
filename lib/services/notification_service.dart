import 'dart:ui' show Color;

import 'package:do_x/l10n/app_localizations.dart';
import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:do_x/services/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const electricNotificationPayload = 'electric:last-month';

  /// Payload of a shared-activity notification, followed by the id of the
  /// account that recorded the sale or the expense.
  static const sharedActivityPayloadPrefix = 'chicken-activity:';

  /// Payload of a storm alert. It names no storm: the bulletin itself lives on
  /// the news page, which is all the notification has to open.
  static const stormAlertPayload = 'storm-alert';

  static const _channelId = 'chicken_vaccinations';
  static const _channelName = 'Lịch tiêm phòng';
  static const _channelDescription = 'Nhắc lịch tiêm phòng cho các lứa gà';

  static const _electricChannelId = 'electric_bill';
  static const _electricChannelName = 'Tiền điện';
  static const _electricChannelDescription =
      'Nhắc kiểm tra tiền điện đầu tháng';
  static const _electricReminderId = 0x0E1EC001;

  static const _stormChannelId = 'storm_alert';
  static const _stormChannelName = 'Cảnh báo bão';
  static const _stormChannelDescription =
      'Báo khi có bão hoặc áp thấp nhiệt đới ảnh hưởng Việt Nam';
  var _stormNotificationId = 0x570A0000;

  static const _sharedChannelId = 'shared_chicken_activity';
  static const _sharedChannelName = 'Dữ liệu gà được chia sẻ';
  static const _sharedChannelDescription =
      'Báo khi người chia sẻ dữ liệu bán gà hoặc thêm chi phí';
  var _sharedNotificationId = 0x5A1E0000;

  final _plugin = FlutterLocalNotificationsPlugin();
  final ValueNotifier<DateTime?> electricNotificationMonth = ValueNotifier(
    null,
  );

  /// Owner id carried by a tapped shared-activity notification: the app opens
  /// the chicken page on that owner's data. Cleared by whoever consumes it.
  final ValueNotifier<String?> sharedActivityOwnerId = ValueNotifier(null);

  /// Set when a storm alert is tapped: the app opens the news page, where the
  /// bulletin is. Cleared by whoever consumes it.
  final ValueNotifier<bool> stormAlertRequested = ValueNotifier(false);
  bool _initialized = false;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> init() async {
    if (_initialized || !isSupported) return;

    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // timezone.local remains available as a safe fallback.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        // Not the launcher icon: Android masks a status bar icon by its alpha
        // channel, and the launcher icon is fully opaque, so it showed up as a
        // plain white square. This one is the logo on transparency.
        android: AndroidInitializationSettings(
          '@drawable/ic_stat_notification',
        ),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
    _initialized = true;
    await _createAndroidChannels();

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        launchResponse != null) {
      _handleNotificationResponse(launchResponse);
    }
  }

  /// Declares the push channels up front, before any notification uses them.
  ///
  /// A push that arrives while the app is killed is drawn by the system, not by
  /// this plugin, so the channel it names has to exist already — otherwise
  /// Android files a storm warning under the fallback channel, at default
  /// importance, and it never gets to interrupt anybody. The channels a local
  /// reminder uses are created on first use, which is soon enough.
  Future<void> _createAndroidChannels() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _stormChannelId,
        _stormChannelName,
        description: _stormChannelDescription,
        importance: Importance.max,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _sharedChannelId,
        _sharedChannelName,
        description: _sharedChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  void _handleNotificationResponse(NotificationResponse response) {
    handlePayload(response.payload);
  }

  /// What a tapped notification asks the app to open. A vaccination reminder
  /// carries a batch id, which no screen listens for — it only opens the app.
  @visibleForTesting
  void handlePayload(String? payload) {
    if (payload == electricNotificationPayload) {
      final now = DateTime.now();
      electricNotificationMonth.value = DateTime(now.year, now.month - 1);
      return;
    }
    if (payload == stormAlertPayload) {
      openStormAlert();
      return;
    }
    if (payload != null && payload.startsWith(sharedActivityPayloadPrefix)) {
      openSharedActivity(payload.substring(sharedActivityPayloadPrefix.length));
    }
  }

  /// Asks the app to show the news page, where the storm bulletin is. Also
  /// called for a push the system drew itself, whose tap never reaches this
  /// plugin.
  void openStormAlert() {
    // Same reason as [openSharedActivity]: a ValueNotifier swallows a write of
    // the value it already holds, and a second tap has to navigate again.
    stormAlertRequested.value = false;
    stormAlertRequested.value = true;
  }

  /// Asks the app to show [ownerId]'s shared chicken data. Also called for a
  /// push the system drew itself, whose tap never reaches this plugin.
  void openSharedActivity(String ownerId) {
    if (ownerId.isEmpty) return;
    // A second tap on the same owner has to notify again, and a ValueNotifier
    // swallows a write of the value it already holds.
    sharedActivityOwnerId.value = null;
    sharedActivityOwnerId.value = ownerId;
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            true;
      case TargetPlatform.iOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      case TargetPlatform.macOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      default:
        return false;
    }
  }

  Future<void> scheduleVaccinations(List<ChickenBatch> batches) async {
    if (!isSupported) return;
    await init();
    await _plugin.cancelAllPendingNotifications();

    final now = tz.TZDateTime.now(tz.local);
    final l10n = _localizations();
    final reminders =
        [
          for (final batch in batches)
            for (final vaccination in batch.vaccinations)
              if (!vaccination.isCompleted)
                (batch: batch, vaccination: vaccination),
        ]..sort(
          (a, b) => a.vaccination.scheduledDate.compareTo(
            b.vaccination.scheduledDate,
          ),
        );

    // iOS keeps at most 64 pending notifications. Leave a little room for
    // future notification types and schedule the nearest vaccination dates.
    var scheduledCount = 0;
    for (final reminder in reminders) {
      final date = reminder.vaccination.scheduledDate;
      final scheduledDate = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        8,
      );
      if (!scheduledDate.isAfter(now)) continue;

      await _plugin.zonedSchedule(
        id: _stableId(reminder.vaccination.id),
        title: l10n.vaccinationNotificationTitle(reminder.vaccination.title),
        body: l10n.vaccinationNotificationBody(reminder.batch.name),
        scheduledDate: scheduledDate,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.batch.id,
      );
      scheduledCount++;
      if (scheduledCount >= 60) break;
    }

    // cancelAllPendingNotifications above also removed the electric reminder.
    await _restoreElectricReminderIfEnabled();
  }

  Future<void> cancelVaccinationNotifications() async {
    if (!isSupported) return;
    await init();
    await _plugin.cancelAllPendingNotifications();
    await _restoreElectricReminderIfEnabled();
  }

  Future<void> _restoreElectricReminderIfEnabled() async {
    if (storageService.getElectricReminderEnabled()) {
      await scheduleMonthlyElectricReminder();
    }
  }

  /// Repeats at 08:00 on the 1st of every month.
  Future<void> scheduleMonthlyElectricReminder() async {
    if (!isSupported) return;
    await init();

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, 1, 8);
    if (!scheduledDate.isAfter(now)) {
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month + 1, 1, 8);
    }

    final l10n = _localizations();
    await _plugin.zonedSchedule(
      id: _electricReminderId,
      title: l10n.electricNotificationTitle,
      body: l10n.electricNotificationBody,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _electricChannelId,
          _electricChannelName,
          channelDescription: _electricChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      payload: electricNotificationPayload,
    );
  }

  /// Draws a push that arrived while the app was in the foreground.
  ///
  /// Android hands a foreground message straight to the app instead of the
  /// system tray, so nothing is shown unless we draw it ourselves. Each one
  /// gets its own id: a second sale should not overwrite the first.
  Future<void> showSharedActivity({
    required String title,
    required String body,
    String? ownerId,
  }) async {
    if (!isSupported) return;
    await init();

    await _plugin.show(
      id: _sharedNotificationId++,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _sharedChannelId,
          _sharedChannelName,
          channelDescription: _sharedChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF00695C),
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      payload: ownerId == null ? null : '$sharedActivityPayloadPrefix$ownerId',
    );
  }

  /// Draws a storm alert that arrived while the app was in the foreground, for
  /// the same reason as [showSharedActivity]. Its own channel, so a reader can
  /// mute chicken activity and keep the weather warnings.
  Future<void> showStormAlert({
    required String title,
    required String body,
  }) async {
    if (!isSupported) return;
    await init();

    await _plugin.show(
      id: _stormNotificationId++,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _stormChannelId,
          _stormChannelName,
          channelDescription: _stormChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          color: Color(0xFFB3261E),
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      payload: stormAlertPayload,
    );
  }

  Future<void> cancelMonthlyElectricReminder() async {
    if (!isSupported) return;
    await init();
    await _plugin.cancel(id: _electricReminderId);
  }

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  AppLocalizations _localizations() {
    final languageCode =
        storageService.getLocale() ??
        PlatformDispatcher.instance.locale.languageCode;
    final locale = AppLocalizations.supportedLocales.firstWhere(
      (item) => item.languageCode == languageCode,
      orElse: () => AppLocalizations.supportedLocales.first,
    );
    return lookupAppLocalizations(locale);
  }
}

final notificationService = NotificationService();
