import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/screens/history_screen.dart';
import 'package:keepkapook/screens/ledger_screen.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final at = DateTime.utc(2026, 8, 27);

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget wrap(AppState app, Widget screen) => MaterialApp(
        theme: buildAppTheme(),
        home: ChangeNotifierProvider<AppState>.value(
          value: app,
          child: screen,
        ),
      );

  testWidgets('หน้า ledger แก้ไขและลบรายการย้อนหลังได้', (tester) async {
    final app = AppState()
      ..loaded = true
      ..ledger = <LedgerEntry>[
        LedgerEntry(
          id: 'ledger-1',
          type: LedgerType.expense,
          amountSatang: 6500,
          category: 'อาหาร',
          note: 'กาแฟ',
          date: at,
        ),
      ];
    await tester.pumpWidget(wrap(app, const LedgerScreen()));

    await tester.tap(find.byKey(const ValueKey('ledger-actions-ledger-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('แก้ไข'));
    await tester.pumpAndSettle();
    expect(find.text('แก้ไขรายการ'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '70');
    await tester.tap(find.text('บันทึกการแก้ไข'));
    await tester.pumpAndSettle();
    expect(app.ledger.single.amountSatang, 7000);

    await tester.tap(find.byKey(const ValueKey('ledger-actions-ledger-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบรายการ'));
    await tester.pumpAndSettle();
    expect(app.ledger, isEmpty);
  });

  testWidgets('หน้า history แก้ไขและลบพร้อมปรับยอดกระปุกได้', (tester) async {
    final app = AppState()
      ..loaded = true
      ..goals = <Goal>[
        Goal(
          id: 'goal-1',
          name: 'เที่ยว',
          targetSatang: 100000,
          currentSatang: 5000,
          startDate: at,
          targetDate: at.add(const Duration(days: 90)),
        ),
      ]
      ..transactions = <SavingTransaction>[
        SavingTransaction(
          id: 'tx-1',
          type: TxType.deposit,
          amountSatang: 5000,
          date: at,
          destinationGoalId: 'goal-1',
          note: 'เริ่มออม',
          expAwarded: 10,
        ),
      ];
    await tester.pumpWidget(wrap(app, const HistoryScreen()));

    await tester.tap(find.byKey(const ValueKey('history-actions-tx-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('แก้ไข'));
    await tester.pumpAndSettle();
    expect(find.text('แก้ไขประวัติ'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '40');
    await tester.tap(find.text('บันทึกการแก้ไข'));
    await tester.pumpAndSettle();
    expect(app.goals.single.currentSatang, 4000);

    await tester.tap(find.byKey(const ValueKey('history-actions-tx-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ลบประวัติ'));
    await tester.pumpAndSettle();
    expect(app.transactions, isEmpty);
    expect(app.goals.single.currentSatang, 0);
  });

  testWidgets('รายการโอนเก่าที่ไม่มีปลายทางปิดการแก้ไขพร้อมอธิบายภาษาไทย',
      (tester) async {
    final app = AppState()
      ..loaded = true
      ..goals = <Goal>[
        Goal(
          id: 'source',
          name: 'ต้นทาง',
          targetSatang: 100000,
          currentSatang: 5000,
          startDate: at,
          targetDate: at.add(const Duration(days: 90)),
        ),
      ]
      ..transactions = <SavingTransaction>[
        SavingTransaction(
          id: 'legacy-transfer',
          type: TxType.transfer,
          amountSatang: 1000,
          date: at,
          goalId: 'source',
          note: 'โอนไป กระปุกที่ถูกลบ',
        ),
      ];
    await tester.pumpWidget(wrap(app, const HistoryScreen()));

    await tester.tap(find.text('โอนระหว่างกระปุก'));
    await tester.pump();

    expect(
      find.text(
        'รายการโอนเก่านี้ไม่มีข้อมูลกระปุกปลายทาง จึงแก้ไขหรือลบไม่ได้',
      ),
      findsOneWidget,
    );
    expect(find.text('แก้ไขประวัติ'), findsNothing);
  });
}
