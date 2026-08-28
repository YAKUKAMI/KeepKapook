import 'package:flutter/foundation.dart';

import '../../utils/notification_schedule.dart';
import 'local_notification_platform.dart';
import 'local_notification_platform_contract.dart';
import 'notification_preferences_store.dart';

class NotificationController extends ChangeNotifier {
  NotificationController({
    LocalNotificationPlatform? platform,
    NotificationPreferencesStore? store,
    DateTime Function()? now,
  })  : _platform = platform ?? createLocalNotificationPlatform(),
        _store = store ?? const SharedPreferencesNotificationPreferencesStore(),
        _now = now ?? DateTime.now;

  final LocalNotificationPlatform _platform;
  final NotificationPreferencesStore _store;
  final DateTime Function() _now;

  NotificationPreferences preferences =
      const NotificationPreferences.defaults();
  bool loaded = false;
  bool busy = false;
  String? errorMessage;

  bool get isSupported => _platform.isSupported;

  Future<void> load({String? goalName}) async {
    if (!isSupported) {
      loaded = true;
      notifyListeners();
      return;
    }
    try {
      await _platform.initialize();
      preferences = await _store.load();
      if (preferences.permissionGranted) {
        await _syncSchedules(goalName: goalName);
      }
    } catch (_) {
      errorMessage =
          'เตรียมการแจ้งเตือนไม่สำเร็จ แอปส่วนอื่นยังใช้งานได้ตามปกติ';
    } finally {
      loaded = true;
      notifyListeners();
    }
  }

  Future<bool> acceptPermissionOffer({String? goalName}) async {
    if (!isSupported || preferences.permissionPromptHandled) {
      return preferences.permissionGranted;
    }
    busy = true;
    preferences = preferences.copyWith(permissionPromptHandled: true);
    notifyListeners();
    try {
      await _store.save(preferences);
      final granted = await _platform.requestPermission();
      preferences = preferences.copyWith(
        permissionGranted: granted,
        dailyEnabled: granted,
        weeklyEnabled: granted,
      );
      await _store.save(preferences);
      if (granted) {
        await _syncSchedules(goalName: goalName);
      } else {
        await _cancelAll();
      }
      return granted;
    } catch (_) {
      preferences = preferences.copyWith(
        permissionGranted: false,
        dailyEnabled: false,
        weeklyEnabled: false,
      );
      errorMessage =
          'เปิดการแจ้งเตือนไม่สำเร็จ แอปจะไม่ถามสิทธิ์ซ้ำและยังใช้งานได้ตามปกติ';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> declinePermissionOffer() async {
    if (!isSupported || preferences.permissionPromptHandled) return;
    busy = true;
    preferences = preferences.copyWith(
      permissionPromptHandled: true,
      permissionGranted: false,
      dailyEnabled: false,
      weeklyEnabled: false,
    );
    notifyListeners();
    try {
      await _store.save(preferences);
      await _cancelAll();
    } catch (_) {
      errorMessage =
          'บันทึกตัวเลือกการแจ้งเตือนไม่สำเร็จ แอปส่วนอื่นยังใช้งานได้ตามปกติ';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> setDailyEnabled(bool enabled, {String? goalName}) async {
    if (!isSupported || (enabled && !preferences.permissionGranted)) return;
    await _update(
      preferences.copyWith(dailyEnabled: enabled),
      goalName: goalName,
    );
  }

  Future<void> setWeeklyEnabled(bool enabled, {String? goalName}) async {
    if (!isSupported || (enabled && !preferences.permissionGranted)) return;
    await _update(
      preferences.copyWith(weeklyEnabled: enabled),
      goalName: goalName,
    );
  }

  Future<void> setDailyTime(ReminderTime time, {String? goalName}) => _update(
        preferences.copyWith(dailyTime: time),
        goalName: goalName,
      );

  Future<void> setWeeklyTime(ReminderTime time, {String? goalName}) => _update(
        preferences.copyWith(weeklyTime: time),
        goalName: goalName,
      );

  Future<void> refreshSchedules({String? goalName}) async {
    if (!isSupported || !loaded || !preferences.permissionGranted) return;
    try {
      await _syncSchedules(goalName: goalName);
    } catch (_) {
      errorMessage =
          'อัปเดตข้อความเตือนไม่สำเร็จ การบันทึกรายการยังสำเร็จตามปกติ';
      notifyListeners();
    }
  }

  void clearErrorMessage() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _update(
    NotificationPreferences updated, {
    String? goalName,
  }) async {
    if (!isSupported) return;
    busy = true;
    preferences = updated;
    notifyListeners();
    try {
      await _store.save(preferences);
      await _syncSchedules(goalName: goalName);
    } catch (_) {
      errorMessage = 'บันทึกการตั้งค่าแจ้งเตือนไม่สำเร็จ กรุณาลองอีกครั้ง';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _syncSchedules({String? goalName}) async {
    final plans = buildReminderPlans(
      preferences: preferences,
      now: _now(),
      goalName: goalName,
    );
    final plansById = {for (final plan in plans) plan.id: plan};
    for (final id in const <int>[
      dailyReminderNotificationId,
      weeklyReminderNotificationId,
    ]) {
      final plan = plansById[id];
      if (plan == null) {
        await _platform.cancel(id);
        continue;
      }
      await _platform.schedule(
        LocalReminderRequest(
          id: plan.id,
          title: plan.title,
          body: plan.body,
          firstTrigger: plan.firstTrigger,
          repeat: plan.kind == ReminderKind.daily
              ? ReminderRepeat.daily
              : ReminderRepeat.weeklyMonday,
        ),
      );
    }
  }

  Future<void> _cancelAll() async {
    await _platform.cancel(dailyReminderNotificationId);
    await _platform.cancel(weeklyReminderNotificationId);
  }
}
