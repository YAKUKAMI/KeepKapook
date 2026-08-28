import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/state/backup.dart';
import 'package:keepkapook/state/migrations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('export มีตัวระบุ schemaVersion เวลา export เวอร์ชันแอป และชื่อไฟล์',
      () {
    final exportedAt = DateTime.utc(2026, 8, 24, 10, 30);
    final state = _stateV2(userName: 'กัปตัน');
    final raw = createBackupJson(
      state: state,
      exportedAt: exportedAt,
      appVersion: '0.1.0+1',
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    expect(decoded['backupFormat'], keepKapookBackupFormat);
    expect(decoded['schemaVersion'], currentSchemaVersion);
    expect(decoded['exportedAt'], '2026-08-24T10:30:00.000Z');
    expect(decoded['appVersion'], '0.1.0+1');
    expect(decoded['user'], isA<Map<String, dynamic>>());
    for (final entry in state.entries) {
      expect(decoded[entry.key], entry.value);
    }
    expect(backupFileName(exportedAt), 'keepkapook-backup-20260824.json');
  });

  test('validate สร้าง preview หลัง migrate v1 พร้อมยอดและจำนวนที่ถูกต้อง', () {
    final raw = jsonEncode(<String, dynamic>{
      'backupFormat': keepKapookBackupFormat,
      'exportedAt': '2026-08-24T10:30:00.000Z',
      'appVersion': '0.0.9+8',
      'schemaVersion': 1,
      'user': <String, dynamic>{'name': 'ผู้ใช้เดิม'},
      'goals': <dynamic>[
        <String, dynamic>{
          'id': 'goal-old',
          'name': 'กระปุกเดิม',
          'targetAmount': 1000,
          'currentAmount': 12.345,
          'startDate': '2026-01-01T00:00:00.000Z',
          'targetDate': '2026-12-31T00:00:00.000Z',
        },
      ],
      'transactions': <dynamic>[
        <String, dynamic>{
          'id': 'tx-old',
          'type': 'deposit',
          'amount': 12.345,
          'date': '2026-01-02T00:00:00.000Z',
        },
      ],
      'quests': <dynamic>[],
      'badges': <dynamic>[],
      'ledger': <dynamic>[
        <String, dynamic>{
          'id': 'ledger-old',
          'type': 'income',
          'amount': 20,
          'date': '2026-01-02T00:00:00.000Z',
        },
      ],
      'unallocated': 1.005,
    });

    final preview = validateBackupJson(raw);

    expect(preview.schemaVersion, currentSchemaVersion);
    expect(preview.goalCount, 1);
    expect(preview.savingTransactionCount, 1);
    expect(preview.ledgerEntryCount, 1);
    expect(preview.totalItemCount, 2);
    expect(preview.totalSavedSatang, 1235);
    expect(preview.unallocatedSatang, 101);
    expect(preview.exportedAt, DateTime.utc(2026, 8, 24, 10, 30));
    expect(preview.appVersion, '0.0.9+8');
    expect(preview.migratedState['schemaVersion'], currentSchemaVersion);
  });

  test('ไฟล์ JSON พังถูกปฏิเสธด้วยข้อความภาษาไทย', () {
    expect(
      () => validateBackupJson('{พัง'),
      throwsA(
        isA<BackupValidationException>()
            .having(
              (error) => error.reason,
              'reason',
              BackupValidationReason.malformedJson,
            )
            .having(
                (error) => error.userMessage, 'message', contains('อ่านไฟล์')),
      ),
    );
  });

  test('JSON ที่ไม่ใช่ไฟล์ KeepKapook ถูกปฏิเสธ', () {
    expect(
      () => validateBackupJson(jsonEncode(_stateV2(userName: 'อื่น'))),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.reason,
          'reason',
          BackupValidationReason.notKeepKapookBackup,
        ),
      ),
    );
  });

  test('backup ที่ schemaVersion ใหม่กว่าแอปถูกปฏิเสธ', () {
    final state = _stateV2(userName: 'อนาคต')
      ..['schemaVersion'] = currentSchemaVersion + 1;
    final raw = createBackupJson(
      state: state,
      exportedAt: DateTime.utc(2026, 8, 24),
      appVersion: '9.0.0+1',
    );

    expect(
      () => validateBackupJson(raw),
      throwsA(
        isA<BackupValidationException>()
            .having(
              (error) => error.reason,
              'reason',
              BackupValidationReason.newerSchema,
            )
            .having(
              (error) => error.userMessage,
              'message',
              contains('เวอร์ชันใหม่กว่า'),
            ),
      ),
    );
  });

  test('backup ที่โครงสร้างข้อมูลไม่ถูกต้องถูกปฏิเสธ', () {
    final state = _stateV2(userName: 'ข้อมูลพัง')..['goals'] = 'ไม่ใช่รายการ';
    final raw = createBackupJson(
      state: state,
      exportedAt: DateTime.utc(2026, 8, 24),
      appVersion: '0.1.0+1',
    );

    expect(
      () => validateBackupJson(raw),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.reason,
          'reason',
          BackupValidationReason.invalidData,
        ),
      ),
    );
  });

  test('backup ที่ metadata ไม่ครบถูกปฏิเสธ', () {
    final raw = jsonEncode(<String, dynamic>{
      ..._stateV2(userName: 'metadata หาย'),
      'backupFormat': keepKapookBackupFormat,
      'appVersion': '0.1.0+1',
    });

    expect(
      () => validateBackupJson(raw),
      throwsA(
        isA<BackupValidationException>().having(
          (error) => error.reason,
          'reason',
          BackupValidationReason.invalidData,
        ),
      ),
    );
  });

  test('restore สำรอง state ปัจจุบันก่อนเขียนทับและบันทึกแบบ canonical',
      () async {
    final app = AppState();
    app.user.name = 'ข้อมูลปัจจุบัน';
    final currentRaw = jsonEncode(app.toJson());
    SharedPreferences.setMockInitialValues(<String, Object>{
      appStateStorageKey: currentRaw,
    });
    final importedState = _stateV2(userName: 'ข้อมูลจากไฟล์');
    final preview = validateBackupJson(createBackupJson(
      state: importedState,
      exportedAt: DateTime.utc(2026, 8, 24),
      appVersion: '0.1.0+1',
    ));

    await app.restoreBackup(preview);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(appStatePreImportBackupKey), currentRaw);
    expect(app.user.name, 'ข้อมูลจากไฟล์');
    final persisted = jsonDecode(prefs.getString(appStateStorageKey)!)
        as Map<String, dynamic>;
    expect(persisted['user']['name'], 'ข้อมูลจากไฟล์');
    expect(persisted, isNot(contains('backupFormat')));
  });
}

Map<String, dynamic> _stateV2({required String userName}) => <String, dynamic>{
      'schemaVersion': currentSchemaVersion,
      'user': <String, dynamic>{
        'name': userName,
        'emoji': '🐷',
        'exp': 0,
        'consistencyWeeks': 0,
        'mode': 'adult',
        'onboarded': true,
      },
      'goals': <dynamic>[],
      'transactions': <dynamic>[],
      'quests': <dynamic>[],
      'badges': <dynamic>[],
      'ledger': <dynamic>[],
      'unallocatedSatang': 0,
    };
