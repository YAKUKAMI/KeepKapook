import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'invariants/invariant_test_support.dart';

void main() {
  configureInvariantTestEnvironment();

  test('q-weekly-consistency และ b-rhythm มี handler จากวันบันทึกจริง',
      () async {
    final app = await loadEmptyInvariantApp();
    app.user.exp = 120;

    for (var index = 0; index < 7; index++) {
      app.addLedger(
        LedgerType.expense,
        100,
        'อาหาร',
        '',
        date: invariantTime.add(Duration(days: index)),
      );
    }

    final quest =
        app.quests.singleWhere((entry) => entry.id == 'q-weekly-consistency');
    final badge = app.badges.singleWhere((entry) => entry.id == 'b-rhythm');
    expect(quest.progress, quest.target);
    expect(badge.unlocked, isTrue);
    expect(app.user.exp, 120, reason: 'streak ห้ามแจกหรือหัก EXP อัตโนมัติ');
    await app.flushPendingSaves();
  });

  test('streak ขาดไม่หัก EXP และข้อความสถานะมาจาก summary ที่คำนวณใหม่',
      () async {
    final app = await loadEmptyInvariantApp();
    app.user.exp = 80;
    for (var index = 0; index < 3; index++) {
      app.addLedger(
        LedgerType.income,
        100,
        'รายได้',
        '',
        date: invariantTime.add(Duration(days: index)),
      );
    }

    final summary = app.habitSummary(
      now: invariantTime.add(const Duration(days: 4)),
    );
    expect(summary.currentStreak, 0);
    expect(summary.longestStreak, 3);
    expect(app.user.exp, 80);
    await app.flushPendingSaves();
  });

  test('ผู้ใช้ v5 เดิมได้รับ quest และ badge ที่กลับมาโดยไม่ต้อง migration',
      () async {
    final source = await loadEmptyInvariantApp();
    final raw = source.toJson();
    (raw['quests'] as List).removeWhere(
      (entry) => (entry as Map)['id'] == 'q-weekly-consistency',
    );
    (raw['badges'] as List).removeWhere(
      (entry) => (entry as Map)['id'] == 'b-rhythm',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      appStateStorageKey: jsonEncode(raw),
    });

    final reloaded = AppState();
    await reloaded.load();

    expect(
      reloaded.quests.any((entry) => entry.id == 'q-weekly-consistency'),
      isTrue,
    );
    expect(reloaded.badges.any((entry) => entry.id == 'b-rhythm'), isTrue);
  });

  test('badge ที่ปลดล็อกแล้วไม่ถูกเอาคืนเมื่อคำนวณ habit ใหม่', () async {
    final app = await loadEmptyInvariantApp();
    final badge = app.badges.singleWhere((entry) => entry.id == 'b-first-drop');
    badge
      ..unlocked = true
      ..progress = 1;

    app.addLedger(
      LedgerType.expense,
      100,
      'อาหาร',
      '',
      date: invariantTime,
    );

    expect(badge.unlocked, isTrue);
    expect(badge.progress, 1);
    await app.flushPendingSaves();
  });
}
