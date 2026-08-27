import '../models/models.dart';

class GoalMoneySummary {
  const GoalMoneySummary({
    required this.currentSatang,
    required this.targetSatang,
    required this.remainingSatang,
    required this.progress,
    required this.hasTarget,
    required this.isCompleted,
  });

  final int currentSatang;
  final int targetSatang;
  final int remainingSatang;
  final double progress;
  final bool hasTarget;
  final bool isCompleted;
}

GoalMoneySummary summarizeGoalMoney(Goal goal) => GoalMoneySummary(
      currentSatang: goal.currentSatang,
      targetSatang: goal.targetSatang,
      remainingSatang: goal.remainingSatang,
      progress: goal.progress,
      hasTarget: goal.hasSavingsTarget,
      isCompleted: goal.isCompleted,
    );

class GoalTotalsSummary {
  const GoalTotalsSummary({
    required this.totalSavedSatang,
    required this.targetedSavedSatang,
    required this.targetSatang,
  });

  final int totalSavedSatang;
  final int targetedSavedSatang;
  final int targetSatang;

  double get targetProgress =>
      targetSatang <= 0 ? 0 : (targetedSavedSatang / targetSatang).clamp(0, 1);
}

GoalTotalsSummary summarizeGoalTotals(Iterable<Goal> goals) {
  var totalSavedSatang = 0;
  var targetedSavedSatang = 0;
  var targetSatang = 0;
  for (final goal in goals) {
    totalSavedSatang += goal.currentSatang;
    if (goal.hasSavingsTarget) {
      targetedSavedSatang += goal.currentSatang;
      targetSatang += goal.targetSatang;
    }
  }
  return GoalTotalsSummary(
    totalSavedSatang: totalSavedSatang,
    targetedSavedSatang: targetedSavedSatang,
    targetSatang: targetSatang,
  );
}

class LedgerPeriodSummary {
  const LedgerPeriodSummary({
    required this.incomeSatang,
    required this.expenseSatang,
  });

  final int incomeSatang;
  final int expenseSatang;

  int get netSatang => incomeSatang - expenseSatang;
}

LedgerPeriodSummary summarizeLedgerMonth(
  Iterable<LedgerEntry> entries, {
  required DateTime now,
}) {
  var incomeSatang = 0;
  var expenseSatang = 0;
  for (final entry in entries) {
    final localDate = entry.date.toLocal();
    if (localDate.year != now.year || localDate.month != now.month) continue;
    if (entry.type == LedgerType.income) {
      incomeSatang += entry.amountSatang;
    } else {
      expenseSatang += entry.amountSatang;
    }
  }
  return LedgerPeriodSummary(
    incomeSatang: incomeSatang,
    expenseSatang: expenseSatang,
  );
}

class DailySavingTotal {
  const DailySavingTotal({required this.date, required this.totalSatang});

  final DateTime date;
  final int totalSatang;
}

List<DailySavingTotal> summarizeSevenDaySavings(
  Iterable<SavingTransaction> transactions, {
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final days = List<DateTime>.generate(
    7,
    (index) => today.subtract(Duration(days: 6 - index)),
  );
  return days.map((day) {
    final totalSatang = transactions
        .where(
          (transaction) =>
              transaction.type != TxType.withdraw &&
              transaction.date.year == day.year &&
              transaction.date.month == day.month &&
              transaction.date.day == day.day,
        )
        .fold<int>(
          0,
          (sum, transaction) => sum + transaction.amountSatang,
        );
    return DailySavingTotal(date: day, totalSatang: totalSatang);
  }).toList(growable: false);
}

class DashboardMoneySummary {
  const DashboardMoneySummary({
    required this.goals,
    required this.month,
    required this.sevenDays,
  });

  final GoalTotalsSummary goals;
  final LedgerPeriodSummary month;
  final List<DailySavingTotal> sevenDays;
}

DashboardMoneySummary summarizeDashboardMoney({
  required Iterable<Goal> goals,
  required Iterable<LedgerEntry> ledger,
  required Iterable<SavingTransaction> transactions,
  required DateTime now,
}) =>
    DashboardMoneySummary(
      goals: summarizeGoalTotals(goals),
      month: summarizeLedgerMonth(ledger, now: now),
      sevenDays: summarizeSevenDaySavings(transactions, now: now),
    );
