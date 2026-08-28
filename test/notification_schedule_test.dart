import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/utils/notification_schedule.dart';

void main() {
  group('notification schedule', () {
    test('ค่าเริ่มต้นเป็นรายวัน 20:00 และวันจันทร์ 09:00', () {
      const preferences = NotificationPreferences.defaults();

      expect(preferences.dailyTime, const ReminderTime(hour: 20, minute: 0));
      expect(preferences.weeklyTime, const ReminderTime(hour: 9, minute: 0));
      expect(preferences.dailyEnabled, isFalse);
      expect(preferences.weeklyEnabled, isFalse);
    });

    test('daily เลื่อนไปวันถัดไปเมื่อเวลาวันนี้ผ่านแล้ว', () {
      final next = nextDailyReminder(
        now: DateTime.utc(2026, 8, 24, 14), // 21:00 กรุงเทพฯ
        time: const ReminderTime(hour: 20, minute: 0),
      );

      expect(next, DateTime(2026, 8, 25, 20));
    });

    test('daily ใช้วันนี้เมื่อเวลาไทยยังไม่ถึง แม้ input เป็น UTC', () {
      final next = nextDailyReminder(
        now: DateTime.utc(2026, 8, 24, 12), // 19:00 กรุงเทพฯ
        time: const ReminderTime(hour: 20, minute: 0),
      );

      expect(next, DateTime(2026, 8, 24, 20));
    });

    test('weekly เลื่อนไปจันทร์ถัดไปและไม่ตั้งถี่กว่าสัปดาห์ละครั้ง', () {
      final next = nextWeeklyMondayReminder(
        now: DateTime.utc(2026, 8, 24, 3), // จันทร์ 10:00 กรุงเทพฯ
        time: const ReminderTime(hour: 9, minute: 0),
      );

      expect(next, DateTime(2026, 8, 31, 9));
    });

    test('สร้างอย่างมากหนึ่ง schedule ต่อประเภทและอ้างอิงเป้าหมาย', () {
      const preferences = NotificationPreferences(
        dailyEnabled: true,
        weeklyEnabled: true,
        dailyTime: ReminderTime(hour: 20, minute: 0),
        weeklyTime: ReminderTime(hour: 9, minute: 0),
        permissionPromptHandled: true,
        permissionGranted: true,
      );

      final plans = buildReminderPlans(
        preferences: preferences,
        now: DateTime.utc(2026, 8, 23, 12),
        goalName: 'iPhone มือสอง',
      );

      expect(plans, hasLength(2));
      expect(plans.map((plan) => plan.kind).toSet(), hasLength(2));
      expect(
          plans.every((plan) => plan.body.contains('iPhone มือสอง')), isTrue);
      expect(plans.any((plan) => plan.body.contains('หนี้')), isFalse);
      expect(plans.any((plan) => plan.body.contains('ล้มเหลว')), isFalse);
    });
  });
}
