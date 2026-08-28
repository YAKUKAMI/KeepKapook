enum ReminderRepeat { daily, weeklyMonday }

class LocalReminderRequest {
  const LocalReminderRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.firstTrigger,
    required this.repeat,
  });

  final int id;
  final String title;
  final String body;
  final DateTime firstTrigger;
  final ReminderRepeat repeat;
}

abstract interface class LocalNotificationPlatform {
  bool get isSupported;

  Future<void> initialize();

  Future<bool> requestPermission();

  Future<void> schedule(LocalReminderRequest request);

  Future<void> cancel(int id);
}
