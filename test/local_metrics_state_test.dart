import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/state/backup.dart';
import 'package:keepkapook/utils/parser/parser.dart';

void main() {
  final now = DateTime.utc(2026, 1, 29);

  test('AppState นับ saving/expense/undo/correction โดย undo คืนตัวนับรายการ',
      () {
    final app = _readyApp(now);
    app.addSaving(
      amountSatang: 5000,
      goalId: 'goal',
      date: DateTime.utc(2026, 1, 22),
    );
    app.addLedger(
      LedgerType.expense,
      3500,
      'อาหาร',
      '',
      date: DateTime.utc(2026, 1, 23),
    );
    final quickReceipt = app.quickSave(
      amountSatang: 2000,
      goalId: 'goal',
      date: DateTime.utc(2026, 1, 24),
    );

    expect(app.localMetrics.savingRecordCount, 2);
    expect(app.localMetrics.expenseRecordCount, 1);
    expect(app.undoQuickRecord(quickReceipt), isTrue);
    expect(app.localMetrics.savingRecordCount, 1);
    expect(app.localMetrics.undoCount, 1);

    final expenseId = app.ledger.single.id;
    app.updateLedgerCategory(
      expenseId,
      'ของใช้',
      parserInput: 'ซื้อของ 35',
    );
    expect(app.localMetrics.correctionCount, 1);
    expect(app.localMetrics.parserCorpus.single.input, 'ซื้อของ 35');
  });

  test('parser/review/recovery/next-goal counters persist ใน state และ export',
      () {
    final app = _readyApp(now);
    app.recordQuickEntryResult(
      ParseTier.low,
      'จ่ายแทนเพื่อน 500',
      occurredAt: now,
    );
    app.completeWeeklyReview();
    app.recordRecoveryPlanUse();
    app.recordNextGoalDecision(accepted: true);
    app.recordNextGoalDecision(accepted: false);

    final state = app.toJson();
    final metrics = Map<String, dynamic>.from(state['metrics'] as Map);
    expect(metrics['weeklyReviewOpenCount'], 1);
    expect(metrics['recoveryPlanAcceptedCount'], 1);
    expect(metrics['nextGoalOfferAcceptedCount'], 1);
    expect(metrics['nextGoalOfferDeferredCount'], 1);
    expect(metrics.toString(), isNot(contains('amountSatang')));

    final backup = jsonDecode(
      createBackupJson(
        state: state,
        exportedAt: now,
        appVersion: '1.0.0+1',
      ),
    ) as Map<String, dynamic>;
    expect(backup['metrics'], equals(metrics));
  });
}

AppState _readyApp(DateTime now) => AppState(now: () => now)
  ..loaded = true
  ..user = AppUser(name: 'เมย์', onboarded: true)
  ..goals = <Goal>[
    Goal(
      id: 'goal',
      name: 'เป้าหมาย',
      targetSatang: 100000,
      startDate: DateTime.utc(2026, 1, 1),
      targetDate: DateTime.utc(2026, 12, 1),
    ),
  ];
