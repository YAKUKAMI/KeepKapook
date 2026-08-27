import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';

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
      ..unallocatedSatang = 3000;
    final beforeExp = app.user.exp;

    app.allocateUnallocated(1000, 'goal');

    expect(app.user.exp, beforeExp);
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

  test(
    'I7 seven-day graph counts only external inflow',
    () {
      fail('Unskip after the chart calculation accepts an injected clock.');
    },
    skip: 'Blocked: seven-day totals are private UI logic in _Chart and read '
        'the wall clock directly; there is no injectable clock or public pure '
        'function to test without changing production code.',
  );
}
