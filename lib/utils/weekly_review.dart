import '../models/models.dart';
import 'financial_summary.dart';
import 'habit_streak.dart';

const weeklyReportDisclaimer =
    'สรุปนี้คำนวณจากรายการที่คุณบันทึก ไม่ใช่ยอดเงินจริงจากธนาคาร';

enum WeeklyReviewKind { firstWeek, weekly }

class WeeklyReviewPeriod {
  const WeeklyReviewPeriod({
    required this.kind,
    required this.start,
    required this.end,
  });

  final WeeklyReviewKind kind;
  final DateTime start;
  final DateTime end;

  DateTime get lastDay => end.subtract(const Duration(days: 1));

  String get id =>
      '${kind.name}-${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
}

class WeeklyGoalInput {
  const WeeklyGoalInput({
    required this.id,
    required this.name,
    required this.currentSatang,
    required this.targetSatang,
    required this.completed,
    this.plannedDate,
    this.startedAt,
    this.flexible = false,
  });

  factory WeeklyGoalInput.fromGoal(Goal goal) => WeeklyGoalInput(
        id: goal.id,
        name: goal.name,
        currentSatang: goal.currentSatang,
        targetSatang: goal.targetSatang,
        completed: goal.isCompleted,
        plannedDate: goal.targetDate,
        startedAt: goal.startDate,
        flexible: goal.flexible,
      );

  final String id;
  final String name;
  final int currentSatang;
  final int targetSatang;
  final bool completed;
  final DateTime? plannedDate;
  final DateTime? startedAt;
  final bool flexible;
}

class WeeklyExpenseComparison {
  const WeeklyExpenseComparison({
    required this.currentSatang,
    required this.previousSatang,
  });

  final int currentSatang;
  final int previousSatang;
  int get deltaSatang => currentSatang - previousSatang;
  int get absoluteDeltaSatang => deltaSatang.abs();
}

class WeeklyGoalProjection {
  const WeeklyGoalProjection({
    required this.goalId,
    required this.goalName,
    required this.weeklySavingSatang,
    required this.daysToGoal,
    required this.estimatedDate,
    this.daysComparedWithPlan,
  });

  final String goalId;
  final String goalName;
  final int weeklySavingSatang;
  final int daysToGoal;
  final DateTime estimatedDate;

  /// ค่าบวก = เร็วกว่าแผน, ค่าลบ = ช้ากว่าแผน
  final int? daysComparedWithPlan;
  int? get absoluteDaysComparedWithPlan => daysComparedWithPlan?.abs();
}

enum WeeklyGoalLinkKind { returnToPrevious, maintainReduction, startSaving }

class WeeklyGoalLink {
  const WeeklyGoalLink({
    required this.kind,
    required this.goalId,
    required this.goalName,
    required this.observedDifferenceSatang,
    this.daysSooner,
  });

  final WeeklyGoalLinkKind kind;
  final String goalId;
  final String goalName;
  final int observedDifferenceSatang;
  final int? daysSooner;
}

class WeeklyReport {
  const WeeklyReport({
    required this.period,
    required this.loggingDays,
    required this.streak,
    required this.savingsToGoalsSatang,
    required this.expenseSatang,
    required this.isDataSufficient,
    required this.disclaimer,
    this.dataMessage,
    this.expenseComparison,
    this.topExpenseCategory,
    this.projection,
    this.goalLink,
  });

  final WeeklyReviewPeriod period;
  final int loggingDays;
  final int streak;
  final int savingsToGoalsSatang;
  final int expenseSatang;
  final bool isDataSufficient;
  final String disclaimer;
  final String? dataMessage;
  final WeeklyExpenseComparison? expenseComparison;
  final ExpenseCategoryTotal? topExpenseCategory;
  final WeeklyGoalProjection? projection;
  final WeeklyGoalLink? goalLink;
}

DateTime? deriveFirstUseAt({
  required Iterable<WeeklyGoalInput> goals,
  required Iterable<LedgerEntry> ledger,
  required Iterable<SavingTransaction> transactions,
}) {
  final candidates = <DateTime>[
    ...goals.map((goal) => goal.startedAt).whereType<DateTime>(),
    ...ledger.map((entry) => entry.date),
    ...transactions.map((transaction) => transaction.date),
  ];
  if (candidates.isEmpty) return null;
  candidates.sort();
  return candidates.first;
}

