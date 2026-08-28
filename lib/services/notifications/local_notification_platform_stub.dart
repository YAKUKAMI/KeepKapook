import 'local_notification_platform_contract.dart';

LocalNotificationPlatform createLocalNotificationPlatform() =>
    const WebLocalNotificationStub();

class WebLocalNotificationStub implements LocalNotificationPlatform {
  const WebLocalNotificationStub();

  @override
  bool get isSupported => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> schedule(LocalReminderRequest request) async {}

  @override
  Future<void> cancel(int id) async {}
}
