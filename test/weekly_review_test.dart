import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/utils/weekly_review.dart';

const _disclaimer =
    'สรุปนี้คำนวณจากรายการที่คุณบันทึก ไม่ใช่ยอดเงินจริงจากธนาคาร';

LedgerEntry _expense(
  String id,
  int amountSatang,
  DateTime date, {
  String category = 'อาหาร',
}) =>
    LedgerEntry(
      id: id,
      type: LedgerType.expense,
      amountSatang: amountSatang,
      category: category,
      date: date,
    );

SavingTransaction _saving(
  String id,
  int amountSatang,
  DateTime date, {
  String goalId = 'goal',
}) =>
    SavingTransaction(
      id: id,
      type: TxType.deposit,
      amountSatang: amountSatang,
      date: date,
      destinationGoalId: goalId,
      destinationGoalNameSnapshot: 'iPhone มือสอง',
    );

WeeklyGoalInput _goal({
  bool completed = false,
  bool noPlannedDate = false,
  int currentSatang = 500000,
  int targetSatang = 1500000,
}) =>
    WeeklyGoalInput(
      id: 'goal',
      name: 'iPhone มือสอง',
      currentSatang: currentSatang,
      targetSatang: targetSatang,
      plannedDate: noPlannedDate ? null : DateTime(2026, 12, 31),
      completed: completed,
    );

final _week = WeeklyReviewPeriod(
  kind: WeeklyReviewKind.weekly,
  start: DateTime(2026, 8, 10),
  end: DateTime(2026, 8, 17),
);

WeeklyReport _report({
  List<LedgerEntry> ledger = const <LedgerEntry>[],
  List<SavingTransaction> transactions = const <SavingTransaction>[],
  List<WeeklyGoalInput>? goals,
  WeeklyReviewPeriod? period,
}) =>
    buildWeeklyReport(
      ledger: ledger,
      transactions: transactions,
      goals: goals ?? <WeeklyGoalInput>[_goal()],
      period: period ?? _week,
    );

