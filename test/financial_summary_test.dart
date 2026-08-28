import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/utils/financial_summary.dart';

Goal _goal({
  required String id,
  required int currentSatang,
  required int targetSatang,
  bool flexible = false,
}) =>
    Goal(
      id: id,
      name: id,
      currentSatang: currentSatang,
      targetSatang: targetSatang,
      startDate: DateTime(2026, 8, 1),
      targetDate: DateTime(2026, 12, 1),
      flexible: flexible,
    );

void main() {
  test('goal totals และ progress เท่ากับสูตรเดิม', () {
    final normal = _goal(
      id: 'normal',
      currentSatang: 4000,
      targetSatang: 10000,
    );
    final flexible = _goal(
      id: 'flexible',
      currentSatang: 2500,
      targetSatang: 0,
      flexible: true,
    );

    final normalSummary = summarizeGoalMoney(normal);
    final totals = summarizeGoalTotals(<Goal>[normal, flexible]);

    expect(normalSummary.progress, 0.4);
    expect(normalSummary.remainingSatang, 6000);
    expect(totals.totalSavedSatang, 6500);
    expect(totals.targetedSavedSatang, 4000);
    expect(totals.targetSatang, 10000);
    expect(totals.targetProgress, 0.4);
  });

  test('monthly ledger ใช้เดือน local เดียวกับพฤติกรรมเดิม', () {
    final now = DateTime(2026, 8, 27, 12);
    final entries = <LedgerEntry>[
      LedgerEntry(
        id: 'income-current',
        type: LedgerType.income,
        amountSatang: 10000,
        category: 'งาน',
        date: DateTime(2026, 8, 1, 8).toUtc(),
      ),
      LedgerEntry(
        id: 'expense-current',
        type: LedgerType.expense,
        amountSatang: 3500,
        category: 'อาหาร',
        date: DateTime(2026, 8, 20, 20).toUtc(),
      ),
      LedgerEntry(
        id: 'income-previous',
        type: LedgerType.income,
        amountSatang: 90000,
        category: 'งาน',
        date: DateTime(2026, 7, 31, 12).toUtc(),
      ),
    ];

    final summary = summarizeLedgerMonth(entries, now: now);

    expect(summary.incomeSatang, 10000);
    expect(summary.expenseSatang, 3500);
    expect(summary.netSatang, 6500);
  });

  test('seven-day summary รับ now และคืนเจ็ดวันเรียงเก่าไปใหม่', () {
    final now = DateTime(2026, 8, 27, 12);
    final transactions = <SavingTransaction>[
      SavingTransaction(
        id: 'today',
        type: TxType.deposit,
        amountSatang: 750,
        date: DateTime(2026, 8, 27, 8),
      ),
      SavingTransaction(
        id: 'withdraw',
        type: TxType.withdraw,
        amountSatang: 200,
        date: DateTime(2026, 8, 27, 9),
      ),
      SavingTransaction(
        id: 'outside-window',
        type: TxType.deposit,
        amountSatang: 9999,
        date: DateTime(2026, 8, 20, 8),
      ),
    ];

    final summary = summarizeSevenDaySavings(transactions, now: now);

    expect(summary, hasLength(7));
    expect(summary.first.date, DateTime(2026, 8, 21));
    expect(summary.last.date, DateTime(2026, 8, 27));
    expect(summary.last.totalSatang, 750);
  });
}
