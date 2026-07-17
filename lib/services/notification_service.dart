import 'package:do_x/model/chicken/chicken_batch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static const _channelId = 'chicken_vaccinations';
  static const _channelName = 'Lịch tiêm phòng';
  static const _channelDescription = 'Nhắc lịch tiêm phòng cho các lứa gà';

  final _plugin = FlutterLocalNotificationsPlugin();
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
    );
    _initialized = true;
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
        title: 'Lịch tiêm: ${reminder.vaccination.title}',
        body: 'Lứa ${reminder.batch.name} đến lịch tiêm phòng hôm nay.',
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
  }

  Future<void> cancelVaccinationNotifications() async {
    if (!isSupported) return;
    await init();
    await _plugin.cancelAllPendingNotifications();
  }

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

final notificationService = NotificationService();
