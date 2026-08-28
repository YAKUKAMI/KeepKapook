import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/habit_streak.dart';

class HabitCalendarCard extends StatefulWidget {
  const HabitCalendarCard({
    super.key,
    required this.summary,
    required this.entries,
    required this.today,
  });

  final HabitStreakSummary summary;
  final List<HabitEntry> entries;
  final DateTime today;

  @override
  State<HabitCalendarCard> createState() => _HabitCalendarCardState();
}

class _HabitCalendarCardState extends State<HabitCalendarCard> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = habitMonthFor(widget.today);
  }

  @override
  void didUpdateWidget(HabitCalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (habitMonthFor(oldWidget.today) != habitMonthFor(widget.today)) {
      _visibleMonth = habitMonthFor(widget.today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendar = buildHabitMonth(
      month: _visibleMonth,
      activeDays: widget.summary.activeDays,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0x1AFFC857),
                  shape: BoxShape.circle,
                ),
                child: const Text('🔥', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'สตรีคการบันทึก',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${widget.summary.currentStreak} วัน',
                      style: const TextStyle(
                        color: AppColors.deepGreen,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'ยาวที่สุด ${widget.summary.longestStreak} วัน',
                style: const TextStyle(
                  color: AppColors.mutedText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _HabitStatus(status: widget.summary.status),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton(
                tooltip: 'เดือนก่อนหน้า',
                onPressed: () => setState(
                  () => _visibleMonth = shiftHabitMonth(_visibleMonth, -1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  formatThaiMonthYear(calendar.month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'เดือนถัดไป',
                onPressed: () => setState(
                  () => _visibleMonth = shiftHabitMonth(_visibleMonth, 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final label in <String>[
                'จ',
                'อ',
                'พ',
                'พฤ',
                'ศ',
                'ส',
                'อา',
              ])
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: calendar.leadingEmptyDays + calendar.days.length,
            itemBuilder: (context, index) {
              if (index < calendar.leadingEmptyDays) {
                return const SizedBox.shrink();
              }
              final day = calendar.days[index - calendar.leadingEmptyDays];
              return _CalendarDay(
                key: Key('habit-day-${habitDayKey(day.date)}'),
                day: day,
                onTap: () => _showEntries(context, day.date),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEntries(BuildContext context, DateTime day) {
    final entries = habitEntriesForDay(widget.entries, day);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'รายการวันที่ ${formatThaiDate(day)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'วันนี้ยังไม่มีรายการ เริ่มบันทึกวันนี้ได้เลย',
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _entryIcon(entry.kind),
                          color: AppColors.deepGreen,
                        ),
                        title: Text(entry.title),
                        subtitle: entry.note.isEmpty ? null : Text(entry.note),
                        trailing: Text(
                          formatMoney(entry.amountSatang),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _entryIcon(HabitEntryKind kind) => switch (kind) {
        HabitEntryKind.ledgerIncome => Icons.south_west,
        HabitEntryKind.ledgerExpense => Icons.north_east,
        HabitEntryKind.goalSaving => Icons.savings_outlined,
      };
}

class _HabitStatus extends StatelessWidget {
  const _HabitStatus({required this.status});

  final HabitStreakStatus status;

  @override
  Widget build(BuildContext context) {
    final (text, color, background) = switch (status) {
      HabitStreakStatus.grace => (
          'ผ่อนผันอยู่ · กลับมาบันทึกวันนี้เพื่อรักษาจังหวะนะ',
          AppColors.deepGreen,
          const Color(0x33FFC857),
        ),
      HabitStreakStatus.restart => (
          'เริ่มใหม่วันนี้ได้เลย ทุกการบันทึกคือจังหวะใหม่',
          AppColors.deepGreen,
          const Color(0x1A52C7A5),
        ),
      HabitStreakStatus.active => (
          'เยี่ยมเลย วันนี้บันทึกแล้ว กลับมาอีกพรุ่งนี้นะ',
          AppColors.deepGreen,
          const Color(0x1A52C7A5),
        ),
      HabitStreakStatus.empty => (
          'เริ่มบันทึกรายการแรกวันนี้ได้เลย',
          AppColors.mutedText,
          const Color(0x0D6B7D78),
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    super.key,
    required this.day,
    required this.onTap,
  });

  final HabitCalendarDay day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: day.hasActivity ? AppColors.mint : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${day.date.day}',
            style: TextStyle(
              color: day.hasActivity ? AppColors.white : AppColors.darkText,
              fontWeight: day.hasActivity ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
