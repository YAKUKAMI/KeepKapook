import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keepkapook/main.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/state/migrations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('state ที่ persist ใหม่มี schemaVersion', () {
    expect(AppState().toJson()['schemaVersion'], currentSchemaVersion);
  });

  test('ข้อมูล v1 ที่ไม่มี schemaVersion โหลดได้ ยอดตรง และถูกเขียนเป็น v5',
      () async {
    final oldJson = jsonEncode(<String, dynamic>{
      'user': <String, dynamic>{'name': 'ผู้ใช้เดิม'},
      'goals': <dynamic>[
        <String, dynamic>{
          'id': 'goal-old',
          'name': 'กระปุกเดิม',
          'targetAmount': 1000.005,
          'currentAmount': 12.345,
          'startDate': '2026-01-01T00:00:00.000',
          'targetDate': '2026-12-31T00:00:00.000',
        },
      ],
      'transactions': <dynamic>[
        <String, dynamic>{
          'id': 'tx-old',
          'type': 'deposit',
          'amount': 0.105,
          'date': '2026-01-02T00:00:00.000',
          'goalId': 'goal-old',
        },
      ],
      'ledger': <dynamic>[
        <String, dynamic>{
          'id': 'ledger-old',
          'type': 'income',
          'amount': 2.675,
          'date': '2026-01-02T00:00:00.000',
        },
      ],
      'unallocated': 1.005,
    });
    SharedPreferences.setMockInitialValues(<String, Object>{
      appStateStorageKey: oldJson,
    });

    final app = AppState();
    await app.load();

    expect(app.user.name, 'ผู้ใช้เดิม');
    expect(app.goals.single.name, 'กระปุกเดิม');
    expect(app.goals.single.targetSatang, 100001);
    expect(app.goals.single.currentSatang, 1235);
    expect(app.totalSavedSatang, 1235);
    expect(app.transactions.single.amountSatang, 11);
    expect(app.transactions.single.flow, TransactionFlow.externalIn);
    expect(app.transactions.single.goalId, isNull);
    expect(app.transactions.single.destinationGoalId, 'goal-old');
    expect(app.ledger.single.amountSatang, 268);
    expect(app.unallocatedSatang, 101);
    expect(app.loadErrorMessage, isNull);

    final prefs = await SharedPreferences.getInstance();
    final persisted = jsonDecode(prefs.getString(appStateStorageKey)!)
        as Map<String, dynamic>;
    expect(persisted['schemaVersion'], currentSchemaVersion);
    expect(persisted, contains('unallocatedSatang'));
    expect(persisted, isNot(contains('unallocated')));
  });

  test('JSON ที่พังถูกสำรองและคืน state ว่างพร้อมข้อความภาษาไทย', () async {
    const broken = '{นี่ไม่ใช่ JSON';
    SharedPreferences.setMockInitialValues(<String, Object>{
      appStateStorageKey: broken,
    });

    final app = AppState();
    await app.load();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(appStateCorruptBackupKey), broken);
    expect(app.user.onboarded, isFalse);
    expect(app.loadErrorMessage, contains('โหลดข้อมูลไม่สำเร็จ'));
  });

  test('schemaVersion ใหม่กว่าไม่ถูก migrate และเก็บ backup', () async {
    final newerJson = jsonEncode(<String, dynamic>{
      'schemaVersion': currentSchemaVersion + 1,
      'user': <String, dynamic>{'name': 'จากอนาคต'},
    });
    SharedPreferences.setMockInitialValues(<String, Object>{
      appStateStorageKey: newerJson,
    });

    final app = AppState();
    await app.load();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(appStateCorruptBackupKey), newerJson);
    expect(app.user.name, isEmpty);
    expect(app.loadErrorMessage, contains('เวอร์ชันใหม่กว่า'));
  });

  testWidgets('หน้าแอปแสดงข้อความเมื่อโหลดข้อมูลไม่สำเร็จ', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      appStateStorageKey: 'broken-json',
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState()..load(),
        child: const KeepKapookApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('โหลดข้อมูลไม่สำเร็จ'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsOneWidget);
  });

  test('save debounce writes only the latest snapshot', () async {
    final writes = <Map<String, dynamic>>[];
    final app = AppState(
      stateWriter: (raw) async {
        writes.add(jsonDecode(raw) as Map<String, dynamic>);
        return true;
      },
    );

    app.setName('ชื่อแรก');
    app.setName('ชื่อล่าสุด');

    await Future<void>.delayed(const Duration(milliseconds: 350));
    await app.flushPendingSaves();

    expect(writes, hasLength(1));
    expect(
        (writes.single['user'] as Map<String, dynamic>)['name'], 'ชื่อล่าสุด');
    app.dispose();
  });

  test('save queue never starts a newer write before the previous write',
      () async {
    final writes = <Map<String, dynamic>>[];
    final completions = <Completer<bool>>[];
    final app = AppState(
      stateWriter: (raw) {
        writes.add(jsonDecode(raw) as Map<String, dynamic>);
        final completion = Completer<bool>();
        completions.add(completion);
        return completion.future;
      },
    );

    app.setName('snapshot-1');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(writes, hasLength(1));

    app.setName('snapshot-2');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(writes, hasLength(1));

    completions.first.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(writes, hasLength(2));
    expect((writes[0]['user'] as Map<String, dynamic>)['name'], 'snapshot-1');
    expect((writes[1]['user'] as Map<String, dynamic>)['name'], 'snapshot-2');

    completions[1].complete(true);
    await app.flushPendingSaves();
    app.dispose();
  });

  test('save failure is exposed through an observable Thai message', () async {
    final app = AppState(stateWriter: (_) async => false);
    var notifications = 0;
    app.addListener(() => notifications++);

    app.setName('ข้อมูลที่ต้องบันทึก');
    await app.flushPendingSaves();

    expect(app.loadErrorMessage, isNotNull);
    expect(app.loadErrorMessage, contains('บันทึกข้อมูลล่าสุดไม่สำเร็จ'));
    expect(notifications, greaterThanOrEqualTo(2));
    app.dispose();
  });
}
