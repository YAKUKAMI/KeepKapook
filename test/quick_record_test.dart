import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/services/quick_entry/quick_entry_controller.dart';
import 'package:keepkapook/services/quick_entry/quick_entry_preferences_store.dart';
import 'package:keepkapook/screens/dashboard_screen.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/theme/app_theme.dart';
import 'package:keepkapook/widgets/quick_amount_settings.dart';
import 'package:keepkapook/widgets/quick_record_sheet.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  AppState readyApp() {
    final now = DateTime.utc(2026, 8, 28);
    return AppState()
      ..loaded = true
      ..user = AppUser(name: 'เมย์', exp: 7, onboarded: true)
      ..goals = <Goal>[
        Goal(
          id: 'goal-1',
          name: 'เที่ยว',
          targetSatang: 100000,
          startDate: now,
          targetDate: now.add(const Duration(days: 90)),
        ),
      ]
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

  Future<QuickEntryController> readyQuickController() async {
    final controller = QuickEntryController(
      store: const SharedPreferencesQuickEntryPreferencesStore(),
    );
    await controller.load();
    return controller;
  }

  Widget wrap({
    required AppState app,
    required QuickEntryController quickEntries,
    Widget child = const QuickRecordLauncher(),
  }) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppState>.value(value: app),
        ChangeNotifierProvider<QuickEntryController>.value(value: quickEntries),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('กด 50 แล้วยอดเพิ่มและ undo คืน state ทั้งก้อน', (tester) async {
    final app = readyApp();
    final quickEntries = await readyQuickController();
    final before = app.toJson();
    final expectedAfterUndo = Map<String, dynamic>.from(before);
    final expectedMetrics = Map<String, dynamic>.from(
      before['metrics']! as Map<String, dynamic>,
    )..['undoCount'] = 1;
    expectedAfterUndo['metrics'] = expectedMetrics;
    await tester.pumpWidget(wrap(app: app, quickEntries: quickEntries));

    await tester.tap(find.byKey(const Key('quick-saving-launcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-saving-5000')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(app.goals.single.currentSatang, 5000);
    expect(find.textContaining('เป้าหมาย 5%'), findsOneWidget);
    expect(find.text('ยกเลิก'), findsOneWidget);

    await tester.tap(find.text('ยกเลิก'));
    await tester.pump();

    // I12: undo must restore all domain state. The local-only undo metric is
    // intentionally append-only and records that the recovery path was used.
    expect(app.toJson(), expectedAfterUndo);
    await app.flushPendingSaves();
  });

  testWidgets('บันทึกรายจ่ายแล้วสรุปบน dashboard อัปเดตทันที', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = readyApp();
    final quickEntries = await readyQuickController();
    await tester.pumpWidget(
      wrap(
        app: app,
        quickEntries: quickEntries,
        child: const DashboardScreen(),
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('quick-expense-launcher')));
    await tester.tap(find.byKey(const Key('quick-expense-launcher')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-expense-amount')),
      '150',
    );
    await tester.tap(find.byKey(const Key('quick-expense-save')));
    await tester.pump();

    expect(app.ledger.single.amountSatang, 15000);
    expect(app.ledger.single.category, 'อาหาร');
    expect(app.ledger.single.note, isEmpty);
    await tester.scrollUntilVisible(
      find.text('รายรับ-รายจ่ายเดือนนี้'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('รับ ฿0 · จ่าย ฿150'), findsOneWidget);
    expect(find.textContaining('รายจ่ายเดือนนี้ ฿150'), findsOneWidget);
    expect(find.text('ยกเลิก'), findsOneWidget);
    await app.flushPendingSaves();
  });

  testWidgets('หลายกระปุกเลือกปลายทางและจำนวนใน bottom sheet เดียว',
      (tester) async {
    final app = readyApp()
      ..goals.add(
        Goal(
          id: 'goal-2',
          name: 'โน้ตบุ๊ก',
          targetSatang: 200000,
          startDate: DateTime.utc(2026, 8, 28),
          targetDate: DateTime.utc(2026, 12, 31),
        ),
      );
    final quickEntries = await readyQuickController();
    await tester.pumpWidget(wrap(app: app, quickEntries: quickEntries));

    await tester.tap(find.byKey(const Key('quick-saving-launcher')));
    await tester.pumpAndSettle();
    expect(find.byType(QuickRecordSheet), findsOneWidget);

    final amountButton = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('quick-saving-5000')),
    );
    expect(amountButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('quick-goal-goal-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick-saving-5000')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(app.goals[0].currentSatang, 0);
    expect(app.goals[1].currentSatang, 5000);
    expect(find.byType(QuickRecordSheet), findsNothing);
    await app.flushPendingSaves();
  });

  testWidgets('Settings แก้ชุดจำนวนและบันทึกไว้ใช้ครั้งถัดไป', (tester) async {
    final quickEntries = await readyQuickController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: ChangeNotifierProvider<QuickEntryController>.value(
            value: quickEntries,
            child: Builder(
              builder: (context) => QuickAmountSettings(
                controller: context.watch<QuickEntryController>(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('edit-quick-amounts')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-amount-input-0')),
      '25',
    );
    await tester.enterText(
      find.byKey(const Key('quick-amount-input-1')),
      '75',
    );
    await tester.enterText(
      find.byKey(const Key('quick-amount-input-2')),
      '200',
    );
    await tester.tap(find.byKey(const Key('save-quick-amounts')));
    await tester.pumpAndSettle();

    expect(quickEntries.savingAmountsSatang, <int>[2500, 7500, 20000]);
    final reloaded = await readyQuickController();
    expect(reloaded.savingAmountsSatang, <int>[2500, 7500, 20000]);
  });

  testWidgets('รายจ่ายเร็วจำหมวดล่าสุดที่ใช้', (tester) async {
    final app = readyApp();
    final quickEntries = await readyQuickController();
    await quickEntries.rememberExpenseCategory('เดินทาง');
    await tester.pumpWidget(wrap(app: app, quickEntries: quickEntries));

    await tester.tap(find.byKey(const Key('quick-expense-launcher')));
    await tester.pumpAndSettle();

    final travelChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('quick-expense-category-เดินทาง')),
    );
    expect(travelChip.selected, isTrue);
  });
}
