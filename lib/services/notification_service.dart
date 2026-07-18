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

  static const _channelId = 'chicken_vaccinations';
  static const _channelName = 'Lịch tiêm phòng';
  static const _channelDescription = 'Nhắc lịch tiêm phòng cho các lứa gà';

  static const _electricChannelId = 'electric_bill';
  static const _electricChannelName = 'Tiền điện';
  static const _electricChannelDescription =
      'Nhắc kiểm tra tiền điện đầu tháng';
  static const _electricReminderId = 0x0E1EC001;

  final _plugin = FlutterLocalNotificationsPlugin();
  final ValueNotifier<DateTime?> electricNotificationMonth = ValueNotifier(
    null,
  );
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
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
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

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        launchResponse != null) {
      _handleNotificationResponse(launchResponse);
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload != electricNotificationPayload) return;
    final now = DateTime.now();
    electricNotificationMonth.value = DateTime(now.year, now.month - 1);
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
      final date = reminder.vaccination.scheduledDate.toLocal();
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
