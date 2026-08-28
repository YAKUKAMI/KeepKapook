import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keepkapook/main.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/theme/app_theme.dart';
import 'package:keepkapook/widgets/simulation_notice.dart';
import 'package:keepkapook/screens/goals_screen.dart';
import 'package:keepkapook/screens/goal_detail_screen.dart';
import 'package:keepkapook/screens/quests_screen.dart';
import 'package:keepkapook/screens/history_screen.dart';
import 'package:keepkapook/screens/settings_screen.dart';
import 'package:keepkapook/screens/ledger_screen.dart';
import 'package:keepkapook/screens/achievements_screen.dart';
import 'package:keepkapook/screens/unallocated_screen.dart';
import 'package:keepkapook/screens/dashboard_screen.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  // ห่อ widget ด้วย MaterialApp + Provider (มี mock data)
  Widget wrap(Widget child, {bool inScaffold = false}) => MaterialApp(
        theme: buildAppTheme(),
        home: ChangeNotifierProvider(
          create: (_) => AppState()..load(),
          child: inScaffold ? Scaffold(body: child) : child,
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('boot แอป (ว่างเปล่า) → เห็น disclaimer ก่อน onboarding',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState()..load(),
        child: const KeepKapookApp(),
      ),
    );
    await settle(tester);

    expect(find.text('ก่อนเริ่มใช้งาน'), findsOneWidget);
    expect(
      find.text('KeepKapook ช่วยบันทึก ไม่ได้เก็บเงินจริง'),
      findsOneWidget,
    );
    expect(find.textContaining('ไม่ใช่แอปธนาคาร'), findsOneWidget);
    expect(find.text('มาทำความรู้จักกัน'), findsNothing);

    await tester.tap(find.text('เข้าใจแล้ว'));
    await tester.pumpAndSettle();
    expect(find.text('มาทำความรู้จักกัน'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  // แต่ละหน้าจอ build ได้ไม่ crash
  final screens = <String, Widget>{
    'Dashboard': const DashboardScreen(),
    'Goals': const GoalsScreen(),
    'Quests': const QuestsScreen(),
    'History': const HistoryScreen(),
    'Settings': const SettingsScreen(),
    'Ledger': const LedgerScreen(),
    'Achievements': const AchievementsScreen(),
    'Unallocated': const UnallocatedScreen(),
  };

  screens.forEach((name, widget) {
    testWidgets('หน้า $name build ไม่ crash', (tester) async {
      await tester.pumpWidget(wrap(widget, inScaffold: name == 'Dashboard'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('หน้า Settings มีเมนูสำรองและกู้คืนข้อมูล', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await settle(tester);

    expect(find.text('เกี่ยวกับแอป'), findsOneWidget);
    expect(find.text(SimulationNotice.generalMessage), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('สำรองข้อมูล'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('สำรองข้อมูล'), findsOneWidget);
    expect(find.text('กู้คืนข้อมูล'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('หน้ากระปุกแสดงป้ายจำลองและคำอธิบายล็อกเงิน', (tester) async {
    final now = DateTime.now();
    final app = AppState()
      ..loaded = true
      ..goals = [
        Goal(
          id: 'goal-a',
          name: 'เที่ยว',
          targetSatang: 100000,
          currentSatang: 50000,
          startDate: now,
          targetDate: now.add(const Duration(days: 90)),
        ),
        Goal(
          id: 'goal-b',
          name: 'สำรอง',
          targetSatang: 100000,
          startDate: now,
          targetDate: now.add(const Duration(days: 120)),
        ),
      ];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ChangeNotifierProvider.value(
          value: app,
          child: const GoalDetailScreen(goalId: 'goal-a'),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('จำลอง'), findsNWidgets(4));
    await tester.tap(find.widgetWithText(OutlinedButton, 'ล็อก'));
    await tester.pumpAndSettle();
    expect(find.text(SimulationNotice.lockMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