List<WeeklyReviewPeriod> availableWeeklyReviewPeriods({
  required DateTime firstUseAt,
  required DateTime asOf,
}) {
  final firstDay = bangkokLocalDay(firstUseAt);
  final asOfDay = bangkokLocalDay(asOf);
  final firstWeekEnd = firstDay.add(const Duration(days: 7));
  if (asOfDay.isBefore(firstWeekEnd)) return const <WeeklyReviewPeriod>[];

  final periods = <WeeklyReviewPeriod>[];
  final currentMonday = asOfDay.subtract(
    Duration(days: asOfDay.weekday - DateTime.monday),
  );
  var weeklyStart = currentMonday.subtract(const Duration(days: 7));
  while (!weeklyStart.isBefore(firstDay)) {
    final weeklyEnd = weeklyStart.add(const Duration(days: 7));
    if (weeklyEnd.isAfter(firstWeekEnd)) {
      periods.add(
        WeeklyReviewPeriod(
          kind: WeeklyReviewKind.weekly,
          start: weeklyStart,
          end: weeklyEnd,
        ),
      );
    }
    weeklyStart = weeklyStart.subtract(const Duration(days: 7));
  }
  periods.add(
    WeeklyReviewPeriod(
      kind: WeeklyReviewKind.firstWeek,
      start: firstDay,
      end: firstWeekEnd,
    ),
  );
  return List<WeeklyReviewPeriod>.unmodifiable(periods);
}

WeeklyReport buildWeeklyReport({
  required Iterable<LedgerEntry> ledger,
  required Iterable<SavingTransaction> transactions,
  required Iterable<WeeklyGoalInput> goals,
  required WeeklyReviewPeriod period,
}) {
  final ledgerList = ledger.toList(growable: false);
  final transactionList = transactions.toList(growable: false);
  final habitEntries = collectHabitEntries(
    ledger: ledgerList,
    transactions: transactionList,
  );
  final activeDays = habitEntries
      .map((entry) => bangkokLocalDay(entry.date))
      .where(
        (day) => !day.isBefore(period.start) && day.isBefore(period.end),
      )
      .toSet();
  final loggingDays = activeDays.length;
  final isDataSufficient = loggingDays >= 2;
  final streak = calculateHabitStreak(
    habitEntries.map((entry) => entry.date),
    asOf: period.end.subtract(const Duration(microseconds: 1)),
  ).currentStreak;
  final currentLedger = summarizeLedgerPeriod(
    ledgerList,
    start: period.start,
    end: period.end,
  );
  final previousStart = period.start.subtract(const Duration(days: 7));
  final previousLedger = summarizeLedgerPeriod(
    ledgerList,
    start: previousStart,
    end: period.start,
  );
  final currentExpenseDays = countLedgerExpenseDays(
    ledgerList,
    start: period.start,
    end: period.end,
  );
  final previousExpenseDays = countLedgerExpenseDays(
    ledgerList,
    start: previousStart,
    end: period.start,
  );
  final expenseComparison = currentExpenseDays >= 2 && previousExpenseDays >= 2
      ? WeeklyExpenseComparison(
          currentSatang: currentLedger.expenseSatang,
          previousSatang: previousLedger.expenseSatang,
        )
      : null;
  final savingsToGoalsSatang = summarizeExternalGoalSavings(
    transactionList,
    start: period.start,
    end: period.end,
  );
  final selectedGoal = _selectGoal(
    goals,
    transactions: transactionList,
    start: period.start,
    end: period.end,
  );
  final goalSavings = selectedGoal == null
      ? 0
      : summarizeExternalGoalSavings(
          transactionList,
          start: period.start,
          end: period.end,
          goalId: selectedGoal.id,
        );
  final savingDays = selectedGoal == null
      ? 0
      : countExternalGoalSavingDays(
          transactionList,
          start: period.start,
          end: period.end,
          goalId: selectedGoal.id,
        );
  final projection = isDataSufficient && selectedGoal != null && savingDays >= 2
      ? _buildProjection(selectedGoal, goalSavings, period.end)
      : null;
  final goalLink =
      isDataSufficient && selectedGoal != null && expenseComparison != null
          ? _buildGoalLink(
              selectedGoal,
              expenseComparison,
              currentWeeklySavingSatang: goalSavings,
            )
          : null;

  return WeeklyReport(
    period: period,
    loggingDays: loggingDays,
    streak: streak,
    savingsToGoalsSatang: savingsToGoalsSatang,
    expenseSatang: currentLedger.expenseSatang,
    isDataSufficient: isDataSufficient,
    dataMessage: isDataSufficient
        ? null
        : 'ยังมีข้อมูลไม่พอจะสรุปแนวโน้ม ลองบันทึกอย่างน้อย 2 วันนะ',
    expenseComparison: expenseComparison,
    topExpenseCategory: summarizeTopExpenseCategory(
      ledgerList,
      start: period.start,
      end: period.end,
    ),
    projection: projection,
    goalLink: goalLink,
    disclaimer: weeklyReportDisclaimer,
  );
}

