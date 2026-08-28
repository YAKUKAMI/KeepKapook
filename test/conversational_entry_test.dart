import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/main.dart';
import 'package:keepkapook/screens/dashboard_screen.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  AppState createReadyApp({int goalCount = 1}) {
    final now = DateTime.utc(2026, 8, 27);
    return AppState()
      ..loaded = true
      ..user = AppUser(name: 'เมย์', exp: 7, onboarded: true)
      ..goals = List<Goal>.generate(
        goalCount,
        (index) => Goal(
          id: 'goal-$index',
          name: index == 0 ? 'เที่ยว' : 'ค่าเทอม',
          targetSatang: 100000,
          startDate: now,
          targetDate: now.add(const Duration(days: 90)),
        ),
      )
      ..quests = <Quest>[
        Quest(
          id: 'q-deposit',
          title: 'บันทึกเงินออม',
          description: 'เพิ่มเงินเข้ากระปุกวันนี้',
          period: 'daily',
          target: 1,
          expReward: 15,
        ),
      ]
      ..badges = <AchievementBadge>[
        AchievementBadge(
          id: 'b-first-drop',
          name: 'First Drop',
          description: 'ออมครั้งแรก',
          emoji: '💧',
          condition: 'บันทึกเงินออมครั้งแรก',
        ),
      ];
  }

  Widget wrap(AppState app) => MaterialApp(
        theme: buildAppTheme(),
        home: ChangeNotifierProvider<AppState>.value(
          value: app,
          child: const Scaffold(body: DashboardScreen()),
        ),
      );

  Future<void> openInput(WidgetTester tester) async {
    await tester.tap(find.text('พิมพ์บันทึกรายการ'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('conversational_entry_input')),
      findsOneWidget,
    );
  }

  testWidgets('high บันทึกทันทีและ undo คืนยอด EXP quest และ badge ครบ',
      (tester) async {
    final app = createReadyApp();
    await tester.pumpWidget(wrap(app));

    await openInput(tester);
    await tester.enterText(
      find.byKey(const Key('conversational_entry_input')),
      'ออม 300',
    );
    await tester.tap(find.byKey(const Key('conversational_entry_submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(app.transactions, hasLength(1));
    expect(app.goals.single.currentSatang, 30000);
    expect(app.user.exp, greaterThan(7));
    expect(app.quests.single.progress, 1);
    expect(app.badges.single.unlocked, isTrue);
    expect(find.textContaining('บันทึก'), findsWidgets);
    expect(find.text('ยกเลิก'), findsOneWidget);

    await tester.tap(find.text('ยกเลิก'));
    await tester.pump();

    expect(app.transactions, isEmpty);
    expect(app.goals.single.currentSatang, 0);
    expect(app.user.exp, 7);
    expect(app.quests.single.progress, 0);
    expect(app.badges.single.unlocked, isFalse);
    await app.flushPendingSaves();
  });

  testWidgets('low ถามหนึ่งคำถามและไม่สร้างรายการ', (tester) async {
    final app = createReadyApp(goalCount: 2);
    await tester.pumpWidget(wrap(app));

    await openInput(tester);
    await tester.enterText(
      find.byKey(const Key('conversational_entry_input')),
      'โอน500',
    );
    await tester.tap(find.byKey(const Key('conversational_entry_submit')));
    await tester.pump();

    expect(app.transactions, isEmpty);
    expect(app.ledger, isEmpty);
    expect(find.text('ต้องการบันทึกการโอนเป็นอะไร?'), findsOneWidget);
    expect(find.text('รายจ่าย'), findsOneWidget);
    expect(find.text('ย้ายเข้ากระปุก'), findsOneWidget);
  });

  testWidgets('ออมกับหลายกระปุกถามปลายทางก่อนและยังไม่บันทึก', (tester) async {
    final app = createReadyApp(goalCount: 2);
    await tester.pumpWidget(wrap(app));

    await openInput(tester);
    await tester.enterText(
      find.byKey(const Key('conversational_entry_input')),
      'ออม 300',
    );
    await tester.tap(find.byKey(const Key('conversational_entry_submit')));
    await tester.pump();

    expect(app.transactions, isEmpty);
    expect(find.text('ต้องการเก็บเงินเข้ากระปุกไหน?'), findsOneWidget);
    expect(find.text('เที่ยว'), findsOneWidget);
    expect(find.text('ค่าเทอม'), findsOneWidget);
  });

  testWidgets('medium บันทึกทันทีและเปลี่ยนหมวดในบรรทัดเดิมได้',
      (tester) async {
    final app = createReadyApp();
    await tester.pumpWidget(wrap(app));

    await openInput(tester);
    await tester.enterText(
      find.byKey(const Key('conversational_entry_input')),
      'จ่าย 100',
    );
    await tester.tap(find.byKey(const Key('conversational_entry_submit')));
    await tester.pump();

    expect(app.ledger, hasLength(1));
    expect(app.ledger.single.category, 'อื่น ๆ');
    expect(find.byKey(const Key('editable_category_chip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('editable_category_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('อาหาร').last);
    await tester.pump();

    expect(app.ledger.single.category, 'อาหาร');
    await app.flushPendingSaves();
  });

  testWidgets('medium ที่วันที่ไม่ชัดแสดง chip วันที่ให้แก้ในบรรทัดเดิม',
      (tester) async {
    final app = createReadyApp();
    await tester.pumpWidget(wrap(app));

    await openInput(tester);
    await tester.enterText(
      find.byKey(const Key('conversational_entry_input')),
      'กาแฟ 65 เมื่อสักครู่',
    );
    await tester.tap(find.byKey(const Key('conversational_entry_submit')));
    await tester.pump();

    expect(app.ledger, hasLength(1));
    expect(find.byKey(const Key('editable_date_chip')), findsOneWidget);
    expect(find.byKey(const Key('editable_category_chip')), findsNothing);
    await app.flushPendingSaves();
  });

  testWidgets('FAB เปิดบันทึกเร็วได้โดยไม่เปลี่ยนแท็บ', (tester) async {
    final app = createReadyApp();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: const KeepKapookApp(),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('บันทึกเร็ว'), findsOneWidget);
    await tester.tap(find.byTooltip('บันทึกเร็ว'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('quick-saving-5000')),
      findsOneWidget,
    );
    expect(find.text('ภาพรวม'), findsOneWidget);
  });
}
