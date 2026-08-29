import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/state/migrations.dart';
import 'package:keepkapook/utils/local_metrics.dart';

void main() {
  test('v5 → v6 สร้าง local metrics จากวันและตัวนับโดยไม่เก็บยอดเงิน', () {
    final raw = <String, dynamic>{
      'schemaVersion': 5,
      'user': <String, dynamic>{'exp': 50},
      'goals': <dynamic>[
        <String, dynamic>{
          'id': 'goal',
          'name': 'เป้าหมาย',
          'targetSatang': 100000,
          'currentSatang': 10000,
          'startDate': '2026-01-01T00:00:00.000Z',
          'targetDate': '2026-12-01T00:00:00.000Z',
        },
      ],
      'transactions': <dynamic>[
        <String, dynamic>{
          'id': 'saving',
          'type': 'deposit',
          'flow': 'externalIn',
          'amountSatang': 10000,
          'date': '2026-01-02T00:00:00.000Z',
          'destinationGoalId': 'goal',
        },
        <String, dynamic>{
          'id': 'transfer',
          'type': 'transfer',
          'flow': 'internal',
          'amountSatang': 5000,
          'date': '2026-01-03T00:00:00.000Z',
        },
      ],
      'ledger': <dynamic>[
        <String, dynamic>{
          'id': 'expense',
          'type': 'expense',
          'amountSatang': 5000,
          'date': '2026-01-04T00:00:00.000Z',
        },
        <String, dynamic>{
          'id': 'income',
          'type': 'income',
          'amountSatang': 20000,
          'date': '2026-01-05T00:00:00.000Z',
        },
      ],
      'unallocatedSatang': 0,
    };

    final migrated = migrateState(raw, 5);
    final metrics = LocalMetrics.fromJson(
      Map<String, dynamic>.from(migrated['metrics'] as Map),
    );

    expect(migrated['schemaVersion'], 6);
    expect(metrics.installedDay, '2026-01-01');
    expect(
      metrics.recordingDays,
      <String>{'2026-01-02', '2026-01-04', '2026-01-05'},
    );
    expect(metrics.savingRecordCount, 1);
    expect(metrics.expenseRecordCount, 1);
    expect(metrics.undoCount, 0);
    expect(metrics.parserCorpus, isEmpty);
    expect(_allKeys(metrics.toJson()), isNot(contains('amountSatang')));
  });
}

Set<String> _allKeys(Object? value) {
  final keys = <String>{};
  if (value is Map) {
    for (final entry in value.entries) {
      keys.add(entry.key.toString());
      keys.addAll(_allKeys(entry.value));
    }
  } else if (value is List) {
    for (final entry in value) {
      keys.addAll(_allKeys(entry));
    }
  }
  return keys;
}
