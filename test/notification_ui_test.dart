import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:keepkapook/main.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/screens/settings_screen.dart';
import 'package:keepkapook/services/notifications/local_notification_platform_contract.dart';
import 'package:keepkapook/services/notifications/notification_controller.dart';
import 'package:keepkapook/services/notifications/notification_preferences_store.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/theme/app_theme.dart';
import 'package:keepkapook/utils/notification_schedule.dart';

class _FakePlatform implements LocalNotificationPlatform {
  _FakePlatform({this.supported = true, this.permissionResult = true});

  final bool supported;
  final bool permissionResult;
  int permissionRequestCount = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    permissionRequestCount++;
    return permissionResult;
  }

  @override
  Future<void> schedule(LocalReminderRequest request) async {}

  @override
  Future<void> cancel(int id) async {}
}

class _MemoryStore implements NotificationPreferencesStore {
  _MemoryStore([this.value = const NotificationPreferences.defaults()]);

  NotificationPreferences value;

  @override
  Future<NotificationPreferences> load() async => value;

  @override
  Future<void> save(NotificationPreferences preferences) async {
    value = preferences;
  }
}

Widget _wrap({
  required AppState app,
  required NotificationController notifications,
  required Widget child,
}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: app),
        ChangeNotifierProvider<NotificationController>.value(
          value: notifications,
        ),
      ],
      child: MaterialApp(theme: buildAppTheme(), home: child),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ขอสิทธิ์หลังบันทึกแรก และปฏิเสธแล้วไม่ถามซ้ำ', (tester) async {
    final app = AppState()
      ..loaded = true
      ..user.onboarded = true;
    final platform = _FakePlatform(permissionResult: false);
    final notifications = NotificationController(
      platform: platform,
      store: _MemoryStore(),
      now: () => DateTime.utc(2026, 8, 24, 12),
    );
    await notifications.load();
    await tester.pumpWidget(
      _wrap(
        app: app,
        notifications: notifications,
        child: const HomeShell(),
      ),
    );

    expect(find.text('ให้เราช่วยเตือนแบบเบา ๆ ไหม?'), findsNothing);

    app.addLedger(LedgerType.expense, 15000, 'อาหาร', 'ข้าวขาหมู');
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('ให้เราช่วยเตือนแบบเบา ๆ ไหม?'), findsOneWidget);
    await tester.tap(find.text('เปิดการเตือน'));
    await tester.pumpAndSettle();
    expect(platform.permissionRequestCount, 1);
    expect(notifications.preferences.permissionPromptHandled, isTrue);

    app.addLedger(LedgerType.expense, 5000, 'เดินทาง', 'รถเมล์');
    await tester.pumpAndSettle();

    expect(find.text('ให้เราช่วยเตือนแบบเบา ๆ ไหม?'), findsNothing);
    expect(platform.permissionRequestCount, 1);
    await app.flushPendingSaves();
  });

  testWidgets('Settings เปิดปิดสองประเภทแยกกันและแสดงเวลาเริ่มต้น',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = AppState()
      ..loaded = true
      ..user.onboarded = true;
    const enabled = NotificationPreferences(
      dailyEnabled: true,
      weeklyEnabled: true,
      dailyTime: ReminderTime(hour: 20, minute: 0),
      weeklyTime: ReminderTime(hour: 9, minute: 0),
      permissionPromptHandled: true,
      permissionGranted: true,
    );
    final notifications = NotificationController(
      platform: _FakePlatform(),
      store: _MemoryStore(enabled),
      now: () => DateTime.utc(2026, 8, 24, 12),
    );
    await notifications.load();
    await tester.pumpWidget(
      _wrap(
        app: app,
        notifications: notifications,
        child: const SettingsScreen(),
      ),
    );

    expect(
        find.byKey(const Key('notification-settings-section')), findsOneWidget);
    expect(find.text('บันทึกประจำวัน'), findsOneWidget);
    expect(find.text('ดูสรุปสัปดาห์'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);

    final dailySwitch = find.byKey(const Key('daily-notification-switch'));
    await tester.ensureVisible(dailySwitch);
    await tester.tap(dailySwitch);
    await tester.pumpAndSettle();

    expect(notifications.preferences.dailyEnabled, isFalse);
    expect(notifications.preferences.weeklyEnabled, isTrue);
  });

  testWidgets('web/unsupported ไม่แสดงเมนูที่กดแล้วไม่ทำงาน', (tester) async {
    final app = AppState()
      ..loaded = true
      ..user.onboarded = true;
    final notifications = NotificationController(
      platform: _FakePlatform(supported: false),
      store: _MemoryStore(),
    );
    await notifications.load();
    await tester.pumpWidget(
      _wrap(
        app: app,
        notifications: notifications,
        child: const SettingsScreen(),
      ),
    );

    expect(
        find.byKey(const Key('notification-settings-section')), findsNothing);
  });
}
