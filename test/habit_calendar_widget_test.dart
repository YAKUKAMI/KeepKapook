import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keepkapook/theme/app_theme.dart';
import 'package:keepkapook/utils/habit_streak.dart';
import 'package:keepkapook/widgets/habit_calendar_card.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('แสดง streak longest และสถานะผ่อนผันโดยไม่ลงโทษผู้ใช้',
      (tester) async {
    final activeDays = <DateTime>{
      DateTime(2026, 8, 1),
      DateTime(2026, 8, 2),
      DateTime(2026, 8, 3),
    };
    final summary = HabitStreakSummary(
      currentStreak: 3,
      longestStreak: 5,
      isGraceActive: true,
      activeDays: activeDays,
      latestActiveDay: DateTime(2026, 8, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HabitCalendarCard(
              summary: summary,
              entries: const <HabitEntry>[],
              today: DateTime(2026, 8, 4),
            ),
          ),
        ),
      ),
    );

    expect(find.text('3 วัน'), findsOneWidget);
    expect(find.text('ยาวที่สุด 5 วัน'), findsOneWidget);
    expect(find.textContaining('ผ่อนผันอยู่'), findsOneWidget);
    expect(find.textContaining('ล้มเหลว'), findsNothing);
  });

  testWidgets('แตะวันที่แล้วเห็นรายการของวันนั้น', (tester) async {
    final entry = HabitEntry(
      id: 'food',
      kind: HabitEntryKind.ledgerExpense,
      amountSatang: 5000,
      date: DateTime.utc(2026, 8, 3, 3),
      title: 'รายจ่าย · อาหาร',
      note: 'ข้าว',
    );
    final summary = HabitStreakSummary(
      currentStreak: 1,
      longestStreak: 1,
      isGraceActive: false,
      activeDays: <DateTime>{DateTime(2026, 8, 3)},
      latestActiveDay: DateTime(2026, 8, 3),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: HabitCalendarCard(
              summary: summary,
              entries: <HabitEntry>[entry],
              today: DateTime(2026, 8, 4),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('habit-day-2026-08-03')));
    await tester.pumpAndSettle();

    expect(find.text('รายจ่าย · อาหาร'), findsOneWidget);
    expect(find.text('ข้าว'), findsOneWidget);
    expect(find.textContaining('฿50'), findsOneWidget);
  });
}