WeeklyGoalInput? _selectGoal(
  Iterable<WeeklyGoalInput> goals, {
  required Iterable<SavingTransaction> transactions,
  required DateTime start,
  required DateTime end,
}) {
  final candidates = goals
      .where(
        (goal) =>
            !goal.flexible &&
            !goal.completed &&
            goal.targetSatang > goal.currentSatang,
      )
      .toList();
  if (candidates.isEmpty) return null;
  candidates.sort((left, right) {
    final leftSavings = summarizeExternalGoalSavings(
      transactions,
      start: start,
      end: end,
      goalId: left.id,
    );
    final rightSavings = summarizeExternalGoalSavings(
      transactions,
      start: start,
      end: end,
      goalId: right.id,
    );
    final bySavings = rightSavings.compareTo(leftSavings);
    if (bySavings != 0) return bySavings;
    if (left.plannedDate == null && right.plannedDate != null) return 1;
    if (left.plannedDate != null && right.plannedDate == null) return -1;
    final byDate = left.plannedDate?.compareTo(right.plannedDate!) ?? 0;
    return byDate != 0 ? byDate : left.id.compareTo(right.id);
  });
  return candidates.first;
}

WeeklyGoalProjection? _buildProjection(
  WeeklyGoalInput goal,
  int weeklySavingSatang,
  DateTime periodEnd,
) {
  final pace = projectGoalAtWeeklyPace(
    currentSatang: goal.currentSatang,
    targetSatang: goal.targetSatang,
    weeklySavingSatang: weeklySavingSatang,
  );
  if (pace == null) return null;
  final estimatedDate = periodEnd.add(Duration(days: pace.daysToGoal));
  final plannedDate =
      goal.plannedDate == null ? null : bangkokLocalDay(goal.plannedDate!);
  return WeeklyGoalProjection(
    goalId: goal.id,
    goalName: goal.name,
    weeklySavingSatang: weeklySavingSatang,
    daysToGoal: pace.daysToGoal,
    estimatedDate: estimatedDate,
    daysComparedWithPlan:
        plannedDate?.difference(bangkokLocalDay(estimatedDate)).inDays,
  );
}

WeeklyGoalLink? _buildGoalLink(
  WeeklyGoalInput goal,
  WeeklyExpenseComparison comparison, {
  required int currentWeeklySavingSatang,
}) {
  final metrics = calculateExpenseGoalLink(
    currentExpenseSatang: comparison.currentSatang,
    previousExpenseSatang: comparison.previousSatang,
    currentGoalSatang: goal.currentSatang,
    targetGoalSatang: goal.targetSatang,
    currentWeeklySavingSatang: currentWeeklySavingSatang,
  );
  if (metrics == null) return null;
  return WeeklyGoalLink(
    kind: metrics.needsSavingStart
        ? WeeklyGoalLinkKind.startSaving
        : metrics.expensesIncreased
            ? WeeklyGoalLinkKind.returnToPrevious
            : WeeklyGoalLinkKind.maintainReduction,
    goalId: goal.id,
    goalName: goal.name,
    observedDifferenceSatang: metrics.observedDifferenceSatang,
    daysSooner: metrics.daysSooner,
  );
}
