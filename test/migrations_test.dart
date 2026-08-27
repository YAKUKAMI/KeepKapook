import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/state/migrations.dart';

void main() {
  test('ข้อมูลที่ไม่มี schemaVersion ถือเป็น v1 และเติมเลขเวอร์ชันให้', () {
    final raw = <String, dynamic>{
      'user': <String, dynamic>{'name': 'ผู้ใช้เดิม'},
      'goals': <dynamic>[],
    };

    final migrated = migrateState(raw, readSchemaVersion(raw));

    expect(migrated['schemaVersion'], currentSchemaVersion);
    expect(migrated['user'], raw['user']);
    expect(raw, isNot(contains('schemaVersion')));
  });

  test('schemaVersion ใหม่กว่าแอปถูกปฏิเสธ', () {
    const version = currentSchemaVersion + 1;
    final raw = <String, dynamic>{'schemaVersion': version};

    expect(
      () => migrateState(raw, readSchemaVersion(raw)),
      throwsA(isA<UnsupportedSchemaVersionException>()),
    );
  });

  test('schemaVersion ที่ไม่ใช่จำนวนเต็มบวกถือว่า JSON ใช้ไม่ได้', () {
    expect(
      () => readSchemaVersion(<String, dynamic>{'schemaVersion': 'หนึ่ง'}),
      throwsFormatException,
    );
  });

  test('v1 → v2 แปลงเงินบาททุกตำแหน่งเป็นสตางค์แบบปัดครึ่งขึ้น', () {
    final raw = <String, dynamic>{
      'schemaVersion': 1,
      'goals': <dynamic>[
        <String, dynamic>{
          'targetAmount': 1000.005,
          'currentAmount': 12.345,
        },
      ],
      'transactions': <dynamic>[
        <String, dynamic>{'amount': 0.105},
      ],
      'ledger': <dynamic>[
        <String, dynamic>{'amount': 2.675},
      ],
      'unallocated': 1.005,
    };

    final migrated = migrateState(raw, 1);
    final goal = (migrated['goals'] as List).single as Map<String, dynamic>;
    final transaction =
        (migrated['transactions'] as List).single as Map<String, dynamic>;
    final ledger =
        (migrated['ledger'] as List).single as Map<String, dynamic>;

    expect(migrated['schemaVersion'], 2);
    expect(goal['targetSatang'], 100001);
    expect(goal['currentSatang'], 1235);
    expect(goal, isNot(contains('targetAmount')));
    expect(goal, isNot(contains('currentAmount')));
    expect(transaction['amountSatang'], 11);
    expect(transaction, isNot(contains('amount')));
    expect(ledger['amountSatang'], 268);
    expect(ledger, isNot(contains('amount')));
    expect(migrated['unallocatedSatang'], 101);
    expect(migrated, isNot(contains('unallocated')));
  });
}
