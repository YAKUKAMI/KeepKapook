import 'habit_streak.dart';

const int dailyReminderNotificationId = 41001;
const int weeklyReminderNotificationId = 41002;

class ReminderTime {
  const ReminderTime({required this.hour, required this.minute})
      : assert(hour >= 0 && hour <= 23),
        assert(minute >= 0 && minute <= 59);

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.dailyEnabled,
    required this.weeklyEnabled,
    required this.dailyTime,
    required this.weeklyTime,
    required this.permissionPromptHandled,
    required this.permissionGranted,
  });

  const NotificationPreferences.defaults()
      : dailyEnabled = false,
        weeklyEnabled = false,
        dailyTime = const ReminderTime(hour: 20, minute: 0),
        weeklyTime = const ReminderTime(hour: 9, minute: 0),
        permissionPromptHandled = false,
        permissionGranted = false;

  final bool dailyEnabled;
  final bool weeklyEnabled;
  final ReminderTime dailyTime;
  final ReminderTime weeklyTime;
  final bool permissionPromptHandled;
  final bool permissionGranted;

  NotificationPreferences copyWith({
    bool? dailyEnabled,
    bool? weeklyEnabled,
    ReminderTime? dailyTime,
    ReminderTime? weeklyTime,
    bool? permissionPromptHandled,
    bool? permissionGranted,
  }) =>
      NotificationPreferences(
        dailyEnabled: dailyEnabled ?? this.dailyEnabled,
        weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
        dailyTime: dailyTime ?? this.dailyTime,
        weeklyTime: weeklyTime ?? this.weeklyTime,
        permissionPromptHandled:
            permissionPromptHandled ?? this.permissionPromptHandled,
        permissionGranted: permissionGranted ?? this.permissionGranted,
      );
}

enum ReminderKind { daily, weeklyReview }

class ReminderPlan {
  const ReminderPlan({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.firstTrigger,
  });

  final int id;
  final ReminderKind kind;
  final String title;
  final String body;
  final DateTime firstTrigger;
}

String? selectReminderGoalName(Iterable<String?> candidates) {
  for (final candidate in candidates) {
    final clean = candidate?.trim();
    if (clean != null && clean.isNotEmpty) return clean;
  }
  return null;
}

String formatReminderTime(ReminderTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

DateTime nextDailyReminder({
  required DateTime now,
  required ReminderTime time,
}) {
  final localNow = bangkokLocalWallClock(now);
  var candidate = DateTime(
    localNow.year,
    localNow.month,
    localNow.day,
    time.hour,
    time.minute,
  );
  if (!candidate.isAfter(localNow)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}

DateTime nextWeeklyMondayReminder({
  required DateTime now,
  required ReminderTime time,
}) {
  final localNow = bangkokLocalWallClock(now);
  final daysUntilMonday = (DateTime.monday - localNow.weekday) % 7;
  var candidate = DateTime(
    localNow.year,
    localNow.month,
    localNow.day + daysUntilMonday,
    time.hour,
    time.minute,
  );
  if (!candidate.isAfter(localNow)) {
    candidate = candidate.add(const Duration(days: 7));
  }
  return candidate;
}

List<ReminderPlan> buildReminderPlans({
  required NotificationPreferences preferences,
  required DateTime now,
  String? goalName,
}) {
  if (!preferences.permissionGranted) return const <ReminderPlan>[];
  final cleanGoalName = goalName?.trim();
  final goalPhrase = cleanGoalName == null || cleanGoalName.isEmpty
      ? 'เป้าหมายของคุณ'
      : '“$cleanGoalName”';
  return <ReminderPlan>[
    if (preferences.dailyEnabled)
      ReminderPlan(
        id: dailyReminderNotificationId,
        kind: ReminderKind.daily,
        title: 'แวะบันทึกวันนี้กันไหม',
        body: 'วันนี้บันทึกหรือยัง? แวะเติมความคืบหน้าให้ $goalPhrase กัน',
        firstTrigger: nextDailyReminder(
          now: now,
          time: preferences.dailyTime,
        ),
      ),
    if (preferences.weeklyEnabled)
      ReminderPlan(
        id: weeklyReminderNotificationId,
        kind: ReminderKind.weeklyReview,
        title: 'สรุปสัปดาห์พร้อมแล้ว',
        body: 'เริ่มสัปดาห์ใหม่ด้วยการดูว่าเราเข้าใกล้ $goalPhrase แค่ไหนกัน',
        firstTrigger: nextWeeklyMondayReminder(
          now: now,
          time: preferences.weeklyTime,
        ),
      ),
  ];
}
