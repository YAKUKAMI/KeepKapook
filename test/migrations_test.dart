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

  test('v1 → v3 แปลงเงินบาทและ migrate transaction ต่อขั้น', () {
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
    final ledger = (migrated['ledger'] as List).single as Map<String, dynamic>;

    expect(migrated['schemaVersion'], currentSchemaVersion);
    expect(goal['targetSatang'], 100001);
    expect(goal['currentSatang'], 1235);
    expect(goal, isNot(contains('targetAmount')));
    expect(goal, isNot(contains('currentAmount')));
    expect(transaction['amountSatang'], 11);
    expect(transaction['flow'], 'externalIn');
    expect(transaction['destinationGoalId'], isNull);
    expect(transaction, isNot(contains('amount')));
    expect(ledger['amountSatang'], 268);
    expect(ledger, isNot(contains('amount')));
    expect(migrated['unallocatedSatang'], 101);
    expect(migrated, isNot(contains('unallocated')));
  });

  test('v2 → v3 กู้ transfer เฉพาะชื่อปลายทางที่ตรงหนึ่งเดียวและคง note เดิม',
      () {
    final raw = <String, dynamic>{
      'schemaVersion': 2,
      'goals': <dynamic>[
        _v2Goal('source', 'ต้นทาง'),
        _v2Goal('unique', 'ปลายทางเดียว'),
        _v2Goal('duplicate-1', 'ชื่อซ้ำ'),
        _v2Goal('duplicate-2', 'ชื่อซ้ำ'),
      ],
      'transactions': <dynamic>[
        _v2Transfer('unique-match', 'โอนไป ปลายทางเดียว'),
        _v2Transfer('duplicate-name', 'โอนไป ชื่อซ้ำ'),
        _v2Transfer('not-found', 'โอนไป ไม่มีชื่อนี้'),
        _v2Transfer('deleted-goal', 'โอนไป กระปุกที่ถูกลบ'),
      ],
    };

    final migrated = migrateState(raw, 2);
    final transactions = (migrated['transactions'] as List)
        .cast<Map<String, dynamic>>()
        .toList();
    Map<String, dynamic> transaction(String id) =>
        transactions.singleWhere((entry) => entry['id'] == id);

    expect(migrated['schemaVersion'], 3);
    expect(transaction('unique-match')['destinationGoalId'], 'unique');
    expect(transaction('duplicate-name')['destinationGoalId'], isNull);
    expect(transaction('not-found')['destinationGoalId'], isNull);
    expect(transaction('deleted-goal')['destinationGoalId'], isNull);
    expect(
      transactions.where((entry) => entry['destinationGoalId'] != null),
      hasLength(1),
    );
    for (final entry in transactions) {
      expect(entry['goalId'], 'source');
      expect(entry['flow'], 'internal');
      expect(entry['note'], rawNoteFor(entry['id'] as String));
    }
  });

  test('v2 → v3 map flow และ source/destination จาก TxType ทุกชนิด', () {
    final raw = <String, dynamic>{
      'schemaVersion': 2,
      'goals': <dynamic>[
        _v2Goal('source', 'ต้นทาง'),
        _v2Goal('destination', 'ปลายทาง'),
      ],
      'transactions': <dynamic>[
        _v2Transaction('deposit', 'deposit', goalId: 'destination'),
        _v2Transaction('unallocated', 'unallocated'),
        _v2Transaction('withdraw', 'withdraw', goalId: 'source'),
        _v2Transaction(
          'transfer',
          'transfer',
          goalId: 'source',
          note: 'โอนไป ปลายทาง',
        ),
        _v2Transaction('adjust', 'adjust', goalId: 'destination'),
        _v2Transaction('slip', 'slip', goalId: 'destination'),
      ],
    };

    final migrated = migrateState(raw, 2);
    final entries = <String, Map<String, dynamic>>{
      for (final entry in (migrated['transactions'] as List))
        (entry as Map<String, dynamic>)['id'] as String: entry,
    };

    expect(entries['deposit']!['flow'], 'externalIn');
    expect(entries['deposit']!['goalId'], isNull);
    expect(entries['deposit']!['destinationGoalId'], 'destination');
    expect(entries['unallocated']!['flow'], 'externalIn');
    expect(entries['withdraw']!['flow'], 'externalOut');
    expect(entries['withdraw']!['goalId'], 'source');
    expect(entries['transfer']!['flow'], 'internal');
    expect(entries['transfer']!['destinationGoalId'], 'destination');
    expect(entries['adjust']!['flow'], 'adjustment');
    expect(entries['adjust']!['goalId'], isNull);
    expect(entries['adjust']!['destinationGoalId'], 'destination');
    expect(entries['slip']!['flow'], 'externalIn');
    expect(entries['slip']!['destinationGoalId'], 'destination');
  });
}

Map<String, dynamic> _v2Goal(String id, String name) => <String, dynamic>{
      'id': id,
      'name': name,
      'targetSatang': 100000,
      'currentSatang': 0,
      'startDate': '2026-01-01T00:00:00.000Z',
      'targetDate': '2026-12-31T00:00:00.000Z',
    };

Map<String, dynamic> _v2Transfer(String id, String note) =>
    _v2Transaction(id, 'transfer', goalId: 'source', note: note);

Map<String, dynamic> _v2Transaction(
  String id,
  String type, {
  String? goalId,
  String note = '',
}) =>
    <String, dynamic>{
      'id': id,
      'type': type,
      'amountSatang': 1000,
      'date': '2026-08-27T00:00:00.000Z',
      'goalId': goalId,
      'note': note,
      'expAwarded': 0,
      'isPossibleDuplicate': false,
    };

String rawNoteFor(String id) => switch (id) {
      'unique-match' => 'โอนไป ปลายทางเดียว',
      'duplicate-name' => 'โอนไป ชื่อซ้ำ',
      'not-found' => 'โอนไป ไม่มีชื่อนี้',
      'deleted-goal' => 'โอนไป กระปุกที่ถูกลบ',
      _ => throw ArgumentError.value(id, 'id'),
    };
