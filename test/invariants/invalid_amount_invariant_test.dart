import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/utils/format.dart';

import 'invariant_test_support.dart';

typedef _AppFactory = AppState Function();
typedef _InvalidAction = void Function(AppState app, Object amount);

final List<({String label, Object value})> _invalidAmounts =
    <({String label, Object value})>[
  (label: 'zero', value: 0),
  (label: 'negative', value: -1),
  (label: 'NaN', value: double.nan),
  (label: 'infinity', value: double.infinity),
  (label: 'over-cap', value: maxMoneyInputSatang + 1),
];

List<String> _invalidAmountViolations({
  required _AppFactory createApp,
  required _InvalidAction invoke,
}) {
  final violations = <String>[];
  for (final invalid in _invalidAmounts) {
    final app = createApp();
    final before = invariantStateJson(app);
    Object? thrown;
    try {
      invoke(app, invalid.value);
    } catch (error) {
      thrown = error;
    }
    final after = invariantStateJson(app);
    if (thrown == null) violations.add('${invalid.label}: did not throw');
    if (after != before) violations.add('${invalid.label}: state changed');
  }
  return violations;
}

void main() {
  configureInvariantTestEnvironment();

  test('I5 addSaving rejects every invalid amount atomically', () {
    final violations = _invalidAmountViolations(
      createApp: () => AppState()
        ..goals = <Goal>[
          invariantGoal(
            id: 'goal',
            name: 'เป้าหมาย',
            targetSatang: maxMoneyInputSatang * 2,
          ),
        ],
      invoke: (app, amount) => (app as dynamic).addSaving(
        amountSatang: amount,
        goalId: 'goal',
        date: invariantTime,
      ),
    );

    expect(violations, isEmpty);
  });

  test('I5 addGoal rejects every invalid amount atomically', () {
    final violations = _invalidAmountViolations(
      createApp: AppState.new,
      invoke: (app, amount) => (app as dynamic).addGoal(
        name: 'เป้าหมาย',
        targetSatang: amount,
        targetDate: invariantTime.add(const Duration(days: 30)),
      ),
    );

    expect(violations, isEmpty);
  });

  test('I5 addLedger rejects every invalid amount atomically', () {
    final violations = _invalidAmountViolations(
      createApp: AppState.new,
      invoke: (app, amount) => (app as dynamic).addLedger(
        LedgerType.expense,
        amount,
        'อาหาร',
        'ทดสอบ invariant',
      ),
    );

    expect(violations, isEmpty);
  });

  test('I5 transfer rejects every invalid amount atomically', () {
    final violations = _invalidAmountViolations(
      createApp: () => AppState()
        ..goals = <Goal>[
          invariantGoal(
            id: 'source',
            name: 'ต้นทาง',
            targetSatang: maxMoneyInputSatang * 2,
            currentSatang: maxMoneyInputSatang + 1000,
          ),
          invariantGoal(
            id: 'destination',
            name: 'ปลายทาง',
            targetSatang: maxMoneyInputSatang * 2,
          ),
        ],
      invoke: (app, amount) =>
          (app as dynamic).transfer('source', 'destination', amount),
    );

    expect(violations, isEmpty);
  });

  test('I5 allocate rejects every invalid amount atomically', () {
    final violations = _invalidAmountViolations(
      createApp: () => AppState()
        ..goals = <Goal>[
          invariantGoal(
            id: 'goal',
            name: 'เป้าหมาย',
            targetSatang: maxMoneyInputSatang * 2,
          ),
        ]
        ..unallocatedSatang = maxMoneyInputSatang + 1000,
      invoke: (app, amount) =>
          (app as dynamic).allocateUnallocated(amount, 'goal'),
    );

    expect(violations, isEmpty);
  });

  test('I5 withdraw rejects every invalid amount atomically', () {
    final violations = _invalidAmountViolations(
      createApp: () => AppState()
        ..goals = <Goal>[
          invariantGoal(
            id: 'goal',
            name: 'เป้าหมาย',
            targetSatang: maxMoneyInputSatang * 2,
            currentSatang: maxMoneyInputSatang + 1000,
          ),
        ],
      invoke: (app, amount) =>
          (app as dynamic).withdrawFromGoal('goal', amount),
    );

    expect(violations, isEmpty);
  });
}
