import '../models/models.dart';

const Duration bangkokUtcOffset = Duration(hours: 7);

/// คืนวันตามเขตเวลาไทยโดยไม่พึ่ง timezone ของเครื่องที่รันเทส
///
/// timestamp ที่เป็น UTC จะถูกเลื่อนเป็น UTC+7 ก่อนตัดเวลา ส่วน timestamp
/// legacy ที่ไม่มี timezone ถือว่าเก็บเป็นเวลาไทยอยู่แล้ว
DateTime bangkokLocalDay(DateTime timestamp) {
  final bangkokTime =
      timestamp.isUtc ? timestamp.add(bangkokUtcOffset) : timestamp;
  return DateTime(bangkokTime.year, bangkokTime.month, bangkokTime.day);
}

enum HabitEntryKind { ledgerIncome, ledgerExpense, goalSaving }

class HabitEntry {
  const HabitEntry({
    required this.id,
    required this.kind,
    required this.amountSatang,
    required this.date,
    required this.title,
    this.note = '',
  });

  final String id;
  final HabitEntryKind kind;
  final int amountSatang;
  final DateTime date;
  final String title;
  final String note;
}

List<HabitEntry> collectHabitEntries({
  required Iterable<LedgerEntry> ledger,
  required Iterable<SavingTransaction> transactions,
}) {
  final entries = <HabitEntry>[
    for (final entry in ledger)
      HabitEntry(
        id: entry.id,
        kind: entry.type == LedgerType.income
            ? HabitEntryKind.ledgerIncome
            : HabitEntryKind.ledgerExpense,
        amountSatang: entry.amountSatang,
        date: entry.date,
        title: entry.type == LedgerType.income
            ? 'รายรับ · ${entry.category}'
            : 'รายจ่าย · ${entry.category}',
        note: entry.note,
      ),
    for (final transaction in transactions)
      if (transaction.flow == TransactionFlow.externalIn &&
          transaction.destinationGoalId != null)
        HabitEntry(
          id: transaction.id,
          kind: HabitEntryKind.goalSaving,
          amountSatang: transaction.amountSatang,
          date: transaction.date,
          title:
              'ออมเข้า ${transaction.destinationGoalNameSnapshot ?? 'เป้าหมาย'}',
          note: transaction.note,
        ),
  ];
  entries.sort((left, right) => left.date.compareTo(right.date));
  return List<HabitEntry>.unmodifiable(entries);
}

DateTime latestHabitTimestamp(
  Iterable<HabitEntry> entries, {
  required DateTime fallback,
}) {
  var latest = fallback;
  for (final entry in entries) {
    if (entry.date.isAfter(latest)) latest = entry.date;
  }
  return latest;
}

class HabitStreakSummary {
  const HabitStreakSummary({
    required this.currentStreak,
    required this.longestStreak,
    required this.isGraceActive,
    required this.activeDays,
    this.latestActiveDay,
  });

  final int currentStreak;
  final int longestStreak;
  final bool isGraceActive;
  final Set<DateTime> activeDays;
  final DateTime? latestActiveDay;

  HabitStreakStatus get status {
    if (isGraceActive) return HabitStreakStatus.grace;
    if (currentStreak > 0) return HabitStreakStatus.active;
    if (longestStreak > 0) return HabitStreakStatus.restart;
    return HabitStreakStatus.empty;
  }
}

enum HabitStreakStatus { empty, active, grace, restart }

HabitStreakSummary calculateHabitStreak(
  Iterable<DateTime> timestamps, {
  required DateTime asOf,
}) {
  final today = bangkokLocalDay(asOf);
  final activeDays = timestamps
      .map(bangkokLocalDay)
      .where((day) => !day.isAfter(today))
      .toSet()
      .toList()
    ..sort();
  if (activeDays.isEmpty) {
    return const HabitStreakSummary(
      currentStreak: 0,
      longestStreak: 0,
      isGraceActive: false,
      activeDays: <DateTime>{},
    );
  }

  var run = 0;
  var longest = 0;
  DateTime? previous;
  for (final day in activeDays) {
    final gap = previous == null ? 0 : day.difference(previous).inDays;
    run = previous == null || gap >= 3 ? 1 : run + 1;
    if (run > longest) longest = run;
    previous = day;
  }

  final latest = activeDays.last;
  final daysSinceLatest = today.difference(latest).inDays;
  return HabitStreakSummary(
    currentStreak: daysSinceLatest >= 2 ? 0 : run,
    longestStreak: longest,
    isGraceActive: daysSinceLatest == 1,
    activeDays: Set<DateTime>.unmodifiable(activeDays),
    latestActiveDay: latest,
  );
}

HabitStreakSummary summarizeHabitEntries(
  Iterable<HabitEntry> entries, {
  required DateTime asOf,
}) =>
    calculateHabitStreak(
      entries.map((entry) => entry.date),
      asOf: asOf,
    );

int habitProgressToward(HabitStreakSummary summary, int target) =>
    summary.longestStreak.clamp(0, target);

double habitProgressRatio(HabitStreakSummary summary, int target) =>
    target <= 0 ? 0 : (summary.longestStreak / target).clamp(0, 1);

bool hasReachedHabitTarget(HabitStreakSummary summary, int target) =>
    target > 0 && summary.longestStreak >= target;

class HabitCalendarDay {
  const HabitCalendarDay({required this.date, required this.hasActivity});

  final DateTime date;
  final bool hasActivity;
}

class HabitMonth {
  const HabitMonth({
    required this.month,
    required this.leadingEmptyDays,
    required this.days,
  });

  final DateTime month;
  final int leadingEmptyDays;
  final List<HabitCalendarDay> days;
}

DateTime habitMonthFor(DateTime date) {
  final localDay = bangkokLocalDay(date);
  return DateTime(localDay.year, localDay.month);
}

DateTime shiftHabitMonth(DateTime month, int offset) =>
    DateTime(month.year, month.month + offset);

String habitDayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

HabitMonth buildHabitMonth({
  required DateTime month,
  required Set<DateTime> activeDays,
}) {
  final normalizedMonth = DateTime(month.year, month.month);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final normalizedActiveDays = activeDays.map(bangkokLocalDay).toSet();
  return HabitMonth(
    month: normalizedMonth,
    leadingEmptyDays: normalizedMonth.weekday - DateTime.monday,
    days: List<HabitCalendarDay>.unmodifiable(
      List<HabitCalendarDay>.generate(daysInMonth, (index) {
        final day = DateTime(month.year, month.month, index + 1);
        return HabitCalendarDay(
          date: day,
          hasActivity: normalizedActiveDays.contains(day),
        );
      }),
    ),
  );
}

List<HabitEntry> habitEntriesForDay(
  Iterable<HabitEntry> entries,
  DateTime day,
) {
  final normalizedDay = bangkokLocalDay(day);
  return entries
      .where((entry) => bangkokLocalDay(entry.date) == normalizedDay)
      .toList(growable: false)
    ..sort((left, right) => right.date.compareTo(left.date));
}
