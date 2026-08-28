import 'local_notification_platform_contract.dart';
import 'local_notification_platform_stub.dart'
    if (dart.library.io) 'local_notification_platform_mobile.dart'
    as implementation;

LocalNotificationPlatform createLocalNotificationPlatform() =>
    implementation.createLocalNotificationPlatform();
