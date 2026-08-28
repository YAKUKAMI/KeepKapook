import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'local_notification_platform_contract.dart';

LocalNotificationPlatform createLocalNotificationPlatform() =>
    MobileLocalNotificationPlatform();

class MobileLocalNotificationPlatform implements LocalNotificationPlatform {
  MobileLocalNotificationPlatform({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _locationName = 'Asia/Bangkok';
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'habit_reminders',
      'เตือนบันทึกและสรุป',
      channelDescription:
          'เตือนให้กลับมาบันทึกและดูความคืบหน้าตามที่ผู้ใช้เลือก',
    ),
    iOS: DarwinNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_locationName));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await initialize();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  @override
  Future<void> schedule(LocalReminderRequest request) async {
    if (!isSupported) return;
    await initialize();
    final at = request.firstTrigger;
    final scheduledDate = tz.TZDateTime(
      tz.local,
      at.year,
      at.month,
      at.day,
      at.hour,
      at.minute,
    );
    await _plugin.zonedSchedule(
      id: request.id,
      title: request.title,
      body: request.body,
      scheduledDate: scheduledDate,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: request.repeat == ReminderRepeat.daily
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime,
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!isSupported) return;
    await initialize();
    await _plugin.cancel(id: id);
  }
}
