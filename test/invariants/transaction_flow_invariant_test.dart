import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/utils/parser/parser.dart';

import 'invariant_test_support.dart';

void main() {
  configureInvariantTestEnvironment();

  test('I13 every TxType has exactly one canonical flow', () {
    const expected = <TxType, TransactionFlow>{
      TxType.deposit: TransactionFlow.externalIn,
      TxType.unallocated: TransactionFlow.externalIn,
      TxType.withdraw: TransactionFlow.externalOut,
      TxType.transfer: TransactionFlow.internal,
      TxType.allocate: TransactionFlow.internal,
      TxType.deallocate: TransactionFlow.internal,
      TxType.adjust: TransactionFlow.adjustment,
      TxType.slip: TransactionFlow.externalIn,
    };

    expect(expected.keys.toSet(), TxType.values.toSet());
    for (final type in TxType.values) {
      expect(transactionFlowForType(type), expected[type], reason: type.name);
    }
  });

  test('I13 SavingTransaction rejects a non-canonical type and flow pair', () {
    expect(
      () => SavingTransaction(
        id: 'invalid',
        type: TxType.transfer,
        flow: TransactionFlow.externalIn,
        amountSatang: 100,
        date: invariantTime,
      ),
      throwsArgumentError,
    );
  });

  test('I13 every transaction-producing AppState action uses canonical flow',
      () {
    final source = invariantGoal(
      id: 'source',
      name: 'ต้นทาง',
      targetSatang: 100000,
      currentSatang: 10000,
    );
    final destination = invariantGoal(
      id: 'destination',
      name: 'ปลายทาง',
      targetSatang: 100000,
    );
    final app = AppState()
      ..goals = <Goal>[source, destination]
      ..unallocatedSatang = 1000;
    final violations = <String>[];

    void runAction(String name, void Function() action) {
      final beforeIds = app.transactions.map((entry) => entry.id).toSet();
      action();
      final created = app.transactions
          .where((entry) => !beforeIds.contains(entry.id))
          .toList();
      if (created.isEmpty) {
        violations.add('$name: did not create a transaction');
        return;
      }
      for (final transaction in created) {
        final expected = transactionFlowForType(transaction.type);
        if (transaction.flow != expected) {
          violations.add(
            '$name: ${transaction.type.name}/${transaction.flow.name} '
            'expected ${expected.name}',
          );
        }
        if (transaction.goalId != null &&
            transaction.sourceGoalNameSnapshot == null) {
          violations.add('$name: missing source goal-name snapshot');
        }
        if (transaction.destinationGoalId != null &&
            transaction.destinationGoalNameSnapshot == null) {
          violations.add('$name: missing destination goal-name snapshot');
        }
      }
    }

    runAction(
      'deposit to goal',
      () => app.addSaving(
        amountSatang: 100,
        goalId: destination.id,
        date: invariantTime,
      ),
    );
    runAction(
      'deposit to unallocated',
      () => app.addSaving(amountSatang: 100, date: invariantTime),
    );
    runAction(
      'slip',
      () => app.addSaving(
        amountSatang: 100,
        goalId: destination.id,
        date: invariantTime,
        source: TxType.slip,
      ),
    );
    runAction(
      'transfer',
      () => app.transfer(source.id, destination.id, 100),
    );
    runAction(
      'allocate',
      () => app.allocateUnallocated(100, destination.id),
    );
    runAction(
      'withdraw to unallocated',
      () => app.withdrawFromGoal(source.id, 100),
    );
    runAction(
      'external withdraw',
      () => app.withdrawFromGoal(
        source.id,
        100,
        toUnallocated: false,
      ),
    );
    runAction(
      'conversational goal deposit',
      () => app.saveParsedEntries(
        <ParsedLedgerItem>[
          ParsedLedgerItem(
            amountSatang: 100,
            type: ParsedEntryType.goalDeposit,
            category: 'เงินออม',
            date: invariantTime,
            description: 'ออม 1 บาท',
            confidence: const FieldConfidence(
              amount: 1,
              type: 1,
              category: 1,
              date: 1,
            ),
          ),
        ],
        goalId: destination.id,
      ),
    );

    expect(violations, isEmpty);
  });
}
