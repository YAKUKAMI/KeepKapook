part of 'app_state.dart';

extension WeeklyReviewState on AppState {
  List<WeeklyGoalInput> get weeklyGoalInputs =>
      goals.map(WeeklyGoalInput.fromGoal).toList(growable: false);

  DateTime? get firstUseAt => deriveFirstUseAt(
        goals: weeklyGoalInputs,
        ledger: ledger,
        transactions: transactions,
      );

  List<WeeklyReviewPeriod> weeklyReviewPeriods({required DateTime now}) {
    final firstUse = firstUseAt;
    if (firstUse == null) return const <WeeklyReviewPeriod>[];
    return availableWeeklyReviewPeriods(firstUseAt: firstUse, asOf: now);
  }

  WeeklyReport weeklyReportFor(WeeklyReviewPeriod period) => buildWeeklyReport(
        ledger: ledger,
        transactions: transactions,
        goals: weeklyGoalInputs,
        period: period,
      );

  void completeWeeklyReview() {
    _progressQuest('q-weekly-review');
    _saveAndNotify();
  }
}