void main() {
  group('weekly report', () {
    test('สัปดาห์ไม่มีข้อมูลบอกตรงๆ และไม่สร้างแนวโน้มหรือตัวเชื่อม', () {
      final report = _report();

      expect(report.loggingDays, 0);
      expect(report.isDataSufficient, isFalse);
      expect(report.dataMessage, contains('ยังมีข้อมูลไม่พอ'));
      expect(report.projection, isNull);
      expect(report.goalLink, isNull);
      expect(report.disclaimer, _disclaimer);
    });

    test('ข้อมูลวันเดียวแสดงยอดจริงได้แต่ไม่เดาแนวโน้ม', () {
      final report = _report(
        ledger: <LedgerEntry>[
          _expense('expense', 15000, DateTime.utc(2026, 8, 12, 1)),
        ],
        transactions: <SavingTransaction>[
          _saving('saving', 5000, DateTime.utc(2026, 8, 12, 2)),
        ],
      );

      expect(report.loggingDays, 1);
      expect(report.expenseSatang, 15000);
      expect(report.savingsToGoalsSatang, 5000);
      expect(report.isDataSufficient, isFalse);
      expect(report.expenseComparison, isNull);
      expect(report.projection, isNull);
      expect(report.goalLink, isNull);
    });

    test('ช่วงสัปดาห์ข้ามเดือนรวมเฉพาะ start inclusive/end exclusive', () {
      final period = WeeklyReviewPeriod(
        kind: WeeklyReviewKind.weekly,
        start: DateTime(2026, 8, 31),
        end: DateTime(2026, 9, 7),
      );
      final report = _report(
        period: period,
        ledger: <LedgerEntry>[
          _expense('aug', 10000, DateTime.utc(2026, 8, 31, 2)),
          _expense('sep', 20000, DateTime.utc(2026, 9, 2, 2)),
          _expense('end', 90000, DateTime.utc(2026, 9, 7, 2)),
        ],
      );

      expect(report.loggingDays, 2);
      expect(report.expenseSatang, 30000);
    });

    test('ช่วงสัปดาห์ข้ามปีรวมรายการถูกวัน', () {
      final period = WeeklyReviewPeriod(
        kind: WeeklyReviewKind.weekly,
        start: DateTime(2026, 12, 28),
        end: DateTime(2027, 1, 4),
      );
      final report = _report(
        period: period,
        ledger: <LedgerEntry>[
          _expense('dec', 10000, DateTime.utc(2026, 12, 28, 2)),
          _expense('jan', 20000, DateTime.utc(2027, 1, 2, 2)),
        ],
      );

      expect(report.loggingDays, 2);
      expect(report.expenseSatang, 30000);
    });

    test('เป้าหมายที่ถึงแล้วไม่สร้าง projection หรือตัวเชื่อม', () {
      final report = _report(
        goals: <WeeklyGoalInput>[_goal(completed: true)],
        ledger: <LedgerEntry>[
          _expense('previous-1', 100000, DateTime.utc(2026, 8, 3, 2)),
          _expense('previous-2', 100000, DateTime.utc(2026, 8, 4, 2)),
          _expense('current-1', 120000, DateTime.utc(2026, 8, 10, 2)),
          _expense('current-2', 104000, DateTime.utc(2026, 8, 11, 2)),
        ],
        transactions: <SavingTransaction>[
          _saving('saving-1', 40000, DateTime.utc(2026, 8, 12, 2)),
          _saving('saving-2', 35000, DateTime.utc(2026, 8, 13, 2)),
        ],
      );

      expect(report.projection, isNull);
      expect(report.goalLink, isNull);
    });

    test('เป้าหมายไม่มีกำหนดวันยังคำนวณวันถึงเป้าและตัวเชื่อมได้', () {
      final report = _report(
        goals: <WeeklyGoalInput>[_goal(noPlannedDate: true)],
        ledger: <LedgerEntry>[
          _expense('previous-1', 90000, DateTime.utc(2026, 8, 3, 2)),
          _expense('previous-2', 100000, DateTime.utc(2026, 8, 4, 2)),
          _expense('current-1', 110000, DateTime.utc(2026, 8, 10, 2)),
          _expense('current-2', 104000, DateTime.utc(2026, 8, 11, 2)),
        ],
        transactions: <SavingTransaction>[
          _saving('saving-1', 40000, DateTime.utc(2026, 8, 12, 2)),
          _saving('saving-2', 35000, DateTime.utc(2026, 8, 13, 2)),
        ],
      );

      expect(report.projection, isNotNull);
      expect(report.projection!.daysComparedWithPlan, isNull);
      expect(report.goalLink, isNotNull);
      expect(report.goalLink!.daysSooner, greaterThanOrEqualTo(1));
    });

    test('projection คืนวันที่ถึงเป้าและจำนวนวันที่เร็วกว่าแผน', () {
      final report = _report(
        ledger: <LedgerEntry>[
          _expense('day-1', 10000, DateTime.utc(2026, 8, 12, 2)),
          _expense('day-2', 10000, DateTime.utc(2026, 8, 13, 2)),
        ],
        transactions: <SavingTransaction>[
          _saving('saving-1', 40000, DateTime.utc(2026, 8, 12, 2)),
          _saving('saving-2', 35000, DateTime.utc(2026, 8, 13, 2)),
        ],
      );

      expect(report.projection!.daysToGoal, 94);
      expect(report.projection!.estimatedDate, DateTime(2026, 11, 19));
      expect(report.projection!.daysComparedWithPlan, 42);
    });

    test('ยอดออมเข้าเป้านับเฉพาะ externalIn ไม่รวม transfer', () {
      final report = _report(
        ledger: <LedgerEntry>[
          _expense('day-1', 10000, DateTime.utc(2026, 8, 12, 2)),
          _expense('day-2', 10000, DateTime.utc(2026, 8, 13, 2)),
        ],
        transactions: <SavingTransaction>[
          _saving('saving', 40000, DateTime.utc(2026, 8, 12, 2)),
          SavingTransaction(
            id: 'transfer',
            type: TxType.transfer,
            amountSatang: 90000,
            date: DateTime.utc(2026, 8, 13, 2),
            goalId: 'another-goal',
            destinationGoalId: 'goal',
          ),
        ],
      );

      expect(report.savingsToGoalsSatang, 40000);
    });
  });

  group('expense to goal link', () {
    final enoughSavings = <SavingTransaction>[
      _saving('saving-1', 40000, DateTime.utc(2026, 8, 12, 2)),
      _saving('saving-2', 35000, DateTime.utc(2026, 8, 13, 2)),
    ];

    test('ไม่มีรายจ่ายสัปดาห์นี้ไม่แสดงตัวเชื่อม', () {
      final report = _report(transactions: enoughSavings);
      expect(report.goalLink, isNull);
    });

    test('ไม่มีข้อมูลสัปดาห์ก่อนเทียบไม่แสดงตัวเชื่อม', () {
      final report = _report(
        ledger: <LedgerEntry>[
          _expense('current-1', 110000, DateTime.utc(2026, 8, 10, 2)),
          _expense('current-2', 104000, DateTime.utc(2026, 8, 11, 2)),
        ],
        transactions: enoughSavings,
      );

      expect(report.expenseComparison, isNull);
      expect(report.goalLink, isNull);
    });

    test('รายจ่ายเพิ่ม ใช้ส่วนต่างจริงเพื่อบอกผลของการกลับไปเท่าเดิม', () {
      final report = _report(
        ledger: <LedgerEntry>[
          _expense('previous-1', 90000, DateTime.utc(2026, 8, 3, 2)),
          _expense('previous-2', 100000, DateTime.utc(2026, 8, 4, 2)),
          _expense('current-1', 110000, DateTime.utc(2026, 8, 10, 2)),
          _expense('current-2', 104000, DateTime.utc(2026, 8, 11, 2)),
        ],
        transactions: enoughSavings,
      );

      expect(report.expenseComparison!.deltaSatang, 24000);
      expect(report.goalLink!.kind, WeeklyGoalLinkKind.returnToPrevious);
      expect(report.goalLink!.observedDifferenceSatang, 24000);
      expect(report.goalLink!.daysSooner, greaterThanOrEqualTo(1));
    });

    test('รายจ่ายลดลง ใช้ส่วนต่างจริงเพื่อชมการรักษาระดับ', () {
      final report = _report(
        ledger: <LedgerEntry>[
          _expense('previous-1', 110000, DateTime.utc(2026, 8, 3, 2)),
          _expense('previous-2', 104000, DateTime.utc(2026, 8, 4, 2)),
          _expense('current-1', 90000, DateTime.utc(2026, 8, 10, 2)),
          _expense('current-2', 100000, DateTime.utc(2026, 8, 11, 2)),
        ],
        transactions: enoughSavings,
      );

      expect(report.expenseComparison!.deltaSatang, -24000);
      expect(report.goalLink!.kind, WeeklyGoalLinkKind.maintainReduction);
      expect(report.goalLink!.observedDifferenceSatang, 24000);
      expect(report.goalLink!.daysSooner, greaterThanOrEqualTo(1));
    });

    test('รายจ่ายเท่าสัปดาห์ก่อนไม่อ้างว่าทำให้ถึงเป้าเร็วขึ้น', () {
      final report = _report(
        ledger: <LedgerEntry>[
          _expense('previous-1', 90000, DateTime.utc(2026, 8, 3, 2)),
          _expense('previous-2', 100000, DateTime.utc(2026, 8, 4, 2)),
          _expense('current-1', 90000, DateTime.utc(2026, 8, 10, 2)),
          _expense('current-2', 100000, DateTime.utc(2026, 8, 11, 2)),
        ],
        transactions: enoughSavings,
      );

      expect(report.expenseComparison!.deltaSatang, 0);
      expect(report.goalLink, isNull);
    });

    test('ไม่มีเป้าหมายที่ยังไม่สำเร็จไม่แสดงตัวเชื่อม', () {
      final report = _report(
        goals: <WeeklyGoalInput>[_goal(completed: true)],
        ledger: <LedgerEntry>[
          _expense('previous-1', 90000, DateTime.utc(2026, 8, 3, 2)),
          _expense('previous-2', 100000, DateTime.utc(2026, 8, 4, 2)),
          _expense('current-1', 110000, DateTime.utc(2026, 8, 10, 2)),
          _expense('current-2', 104000, DateTime.utc(2026, 8, 11, 2)),
        ],
        transactions: enoughSavings,
      );
      expect(report.goalLink, isNull);
    });

    test('อัตราออมเป็นศูนย์คืนคำชวนเริ่มโดยไม่มีตัวเลขอนันต์', () {
      final report = _report(
        ledger: <LedgerEntry>[
          _expense('previous-1', 90000, DateTime.utc(2026, 8, 3, 2)),
          _expense('previous-2', 100000, DateTime.utc(2026, 8, 4, 2)),
          _expense('current-1', 110000, DateTime.utc(2026, 8, 10, 2)),
          _expense('current-2', 104000, DateTime.utc(2026, 8, 11, 2)),
        ],
      );

      expect(report.goalLink!.kind, WeeklyGoalLinkKind.startSaving);
      expect(report.goalLink!.daysSooner, isNull);
    });

    test('ผลเร็วขึ้นต่ำกว่า 1 วันไม่แสดงตัวเชื่อม', () {
      final report = _report(
        goals: <WeeklyGoalInput>[
          _goal(currentSatang: 1499900, targetSatang: 1500000),
        ],
        ledger: <LedgerEntry>[
          _expense('previous-1', 100000, DateTime.utc(2026, 8, 3, 2)),
          _expense('previous-2', 100000, DateTime.utc(2026, 8, 4, 2)),
          _expense('current-1', 100050, DateTime.utc(2026, 8, 10, 2)),
          _expense('current-2', 100050, DateTime.utc(2026, 8, 11, 2)),
        ],
        transactions: enoughSavings,
      );
      expect(report.goalLink, isNull);
    });
  });

  group('review availability and history', () {
    test('first-week review พร้อมวันที่ 7 โดยไม่ต้องรอวันจันทร์', () {
      final periods = availableWeeklyReviewPeriods(
        firstUseAt: DateTime(2026, 8, 5, 12),
        asOf: DateTime(2026, 8, 12, 12),
      );

      expect(periods, hasLength(1));
      expect(periods.single.kind, WeeklyReviewKind.firstWeek);
      expect(periods.single.start, DateTime(2026, 8, 5));
      expect(periods.single.end, DateTime(2026, 8, 12));
    });

    test('ยังไม่ครบวันที่ 7 ไม่สร้าง first-week review', () {
      final periods = availableWeeklyReviewPeriods(
        firstUseAt: DateTime(2026, 8, 5, 12),
        asOf: DateTime(2026, 8, 11, 23),
      );
      expect(periods, isEmpty);
    });

    test('ไม่เปิดวันจันทร์ยังเห็น weekly ล่าสุดและ first-week ย้อนหลัง', () {
      final periods = availableWeeklyReviewPeriods(
        firstUseAt: DateTime(2026, 8, 5, 12),
        asOf: DateTime(2026, 8, 19, 12),
      );

      expect(periods.first.kind, WeeklyReviewKind.weekly);
      expect(periods.first.start, DateTime(2026, 8, 10));
      expect(periods.first.end, DateTime(2026, 8, 17));
      expect(periods.last.kind, WeeklyReviewKind.firstWeek);
    });
  });
}
