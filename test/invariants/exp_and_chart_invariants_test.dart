import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/utils/financial_summary.dart';

import 'invariant_test_support.dart';

void main() {
  configureInvariantTestEnvironment();

  test('I6 transfer does not award EXP', () {
    final app = AppState()
      ..user = AppUser(exp: 31)
      ..goals = <Goal>[
        invariantGoal(
          id: 'source',
          name: 'ต้นทาง',
          targetSatang: 10000,
          currentSatang: 5000,
        ),
        invariantGoal(
          id: 'destination',
          name: 'ปลายทาง',
          targetSatang: 10000,
        ),
      ];
    final beforeExp = app.user.exp;

    app.transfer('source', 'destination', 2000);

    expect(app.user.exp, beforeExp);
  });

  test('I6 allocate does not award EXP', () {
    final app = AppState()
      ..user = AppUser(exp: 31)
      ..goals = <Goal>[
        invariantGoal(
          id: 'goal',
          name: 'เป้าหมาย',
          targetSatang: 10000,
        ),
      ]
      ..quests = <Quest>[
        Quest(
          id: 'q-allocate',
          title: 'จัดสรรเงิน',
          description: 'จัดสรรเงินที่ยังไม่เลือกเป้าหมาย',
          period: 'daily',
          target: 1,
          expReward: 15,
        ),
      ]
      ..unallocatedSatang = 3000;
    final beforeExp = app.user.exp;

    app.allocateUnallocated(1000, 'goal');

    expect(
      <String, int>{
        'exp': app.user.exp,
        'questProgress': app.quests.single.progress,
      },
      <String, int>{
        'exp': beforeExp,
        'questProgress': 1,
      },
    );
  });

  test('I6 milestone EXP does not fire again after money leaves and returns',
      () {
    final goal = invariantGoal(
      id: 'goal',
      name: 'เป้าหมาย',
      targetSatang: 10000,
      currentSatang: 2400,
    );
    final app = AppState()
      ..user = AppUser(exp: 0)
      ..goals = <Goal>[goal];

    app.addSaving(
      amountSatang: 200,
      goalId: goal.id,
      date: invariantTime,
    );
    final afterFirstMilestone = app.user.exp;
    expect(afterFirstMilestone, 30);

    app.withdrawFromGoal(goal.id, 200);
    app.allocateUnallocated(200, goal.id);

    expect(goal.currentSatang, 2600);
    expect(app.user.exp, afterFirstMilestone);
  });

  test('I6 external inflow earns EXP once before later allocation', () {
    final app = AppState()
      ..user = AppUser(exp: 31)
      ..goals = <Goal>[
        invariantGoal(
          id: 'goal',
          name: 'เป้าหมาย',
          targetSatang: 10000,
        ),
      ];
    final beforeExp = app.user.exp;

    app.addSaving(amountSatang: 1000, date: invariantTime);
    final afterExternalInflowExp = app.user.exp;
    app.allocateUnallocated(1000, 'goal');
    final afterAllocationExp = app.user.exp;

    expect(
      <String, bool>{
        'external inflow awarded EXP': afterExternalInflowExp > beforeExp,
        'allocation preserved EXP':
            afterAllocationExp == afterExternalInflowExp,
      },
      <String, bool>{
        'external inflow awarded EXP': true,
        'allocation preserved EXP': true,
      },
    );
  });

  test('I7 seven-day graph counts only external inflow', () {
    final externalDeposit = SavingTransaction(
      id: 'external',
      type: TxType.deposit,
      amountSatang: 500,
      date: invariantTime,
      destinationGoalId: 'destination',
    );
    final internalTransfer = SavingTransaction(
      id: 'transfer',
      type: TxType.transfer,
      amountSatang: 2000,
      date: invariantTime,
      goalId: 'source',
      destinationGoalId: 'destination',
    );

    final beforeTransfer = summarizeSevenDaySavings(
      <SavingTransaction>[externalDeposit],
      now: invariantTime,
    ).map((day) => day.totalSatang).toList();
    final afterTransfer = summarizeSevenDaySavings(
      <SavingTransaction>[externalDeposit, internalTransfer],
      now: invariantTime,
    ).map((day) => day.totalSatang).toList();

    expect(afterTransfer, beforeTransfer);
  });
}
