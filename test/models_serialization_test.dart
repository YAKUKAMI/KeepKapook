import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';

void main() {
  final at = DateTime.utc(2026, 8, 24, 12, 30);

  group('model JSON round-trip', () {
    test('LedgerEntry', () {
      final model = LedgerEntry(
        id: 'ledger-1',
        type: LedgerType.income,
        amountSatang: 125050,
        category: 'งานพิเศษ',
        note: 'งานวันหยุด',
        date: at,
      );

      expect(LedgerEntry.fromJson(model.toJson()).toJson(), model.toJson());
    });

    test('Goal', () {
      final model = Goal(
        id: 'goal-1',
        name: 'จักรยาน',
        description: 'จักรยานคันแรก',
        targetSatang: 1500000,
        currentSatang: 500000,
        startDate: at,
        targetDate: at.add(const Duration(days: 90)),
        category: GoalCategory.shopping,
        priority: GoalPriority.high,
        emoji: '🚲',
        themeColor: 0xFF123456,
        status: GoalStatus.completed,
        completedDate: at.add(const Duration(days: 30)),
        flexible: true,
        locked: true,
        lockUntil: at.add(const Duration(days: 7)),
        shared: true,
        members: ['นิด', 'หน่อย'],
        highestMilestonePercent: 75,
      );

      expect(Goal.fromJson(model.toJson()).toJson(), model.toJson());
    });

    test('SavingTransaction', () {
      final model = SavingTransaction(
        id: 'tx-1',
        type: TxType.slip,
        flow: TransactionFlow.externalIn,
        amountSatang: 25075,
        date: at,
        destinationGoalId: 'goal-1',
        note: 'จากสลิป',
        expAwarded: 30,
        isPossibleDuplicate: true,
      );

      expect(
        SavingTransaction.fromJson(model.toJson()).toJson(),
        model.toJson(),
      );
    });

    test('Quest', () {
      final model = Quest(
        id: 'quest-1',
        title: 'ออมวันนี้',
        description: 'ออมหนึ่งครั้ง',
        period: 'daily',
        target: 1,
        progress: 1,
        expReward: 15,
        claimed: true,
      );

      expect(Quest.fromJson(model.toJson()).toJson(), model.toJson());
    });

    test('AchievementBadge', () {
      final model = AchievementBadge(
        id: 'badge-1',
        name: 'First Drop',
        description: 'ออมครั้งแรก',
        emoji: '💧',
        condition: 'บันทึกเงินออมครั้งแรก',
        unlocked: true,
        progress: 1,
      );

      expect(
        AchievementBadge.fromJson(model.toJson()).toJson(),
        model.toJson(),
      );
    });

    test('AppUser', () {
      final model = AppUser(
        name: 'มีนา',
        emoji: '🐷',
        exp: 450,
        consistencyWeeks: 4,
        mode: SaverMode.child,
        onboarded: true,
      );

      expect(AppUser.fromJson(model.toJson()).toJson(), model.toJson());
    });
  });

  test('ทุก fromJson ใช้ default เมื่อ field หาย', () {
    expect(() => LedgerEntry.fromJson({}), returnsNormally);
    expect(() => Goal.fromJson({}), returnsNormally);
    expect(() => SavingTransaction.fromJson({}), returnsNormally);
    expect(() => Quest.fromJson({}), returnsNormally);
    expect(() => AchievementBadge.fromJson({}), returnsNormally);
    expect(() => AppUser.fromJson({}), returnsNormally);

    expect(Goal.fromJson({}).targetSatang, 0);
    expect(Goal.fromJson({}).highestMilestonePercent, 0);
    expect(SavingTransaction.fromJson({}).amountSatang, 0);
    expect(
      SavingTransaction.fromJson({}).flow,
      TransactionFlow.externalIn,
    );
    expect(Quest.fromJson({}).target, 1);
    expect(AppUser.fromJson({}).onboarded, isTrue);
  });
}
