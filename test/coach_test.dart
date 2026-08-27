import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/utils/coach.dart';

void main() {
  test('planStatus คำนวณยอดตามแผนเป็นสตางค์แบบจำนวนเต็ม', () {
    final now = DateTime.now();
    final goal = Goal(
      id: 'goal',
      name: 'Goal',
      targetSatang: 1001,
      currentSatang: 500,
      startDate: now.subtract(const Duration(days: 10)),
      targetDate: now.add(const Duration(days: 10)),
    );

    final status = planStatus(goal);

    expect(status.behind, isTrue);
    expect(status.shortfallSatang, 1);
    expect(status.onTrackPct, 100);
  });

  test('ค่าเฉลี่ยเงินออมต่อวันปัดครึ่งขึ้นโดยไม่รวมยอดถอนและปรับยอด', () {
    final now = DateTime.now();
    final transactions = <SavingTransaction>[
      SavingTransaction(
        id: 'deposit',
        type: TxType.deposit,
        amountSatang: 101,
        date: now,
      ),
      SavingTransaction(
        id: 'withdraw',
        type: TxType.withdraw,
        amountSatang: 999,
        date: now,
      ),
      SavingTransaction(
        id: 'adjust',
        type: TxType.adjust,
        amountSatang: 999,
        date: now,
      ),
    ];

    expect(
      averageDepositPerDaySatang(
        transactions,
        now.subtract(const Duration(days: 2)),
        now: now,
      ),
      51,
    );
  });

  test('recoveryOptions คืนยอดรายวันและเป้าหมายใหม่เป็นสตางค์', () {
    final now = DateTime.now();
    final goal = Goal(
      id: 'goal',
      name: 'Goal',
      targetSatang: 1000,
      currentSatang: 100,
      startDate: now.subtract(const Duration(days: 10)),
      targetDate: now.add(const Duration(days: 10)),
    );

    final options = recoveryOptions(goal, PlanStatus(true, 101, 50), 50);

    expect(options.catchUpPerDaySatang, 15);
    expect(options.catchUpDays, 7);
    expect(options.extendDays, 8);
    expect(options.reducedTargetSatang, 600);
  });
}
