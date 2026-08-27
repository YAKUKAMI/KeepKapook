import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';

import 'invariant_test_support.dart';

void main() {
  configureInvariantTestEnvironment();

  group('I1 money conservation — internal operation', () {
    test('I1 transfer preserves TOTAL exactly', () {
      final app = AppState()
        ..goals = <Goal>[
          invariantGoal(
            id: 'source',
            name: 'ต้นทาง',
            targetSatang: 100000,
            currentSatang: 70000,
          ),
          invariantGoal(
            id: 'destination',
            name: 'ปลายทาง',
            targetSatang: 100000,
            currentSatang: 10000,
          ),
        ]
        ..unallocatedSatang = 5000;
      final before = invariantTotal(app);

      app.transfer('source', 'destination', 20000);

      expect(invariantTotal(app), before);
    });

    test('I1 allocate preserves TOTAL exactly', () {
      final app = AppState()
        ..goals = <Goal>[
          invariantGoal(
            id: 'goal',
            name: 'เป้าหมาย',
            targetSatang: 100000,
            currentSatang: 10000,
          ),
        ]
        ..unallocatedSatang = 30000;
      final before = invariantTotal(app);

      app.allocateUnallocated(12000, 'goal');

      expect(invariantTotal(app), before);
    });

    test('I1 withdraw to unallocated preserves TOTAL exactly', () {
      final app = AppState()
        ..goals = <Goal>[
          invariantGoal(
            id: 'goal',
            name: 'เป้าหมาย',
            targetSatang: 100000,
            currentSatang: 50000,
          ),
        ]
        ..unallocatedSatang = 7000;
      final before = invariantTotal(app);

      app.withdrawFromGoal('goal', 9000);

      expect(invariantTotal(app), before);
    });
  });

  test('I2 external inflow increases TOTAL by exactly X', () {
    const amountSatang = 12345;
    final app = AppState()
      ..goals = <Goal>[
        invariantGoal(
          id: 'goal',
          name: 'เป้าหมาย',
          targetSatang: 100000,
          currentSatang: 5000,
        ),
      ]
      ..unallocatedSatang = 3000;
    final before = invariantTotal(app);

    app.addSaving(
      amountSatang: amountSatang,
      goalId: 'goal',
      date: invariantTime,
    );

    expect(invariantTotal(app), before + amountSatang);
  });

  test('I3 flexible pocket accepts unlimited deposit without overflow', () {
    const amountSatang = 250000;
    const beforeUnallocatedSatang = 700;
    final pocket = invariantGoal(
      id: 'pocket',
      name: 'กระเป๋ายืดหยุ่น',
      targetSatang: 0,
      currentSatang: 1500,
      flexible: true,
    );
    final app = AppState()
      ..goals = <Goal>[pocket]
      ..unallocatedSatang = beforeUnallocatedSatang;

    app.addSaving(
      amountSatang: amountSatang,
      goalId: pocket.id,
      date: invariantTime,
    );

    expect(
      <String, int>{
        'pocket': pocket.currentSatang,
        'unallocated': app.unallocatedSatang,
      },
      <String, int>{
        'pocket': 1500 + amountSatang,
        'unallocated': beforeUnallocatedSatang,
      },
    );
  });

  test('I4 normal goal overflow goes to unallocated', () {
    const depositSatang = 500;
    final goal = invariantGoal(
      id: 'goal',
      name: 'เป้าหมายปกติ',
      targetSatang: 1000,
      currentSatang: 700,
    );
    final app = AppState()
      ..goals = <Goal>[goal]
      ..unallocatedSatang = 50;

    app.addSaving(
      amountSatang: depositSatang,
      goalId: goal.id,
      date: invariantTime,
    );

    expect(goal.currentSatang, 1000);
    expect(app.unallocatedSatang, 250);
  });
}
