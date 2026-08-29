import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/screens/add_saving_screen.dart';
import 'package:keepkapook/services/product_event_store.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/theme/app_theme.dart';
import 'package:keepkapook/utils/product_events.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('celebration เสนอเป้าค้างในหน้าจอเดียวกันและไว้ก่อนไม่ลงโทษ',
      (tester) async {
    final app = _readyApp();
    final events = _MemoryProductEventStore();
    await tester.pumpWidget(_wrap(app, events));

    await _completeFirstGoal(tester);

    expect(find.text('ถึงเป้าหมายแล้ว! 🎉'), findsOneWidget);
    expect(find.textContaining('เก็บต่อให้ เที่ยวญี่ปุ่น ไหม'), findsOneWidget);
    expect(find.byKey(const Key('celebration-continue')), findsOneWidget);
    expect(find.byKey(const Key('celebration-later')), findsOneWidget);

    final stateAfterCelebration = app.toJson();
    await tester.ensureVisible(find.byKey(const Key('celebration-later')));
    await tester.tap(find.byKey(const Key('celebration-later')));
    await tester.pumpAndSettle();

    expect(app.toJson(), equals(stateAfterCelebration));
    expect(events.events, hasLength(1));
    expect(
      events.events.single.name,
      ProductEventName.nextGoalOfferDeferred,
    );
    expect(find.text('เปิดหน้าบันทึก'), findsOneWidget);
    await app.flushPendingSaves();
  });

  testWidgets('ยอดยังไม่จัดสรรย้ายเข้าเป้าถัดไปได้คลิกเดียวและรักษา TOTAL',
      (tester) async {
    final app = _readyApp(unallocatedSatang: 5000);
    app.goals[1]
      ..currentSatang = 47000
      ..highestMilestonePercent = 75;
    final events = _MemoryProductEventStore();
    await tester.pumpWidget(_wrap(app, events));

    await _completeFirstGoal(tester);

    expect(find.byKey(const Key('celebration-allocate')), findsOneWidget);
    expect(find.textContaining('ยอดยังไม่จัดสรร ฿50'), findsOneWidget);
    final totalBefore = _total(app);
    final expBefore = app.user.exp;

    await tester.ensureVisible(find.byKey(const Key('celebration-allocate')));
    await tester.tap(find.byKey(const Key('celebration-allocate')));
    await tester.pumpAndSettle();

    expect(app.goals[1].currentSatang, 50000);
    expect(app.unallocatedSatang, 2000);
    expect(_total(app), totalBefore);
    expect(app.user.exp, expBefore);
    expect(events.events.single.name, ProductEventName.nextGoalOfferAccepted);
    expect(find.text('เปิดหน้าบันทึก'), findsOneWidget);
    await app.flushPendingSaves();
  });

  testWidgets('ไม่มีเป้าอื่นจะแสดงทางลัดสร้างเป้าโดยไม่บล็อกการปิด',
      (tester) async {
    final app = _readyApp()..goals.removeLast();
    final events = _MemoryProductEventStore();
    await tester.pumpWidget(_wrap(app, events));

    await _completeFirstGoal(tester);

    expect(find.text('ถึงเป้าหมายแล้ว! 🎉'), findsOneWidget);
    expect(find.byKey(const Key('celebration-create-goal')), findsOneWidget);
    expect(find.byKey(const Key('celebration-close')), findsOneWidget);
    expect(find.byKey(const Key('celebration-later')), findsOneWidget);

    await tester
        .ensureVisible(find.byKey(const Key('celebration-create-goal')));
    await tester.tap(find.byKey(const Key('celebration-create-goal')));
    await tester.pumpAndSettle();
    expect(find.text('สร้างกระปุกใหม่'), findsOneWidget);
    expect(events.events.single.name, ProductEventName.nextGoalOfferAccepted);
    await app.flushPendingSaves();
  });
}

AppState _readyApp({int unallocatedSatang = 0}) {
  final now = DateTime.utc(2026, 8, 29);
  return AppState()
    ..loaded = true
    ..user = AppUser(name: 'เมย์', exp: 40, onboarded: true)
    ..unallocatedSatang = unallocatedSatang
    ..goals = <Goal>[
      Goal(
        id: 'just-completed',
        name: 'จักรยาน',
        targetSatang: 10000,
        currentSatang: 9000,
        startDate: now,
        targetDate: now.add(const Duration(days: 30)),
        highestMilestonePercent: 75,
      ),
      Goal(
        id: 'next-goal',
        name: 'เที่ยวญี่ปุ่น',
        targetSatang: 50000,
        currentSatang: 20000,
        startDate: now,
        targetDate: now.add(const Duration(days: 60)),
      ),
    ];
}

Widget _wrap(AppState app, ProductEventStore events) {
  return MultiProvider(
    providers: <SingleChildWidget>[
      ChangeNotifierProvider<AppState>.value(value: app),
      Provider<ProductEventStore>.value(value: events),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.3),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AddSavingScreen(
                    presetGoalId: 'just-completed',
                  ),
                ),
              ),
              child: const Text('เปิดหน้าบันทึก'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _completeFirstGoal(WidgetTester tester) async {
  await tester.tap(find.text('เปิดหน้าบันทึก'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '10');
  await tester.pump();
  await tester.tap(find.text('บันทึก'));
  await tester.pumpAndSettle();
}

int _total(AppState app) =>
    app.unallocatedSatang +
    app.goals.fold<int>(0, (sum, goal) => sum + goal.currentSatang);

class _MemoryProductEventStore implements ProductEventStore {
  final List<ProductEventRecord> events = <ProductEventRecord>[];

  @override
  Future<List<ProductEventRecord>> readAll() async => List.unmodifiable(events);

  @override
  Future<void> record(ProductEventRecord event) async {
    events.add(event);
  }
}
