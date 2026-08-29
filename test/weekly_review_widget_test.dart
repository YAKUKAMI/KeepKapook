import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/screens/dashboard_screen.dart';
import 'package:keepkapook/screens/weekly_review_screen.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 8, 19, 12);

AppState _app({bool withReportData = true}) {
  final app = AppState()
    ..loaded = true
    ..user = AppUser(name: 'เมย์', onboarded: true)
    ..goals = <Goal>[
      Goal(
        id: 'goal',
        name: 'iPhone มือสอง',
        targetSatang: 1500000,
        currentSatang: 500000,
        startDate: DateTime(2026, 8, 5),
        targetDate: DateTime(2026, 12, 31),
      ),
    ]
    ..quests = <Quest>[
      Quest(
        id: 'q-weekly-review',
        title: 'ทบทวนสัปดาห์',
        description: 'เปิดดูสรุปสัปดาห์ล่าสุด',
        period: 'weekly',
        target: 1,
        expReward: 25,
      ),
    ];
  if (!withReportData) return app;
  app
    ..ledger = <LedgerEntry>[
      LedgerEntry(
        id: 'previous-1',
        type: LedgerType.expense,
        amountSatang: 90000,
        category: 'อาหาร',
        date: DateTime.utc(2026, 8, 3, 2),
      ),
      LedgerEntry(
        id: 'previous-2',
        type: LedgerType.expense,
        amountSatang: 100000,
        category: 'เดินทาง',
        date: DateTime.utc(2026, 8, 4, 2),
      ),
      LedgerEntry(
        id: 'current-1',
        type: LedgerType.expense,
        amountSatang: 110000,
        category: 'อาหาร',
        date: DateTime.utc(2026, 8, 10, 2),
      ),
      LedgerEntry(
        id: 'current-2',
        type: LedgerType.expense,
        amountSatang: 104000,
        category: 'อาหาร',
        date: DateTime.utc(2026, 8, 11, 2),
      ),
    ]
    ..transactions = <SavingTransaction>[
      SavingTransaction(
        id: 'saving-1',
        type: TxType.deposit,
        amountSatang: 40000,
        date: DateTime.utc(2026, 8, 12, 2),
        destinationGoalId: 'goal',
        destinationGoalNameSnapshot: 'iPhone มือสอง',
      ),
      SavingTransaction(
        id: 'saving-2',
        type: TxType.deposit,
        amountSatang: 35000,
        date: DateTime.utc(2026, 8, 13, 2),
        destinationGoalId: 'goal',
        destinationGoalNameSnapshot: 'iPhone มือสอง',
      ),
    ];
  return app;
}

Widget _host(AppState app, Widget child) =>
    ChangeNotifierProvider<AppState>.value(
      value: app,
      child: MaterialApp(theme: buildAppTheme(), home: child),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('dashboard shows weekly review without changing tabs',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = _app();

    await tester.pumpWidget(
      _host(app, Scaffold(body: DashboardScreen(now: _now))),
    );

    expect(find.byKey(const Key('weekly-review-launcher')), findsOneWidget);
    expect(find.text('สรุปสัปดาห์พร้อมแล้ว'), findsOneWidget);
    await tester.tap(find.byKey(const Key('weekly-review-launcher')));
    await tester.pumpAndSettle();
    expect(find.text('สรุป 7 วันแรก'), findsOneWidget);
    await app.flushPendingSaves();
  });

  testWidgets('opening review shows history and progresses q-weekly-review',
      (tester) async {
    final app = _app();
    await tester.pumpWidget(_host(app, WeeklyReviewScreen(now: _now)));
    await tester.pump();

    expect(find.text('สรุป 7 วันแรก'), findsOneWidget);
    expect(find.text('สรุปสัปดาห์'), findsWidgets);
    expect(
      find.text(
        'สรุปนี้คำนวณจากรายการที่คุณบันทึก ไม่ใช่ยอดเงินจริงจากธนาคาร',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('จะถึงเร็วขึ้น'), findsOneWidget);
    expect(find.textContaining('เงินคงเหลือ'), findsNothing);
    expect(app.quests.single.progress, 1);
    await app.flushPendingSaves();
  });

  testWidgets('insufficient data never renders the expense-to-goal link',
      (tester) async {
    final app = _app(withReportData: false);
    await tester.pumpWidget(_host(app, WeeklyReviewScreen(now: _now)));
    await tester.pump();

    expect(find.textContaining('ยังมีข้อมูลไม่พอ'), findsOneWidget);
    expect(find.byIcon(Icons.route_outlined), findsNothing);
    await app.flushPendingSaves();
  });
}
