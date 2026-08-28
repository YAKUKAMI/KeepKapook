import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/utils/habit_streak.dart';

DateTime _bangkokTimestamp(int year, int month, int day) =>
    DateTime.utc(year, month, day, 3);

void main() {
  group('habit streak', () {
    test('นับวันบันทึกต่อเนื่อง', () {
      final summary = calculateHabitStreak(
        <DateTime>[
          _bangkokTimestamp(2026, 8, 1),
          _bangkokTimestamp(2026, 8, 2),
          _bangkokTimestamp(2026, 8, 3),
        ],
        asOf: _bangkokTimestamp(2026, 8, 3),
      );

      expect(summary.currentStreak, 3);
      expect(summary.longestStreak, 3);
      expect(summary.isGraceActive, isFalse);
    });

    test('ขาด 1 วันไม่ตัดและไม่นับวันที่ขาดเป็นวัน streak', () {
      final summary = calculateHabitStreak(
        <DateTime>[
          _bangkokTimestamp(2026, 8, 1),
          _bangkokTimestamp(2026, 8, 3),
        ],
        asOf: _bangkokTimestamp(2026, 8, 3),
      );

      expect(summary.currentStreak, 2);
      expect(summary.longestStreak, 2);
    });

    test('วันที่ยังไม่บันทึกหลังวันล่าสุดแสดงสถานะผ่อนผัน', () {
      final summary = calculateHabitStreak(
        <DateTime>[
          _bangkokTimestamp(2026, 8, 1),
          _bangkokTimestamp(2026, 8, 2),
          _bangkokTimestamp(2026, 8, 3),
        ],
        asOf: _bangkokTimestamp(2026, 8, 4),
      );

      expect(summary.currentStreak, 3);
      expect(summary.isGraceActive, isTrue);
    });

    test('ขาด 2 วันติดกันตัด current แต่ไม่ลบ longest', () {
      final summary = calculateHabitStreak(
        <DateTime>[
          _bangkokTimestamp(2026, 8, 1),
          _bangkokTimestamp(2026, 8, 2),
          _bangkokTimestamp(2026, 8, 3),
        ],
        asOf: _bangkokTimestamp(2026, 8, 5),
      );

      expect(summary.currentStreak, 0);
      expect(summary.longestStreak, 3);
      expect(summary.isGraceActive, isFalse);
    });

    test('รายการใหม่หลังขาด 2 วันเริ่ม streak ใหม่', () {
      final summary = calculateHabitStreak(
        <DateTime>[
          _bangkokTimestamp(2026, 8, 1),
          _bangkokTimestamp(2026, 8, 4),
        ],
        asOf: _bangkokTimestamp(2026, 8, 4),
      );

      expect(summary.currentStreak, 1);
      expect(summary.longestStreak, 1);
    });

    test('นับต่อเนื่องข้ามเดือนได้', () {
      final summary = calculateHabitStreak(
        <DateTime>[
          _bangkokTimestamp(2026, 7, 31),
          _bangkokTimestamp(2026, 8, 1),
        ],
        asOf: _bangkokTimestamp(2026, 8, 1),
      );

      expect(summary.currentStreak, 2);
      expect(summary.longestStreak, 2);
    });

    test('นับต่อเนื่องข้ามปีได้', () {
      final summary = calculateHabitStreak(
        <DateTime>[
          _bangkokTimestamp(2026, 12, 31),
          _bangkokTimestamp(2027, 1, 1),
        ],
        asOf: _bangkokTimestamp(2027, 1, 1),
      );

      expect(summary.currentStreak, 2);
      expect(summary.longestStreak, 2);
    });

    test('บันทึกย้อนหลังแล้วคำนวณ streak ใหม่จาก timestamp ทั้งหมด', () {
      final before = calculateHabitStreak(
        <DateTime>[
          _bangkokTimestamp(2026, 8, 1),
          _bangkokTimestamp(2026, 8, 4),
        ],
        asOf: _bangkokTimestamp(2026, 8, 4),
      );
      final after = calculateHabitStreak(
        <DateTime>[
          _bangkokTimestamp(2026, 8, 1),
          _bangkokTimestamp(2026, 8, 2),
          _bangkokTimestamp(2026, 8, 4),
        ],
        asOf: _bangkokTimestamp(2026, 8, 4),
      );

      expect(before.currentStreak, 1);
      expect(after.currentStreak, 3);
    });

    test('ขอบเขตวันใช้เวลาไทยผ่าน helper กลาง', () {
      expect(
        bangkokLocalDay(DateTime.utc(2026, 8, 1, 16, 59)),
        DateTime(2026, 8, 1),
      );
      expect(
        bangkokLocalDay(DateTime.utc(2026, 8, 1, 17)),
        DateTime(2026, 8, 2),
      );
    });
  });

  test('วันที่บันทึกนับ ledger และ externalIn ที่เข้า goal เท่านั้น', () {
    final ledger = <LedgerEntry>[
      LedgerEntry(
        id: 'ledger',
        type: LedgerType.expense,
        amountSatang: 5000,
        category: 'อาหาร',
        date: _bangkokTimestamp(2026, 8, 1),
      ),
    ];
    final transactions = <SavingTransaction>[
      SavingTransaction(
        id: 'deposit',
        type: TxType.deposit,
        amountSatang: 10000,
        date: _bangkokTimestamp(2026, 8, 2),
        destinationGoalId: 'goal',
      ),
      SavingTransaction(
        id: 'unallocated',
        type: TxType.unallocated,
        amountSatang: 10000,
        date: _bangkokTimestamp(2026, 8, 3),
      ),
      SavingTransaction(
        id: 'transfer',
        type: TxType.transfer,
        amountSatang: 10000,
        date: _bangkokTimestamp(2026, 8, 4),
        goalId: 'goal-a',
        destinationGoalId: 'goal-b',
      ),
    ];

    final entries = collectHabitEntries(
      ledger: ledger,
      transactions: transactions,
    );

    expect(entries.map((entry) => entry.id), <String>['ledger', 'deposit']);
  });

  test('ปฏิทินรายเดือนระบายเฉพาะวันที่มีรายการ', () {
    final calendar = buildHabitMonth(
      month: DateTime(2026, 8),
      activeDays: <DateTime>{
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 31),
      },
    );

    expect(calendar.days, hasLength(31));
    expect(calendar.days.first.hasActivity, isTrue);
    expect(calendar.days[1].hasActivity, isFalse);
    expect(calendar.days.last.hasActivity, isTrue);
  });
}
