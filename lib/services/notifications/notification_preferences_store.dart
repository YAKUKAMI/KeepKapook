import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/notification_schedule.dart';

const notificationDailyEnabledKey = 'keepkapook_notification_daily_enabled';
const notificationWeeklyEnabledKey = 'keepkapook_notification_weekly_enabled';
const notificationDailyHourKey = 'keepkapook_notification_daily_hour';
const notificationDailyMinuteKey = 'keepkapook_notification_daily_minute';
const notificationWeeklyHourKey = 'keepkapook_notification_weekly_hour';
const notificationWeeklyMinuteKey = 'keepkapook_notification_weekly_minute';
const notificationPermissionPromptHandledKey =
    'keepkapook_notification_permission_prompt_handled';
const notificationPermissionGrantedKey =
    'keepkapook_notification_permission_granted';

abstract interface class NotificationPreferencesStore {
  Future<NotificationPreferences> load();

  Future<void> save(NotificationPreferences preferences);
}

class SharedPreferencesNotificationPreferencesStore
    implements NotificationPreferencesStore {
  const SharedPreferencesNotificationPreferencesStore();

  @override
  Future<NotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      dailyEnabled: prefs.getBool(notificationDailyEnabledKey) ?? false,
      weeklyEnabled: prefs.getBool(notificationWeeklyEnabledKey) ?? false,
      dailyTime: ReminderTime(
        hour: _bounded(prefs.getInt(notificationDailyHourKey), 0, 23, 20),
        minute: _bounded(prefs.getInt(notificationDailyMinuteKey), 0, 59, 0),
      ),
      weeklyTime: ReminderTime(
        hour: _bounded(prefs.getInt(notificationWeeklyHourKey), 0, 23, 9),
        minute: _bounded(prefs.getInt(notificationWeeklyMinuteKey), 0, 59, 0),
      ),
      permissionPromptHandled:
          prefs.getBool(notificationPermissionPromptHandledKey) ?? false,
      permissionGranted:
          prefs.getBool(notificationPermissionGrantedKey) ?? false,
    );
  }

  @override
  Future<void> save(NotificationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    final results = await Future.wait(<Future<bool>>[
      prefs.setBool(notificationDailyEnabledKey, preferences.dailyEnabled),
      prefs.setBool(notificationWeeklyEnabledKey, preferences.weeklyEnabled),
      prefs.setInt(notificationDailyHourKey, preferences.dailyTime.hour),
      prefs.setInt(notificationDailyMinuteKey, preferences.dailyTime.minute),
      prefs.setInt(notificationWeeklyHourKey, preferences.weeklyTime.hour),
      prefs.setInt(notificationWeeklyMinuteKey, preferences.weeklyTime.minute),
      prefs.setBool(
        notificationPermissionPromptHandledKey,
        preferences.permissionPromptHandled,
      ),
      prefs.setBool(
        notificationPermissionGrantedKey,
        preferences.permissionGranted,
      ),
    ]);
    if (results.any((saved) => !saved)) {
      throw StateError('บันทึกการตั้งค่าแจ้งเตือนไม่สำเร็จ');
    }
  }
}

int _bounded(int? value, int minimum, int maximum, int fallback) {
  if (value == null || value < minimum || value > maximum) return fallback;
  return value;
}
