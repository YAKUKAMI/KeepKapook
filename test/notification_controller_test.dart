import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keepkapook/services/notifications/local_notification_platform_contract.dart';
import 'package:keepkapook/services/notifications/notification_controller.dart';
import 'package:keepkapook/services/notifications/notification_preferences_store.dart';
import 'package:keepkapook/utils/notification_schedule.dart';

class _FakePlatform implements LocalNotificationPlatform {
  _FakePlatform({this.supported = true, this.permissionResult = true});

  final bool supported;
  bool permissionResult;
  int initializeCount = 0;
  int permissionRequestCount = 0;
  final List<LocalReminderRequest> scheduled = [];
  final List<int> cancelled = [];

  @override
  bool get isSupported => supported;

  @override
  Future<void> initialize() async => initializeCount++;

  @override
  Future<bool> requestPermission() async {
    permissionRequestCount++;
    return permissionResult;
  }

  @override
  Future<void> schedule(LocalReminderRequest request) async {
    scheduled.add(request);
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

class _MemoryStore implements NotificationPreferencesStore {
  _MemoryStore([this.value = const NotificationPreferences.defaults()]);

  NotificationPreferences value;
  int loadCount = 0;
  int saveCount = 0;

  @override
  Future<NotificationPreferences> load() async {
    loadCount++;
    return value;
  }

  @override
  Future<void> save(NotificationPreferences preferences) async {
    saveCount++;
    value = preferences;
  }
}

void main() {
  final fixedNow = DateTime.utc(2026, 8, 23, 12);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('load ไม่ขอ permission ตอนเปิดแอป', () async {
    final platform = _FakePlatform();
    final controller = NotificationController(
      platform: platform,
      store: _MemoryStore(),
      now: () => fixedNow,
    );

    await controller.load();

    expect(controller.loaded, isTrue);
    expect(platform.permissionRequestCount, 0);
    expect(platform.scheduled, isEmpty);
  });

  test('ยอมรับครั้งแรกเปิดสองประเภทและตั้ง schedule ตามค่าเริ่มต้น', () async {
    final platform = _FakePlatform();
    final store = _MemoryStore();
    final controller = NotificationController(
      platform: platform,
      store: store,
      now: () => fixedNow,
    );
    await controller.load();

    final granted = await controller.acceptPermissionOffer(
      goalName: 'iPhone มือสอง',
    );

    expect(granted, isTrue);
    expect(platform.permissionRequestCount, 1);
    expect(store.value.permissionPromptHandled, isTrue);
    expect(store.value.permissionGranted, isTrue);
    expect(store.value.dailyEnabled, isTrue);
    expect(store.value.weeklyEnabled, isTrue);
    expect(
      platform.scheduled.map((request) => request.id).toSet(),
      {dailyReminderNotificationId, weeklyReminderNotificationId},
    );
    expect(
      platform.scheduled.every(
        (request) => request.body.contains('iPhone มือสอง'),
      ),
      isTrue,
    );
  });

  test('ปฏิเสธ permission แล้วไม่ขอซ้ำ', () async {
    final platform = _FakePlatform(permissionResult: false);
    final controller = NotificationController(
      platform: platform,
      store: _MemoryStore(),
      now: () => fixedNow,
    );
    await controller.load();

    expect(await controller.acceptPermissionOffer(), isFalse);
    expect(await controller.acceptPermissionOffer(), isFalse);

    expect(platform.permissionRequestCount, 1);
    expect(controller.preferences.permissionPromptHandled, isTrue);
    expect(controller.preferences.dailyEnabled, isFalse);
    expect(controller.preferences.weeklyEnabled, isFalse);
  });

  test('เลือกไม่ใช้จากคำอธิบายแล้วไม่เรียก system permission', () async {
    final platform = _FakePlatform();
    final controller = NotificationController(
      platform: platform,
      store: _MemoryStore(),
      now: () => fixedNow,
    );
    await controller.load();

    await controller.declinePermissionOffer();

    expect(platform.permissionRequestCount, 0);
    expect(controller.preferences.permissionPromptHandled, isTrue);
  });

  test('ปิด daily ยกเลิก id เดิมโดยไม่แตะ weekly', () async {
    const existing = NotificationPreferences(
      dailyEnabled: true,
      weeklyEnabled: true,
      dailyTime: ReminderTime(hour: 20, minute: 0),
      weeklyTime: ReminderTime(hour: 9, minute: 0),
      permissionPromptHandled: true,
      permissionGranted: true,
    );
    final platform = _FakePlatform();
    final controller = NotificationController(
      platform: platform,
      store: _MemoryStore(existing),
      now: () => fixedNow,
    );
    await controller.load();
    platform.cancelled.clear();

    await controller.setDailyEnabled(false, goalName: 'ทริปทะเล');

    expect(platform.cancelled, contains(dailyReminderNotificationId));
    expect(controller.preferences.weeklyEnabled, isTrue);
    expect(controller.preferences.dailyEnabled, isFalse);
  });

  test('เลือกเวลาใหม่ persist และแทน schedule id เดิม', () async {
    const existing = NotificationPreferences(
      dailyEnabled: true,
      weeklyEnabled: false,
      dailyTime: ReminderTime(hour: 20, minute: 0),
      weeklyTime: ReminderTime(hour: 9, minute: 0),
      permissionPromptHandled: true,
      permissionGranted: true,
    );
    final platform = _FakePlatform();
    final store = _MemoryStore(existing);
    final controller = NotificationController(
      platform: platform,
      store: store,
      now: () => fixedNow,
    );
    await controller.load();

    await controller.setDailyTime(
      const ReminderTime(hour: 21, minute: 30),
      goalName: 'ทริปทะเล',
    );

    expect(store.value.dailyTime, const ReminderTime(hour: 21, minute: 30));
    final daily = platform.scheduled.lastWhere(
      (request) => request.id == dailyReminderNotificationId,
    );
    expect(daily.firstTrigger, DateTime(2026, 8, 23, 21, 30));
  });

  test('SharedPreferences store เก็บเวลาและสถานะ permission ครบ', () async {
    const expected = NotificationPreferences(
      dailyEnabled: true,
      weeklyEnabled: false,
      dailyTime: ReminderTime(hour: 18, minute: 45),
      weeklyTime: ReminderTime(hour: 10, minute: 15),
      permissionPromptHandled: true,
      permissionGranted: true,
    );
    const store = SharedPreferencesNotificationPreferencesStore();

    await store.save(expected);
    final loaded = await store.load();

    expect(loaded.dailyEnabled, expected.dailyEnabled);
    expect(loaded.weeklyEnabled, expected.weeklyEnabled);
    expect(loaded.dailyTime, expected.dailyTime);
    expect(loaded.weeklyTime, expected.weeklyTime);
    expect(loaded.permissionPromptHandled, isTrue);
    expect(loaded.permissionGranted, isTrue);
  });

  test('web/unsupported ปิดเงียบโดยไม่ initialize หรืออ่าน preferences',
      () async {
    final platform = _FakePlatform(supported: false);
    final store = _MemoryStore();
    final controller = NotificationController(
      platform: platform,
      store: store,
      now: () => fixedNow,
    );

    await controller.load();

    expect(controller.isSupported, isFalse);
    expect(controller.loaded, isTrue);
    expect(platform.initializeCount, 0);
    expect(store.loadCount, 0);
  });
}
