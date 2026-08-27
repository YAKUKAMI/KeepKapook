import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final at = DateTime.utc(2026, 8, 24);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('โอนไปกลับหลายรอบแล้วยอดรวมและยอดแต่ละกระปุกไม่เปลี่ยน', () {
    final app = AppState()
      ..goals = <Goal>[
        Goal(
          id: 'a',
          name: 'A',
          targetSatang: 0,
          currentSatang: 10000,
          startDate: at,
          targetDate: at,
          flexible: true,
        ),
        Goal(
          id: 'b',
          name: 'B',
          targetSatang: 0,
          startDate: at,
          targetDate: at,
          flexible: true,
        ),
      ];
    final before = app.totalSavedSatang;

    for (var i = 0; i < 100; i++) {
      final amountSatang = (i % 7) + 1;
      app.transfer('a', 'b', amountSatang);
      app.transfer('b', 'a', amountSatang);
    }

    expect(app.totalSavedSatang, before);
    expect(app.goals[0].currentSatang, 10000);
    expect(app.goals[1].currentSatang, 0);
  });

  test('overflow หนึ่งสตางค์เข้ายอดยังไม่จัดสรรโดยยอดไม่เพี้ยน', () {
    final app = AppState()
      ..goals = <Goal>[
        Goal(
          id: 'goal',
          name: 'Goal',
          targetSatang: 100,
          currentSatang: 99,
          startDate: at,
          targetDate: at,
        ),
      ]
      ..unallocatedSatang = 0;

    final result = app.addSaving(
      amountSatang: 2,
      goalId: 'goal',
      date: at,
    );

    expect(result.overflowSatang, 1);
    expect(app.goals.single.currentSatang, 100);
    expect(app.unallocatedSatang, 1);
  });

  test('AppState ปฏิเสธยอดออมศูนย์และค่าติดลบโดยไม่แก้ state', () {
    final app = AppState()..unallocatedSatang = 10;

    expect(
      () => app.addSaving(amountSatang: 0, date: at),
      throwsA(isA<DomainValidationException>()),
    );
    expect(
      () => app.addSaving(amountSatang: -1, date: at),
      throwsA(isA<DomainValidationException>()),
    );

    expect(app.unallocatedSatang, 10);
    expect(app.transactions, isEmpty);
  });

  test('AppState ปฏิเสธยอดออมที่เกินเพดานโดยไม่แก้ state', () {
    final app = AppState();

    expect(
      () => app.addSaving(
        amountSatang: 10000000001,
        date: at,
      ),
      throwsA(isA<DomainValidationException>()),
    );

    expect(app.transactions, isEmpty);
    expect(app.unallocatedSatang, 0);
  });

  test('แก้และลบประวัติเงินออมปรับยอดกระปุกโดยไม่หัก EXP', () {
    final app = AppState()
      ..user.exp = 25
      ..goals = <Goal>[
        Goal(
          id: 'goal',
          name: 'Goal',
          targetSatang: 100000,
          currentSatang: 50000,
          startDate: at,
          targetDate: at,
        ),
      ]
      ..transactions = <SavingTransaction>[
        SavingTransaction(
          id: 'tx',
          type: TxType.deposit,
          amountSatang: 50000,
          date: at,
          destinationGoalId: 'goal',
          expAwarded: 25,
        ),
      ];

    final edited = app.updateSavingTransaction(
      id: 'tx',
      amountSatang: 40000,
      note: 'แก้ยอด',
      date: at.add(const Duration(days: 1)),
    );

    expect(edited.success, isTrue);
    expect(app.goals.single.currentSatang, 40000);
    expect(app.transactions.single.amountSatang, 40000);
    expect(app.user.exp, 25);

    final deleted = app.deleteSavingTransaction('tx');
    expect(deleted.success, isTrue);
    expect(app.goals.single.currentSatang, 0);
    expect(app.transactions, isEmpty);
    expect(app.user.exp, 25);
  });

  test('แก้และลบ ledger ผ่าน AppState', () {
    final app = AppState()
      ..ledger = <LedgerEntry>[
        LedgerEntry(
          id: 'ledger',
          type: LedgerType.expense,
          amountSatang: 6500,
          category: 'อาหาร',
          note: 'กาแฟ',
          date: at,
        ),
      ];

    final updated = app.updateLedgerEntry(
      id: 'ledger',
      type: LedgerType.income,
      amountSatang: 7000,
      category: 'ของขวัญ',
      note: 'ได้เงินคืน',
      date: at.add(const Duration(days: 1)),
    );

    expect(updated, isTrue);
    expect(app.ledger.single.type, LedgerType.income);
    expect(app.ledger.single.amountSatang, 7000);
    expect(app.ledger.single.category, 'ของขวัญ');

    app.deleteLedger('ledger');
    expect(app.ledger, isEmpty);
  });

  test('ยอดเดือนปัจจุบันเทียบเดือนตามเวลาท้องถิ่นของผู้ใช้', () {
    final localNow = DateTime.now();
    final firstDayLocal = DateTime(localNow.year, localNow.month);
    final app = AppState()
      ..ledger = <LedgerEntry>[
        LedgerEntry(
          id: 'local-month',
          type: LedgerType.income,
          amountSatang: 100,
          category: 'อื่น ๆ',
          date: firstDayLocal.toUtc(),
        ),
      ];

    expect(app.monthIncomeSatang, 100);
  });
}
