import '../models/models.dart';
import 'habit_streak.dart';

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
              transaction.flow == TransactionFlow.externalIn &&
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

/// สรุปรายการบัญชีในช่วง [start, end) ตามวันท้องถิ่นประเทศไทย
LedgerPeriodSummary summarizeLedgerPeriod(
  Iterable<LedgerEntry> entries, {
  required DateTime start,
  required DateTime end,
}) {
  final normalizedStart = bangkokLocalDay(start);
  final normalizedEnd = bangkokLocalDay(end);
  var incomeSatang = 0;
  var expenseSatang = 0;
  for (final entry in entries) {
    final day = bangkokLocalDay(entry.date);
    if (day.isBefore(normalizedStart) || !day.isBefore(normalizedEnd)) continue;
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

int countLedgerExpenseDays(
  Iterable<LedgerEntry> entries, {
  required DateTime start,
  required DateTime end,
}) {
  final normalizedStart = bangkokLocalDay(start);
  final normalizedEnd = bangkokLocalDay(end);
  return entries
      .where((entry) => entry.type == LedgerType.expense)
      .map((entry) => bangkokLocalDay(entry.date))
      .where(
        (day) => !day.isBefore(normalizedStart) && day.isBefore(normalizedEnd),
      )
      .toSet()
      .length;
}

class ExpenseCategoryTotal {
  const ExpenseCategoryTotal({
    required this.category,
    required this.amountSatang,
  });

  final String category;
  final int amountSatang;
}

ExpenseCategoryTotal? summarizeTopExpenseCategory(
  Iterable<LedgerEntry> entries, {
  required DateTime start,
  required DateTime end,
}) {
  final normalizedStart = bangkokLocalDay(start);
  final normalizedEnd = bangkokLocalDay(end);
  final totals = <String, int>{};
  for (final entry in entries) {
    final day = bangkokLocalDay(entry.date);
    if (entry.type != LedgerType.expense ||
        day.isBefore(normalizedStart) ||
        !day.isBefore(normalizedEnd)) {
      continue;
    }
    totals.update(
      entry.category,
      (amount) => amount + entry.amountSatang,
      ifAbsent: () => entry.amountSatang,
    );
  }
  if (totals.isEmpty) return null;
  final sorted = totals.entries.toList()
    ..sort((left, right) {
      final byAmount = right.value.compareTo(left.value);
      return byAmount != 0 ? byAmount : left.key.compareTo(right.key);
    });
  return ExpenseCategoryTotal(
    category: sorted.first.key,
    amountSatang: sorted.first.value,
  );
}

int summarizeExternalGoalSavings(
  Iterable<SavingTransaction> transactions, {
  required DateTime start,
  required DateTime end,
  String? goalId,
}) {
  final normalizedStart = bangkokLocalDay(start);
  final normalizedEnd = bangkokLocalDay(end);
  var totalSatang = 0;
  for (final transaction in transactions) {
    final day = bangkokLocalDay(transaction.date);
    if (transaction.flow != TransactionFlow.externalIn ||
        transaction.destinationGoalId == null ||
        (goalId != null && transaction.destinationGoalId != goalId) ||
        day.isBefore(normalizedStart) ||
        !day.isBefore(normalizedEnd)) {
      continue;
    }
    totalSatang += transaction.amountSatang;
  }
  return totalSatang;
}

int countExternalGoalSavingDays(
  Iterable<SavingTransaction> transactions, {
  required DateTime start,
  required DateTime end,
  String? goalId,
}) {
  final normalizedStart = bangkokLocalDay(start);
  final normalizedEnd = bangkokLocalDay(end);
  return transactions
      .where(
        (transaction) =>
            transaction.flow == TransactionFlow.externalIn &&
            transaction.destinationGoalId != null &&
            (goalId == null || transaction.destinationGoalId == goalId),
      )
      .map((transaction) => bangkokLocalDay(transaction.date))
      .where(
        (day) => !day.isBefore(normalizedStart) && day.isBefore(normalizedEnd),
      )
      .toSet()
      .length;
}

class GoalPaceProjection {
  const GoalPaceProjection({
    required this.weeklySavingSatang,
    required this.remainingSatang,
    required this.daysToGoal,
  });

  final int weeklySavingSatang;
  final int remainingSatang;
  final int daysToGoal;
}

GoalPaceProjection? projectGoalAtWeeklyPace({
  required int currentSatang,
  required int targetSatang,
  required int weeklySavingSatang,
}) {
  final remainingSatang = targetSatang - currentSatang;
  if (remainingSatang <= 0 || weeklySavingSatang <= 0) return null;
  final numerator = BigInt.from(remainingSatang) * BigInt.from(7);
  final denominator = BigInt.from(weeklySavingSatang);
  final daysToGoal =
      ((numerator + denominator - BigInt.one) ~/ denominator).toInt();
  return GoalPaceProjection(
    weeklySavingSatang: weeklySavingSatang,
    remainingSatang: remainingSatang,
    daysToGoal: daysToGoal,
  );
}

class ExpenseGoalLinkMetrics {
  const ExpenseGoalLinkMetrics({
    required this.observedDifferenceSatang,
    required this.expensesIncreased,
    required this.currentWeeklySavingSatang,
    this.daysSooner,
    this.needsSavingStart = false,
  });

  final int observedDifferenceSatang;
  final bool expensesIncreased;
  final int currentWeeklySavingSatang;
  final int? daysSooner;
  final bool needsSavingStart;
}

/// เชื่อมส่วนต่างรายจ่ายที่สังเกตได้จริงกับเวลาถึงเป้าหมาย
///
/// ไม่สร้างงบสมมติขึ้นเอง และคืน null เมื่อผลต่างช่วยให้เร็วขึ้นไม่ถึงหนึ่งวัน
/// เพื่อไม่ให้ UI กล่าวเกินความหมายของข้อมูลที่มี
ExpenseGoalLinkMetrics? calculateExpenseGoalLink({
  required int currentExpenseSatang,
  required int previousExpenseSatang,
  required int currentGoalSatang,
  required int targetGoalSatang,
  required int currentWeeklySavingSatang,
}) {
  if (currentExpenseSatang <= 0 || previousExpenseSatang <= 0) return null;
  final signedDifference = currentExpenseSatang - previousExpenseSatang;
  final observedDifference = signedDifference.abs();
  final remainingSatang = targetGoalSatang - currentGoalSatang;
  if (observedDifference <= 0 || remainingSatang <= 0) return null;
  if (currentWeeklySavingSatang <= 0) {
    return ExpenseGoalLinkMetrics(
      observedDifferenceSatang: observedDifference,
      expensesIncreased: signedDifference > 0,
      currentWeeklySavingSatang: 0,
      needsSavingStart: true,
    );
  }

  final currentProjection = projectGoalAtWeeklyPace(
    currentSatang: currentGoalSatang,
    targetSatang: targetGoalSatang,
    weeklySavingSatang: currentWeeklySavingSatang,
  );
  final improvedProjection = projectGoalAtWeeklyPace(
    currentSatang: currentGoalSatang,
    targetSatang: targetGoalSatang,
    weeklySavingSatang: currentWeeklySavingSatang + observedDifference,
  );
  if (currentProjection == null || improvedProjection == null) return null;
  final daysSooner =
      currentProjection.daysToGoal - improvedProjection.daysToGoal;
  if (daysSooner < 1) return null;
  return ExpenseGoalLinkMetrics(
    observedDifferenceSatang: observedDifference,
    expensesIncreased: signedDifference > 0,
    currentWeeklySavingSatang: currentWeeklySavingSatang,
    daysSooner: daysSooner,
  );
}
