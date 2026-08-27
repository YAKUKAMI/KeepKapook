import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'invariant_test_support.dart';

void main() {
  configureInvariantTestEnvironment();

  test('I8 every model survives exact JSON round trip', () {
    final ledger = LedgerEntry(
      id: 'ledger',
      type: LedgerType.expense,
      amountSatang: 12345,
      category: 'อาหาร',
      note: 'ข้าว',
      date: invariantTime,
    );
    final goal = Goal(
      id: 'goal',
      name: 'ทริป',
      description: 'รายละเอียด',
      targetSatang: 500000,
      currentSatang: 120000,
      startDate: invariantTime,
      targetDate: invariantTime.add(const Duration(days: 120)),
      category: GoalCategory.travel,
      priority: GoalPriority.high,
      emoji: '✈️',
      themeColor: 0xFF123456,
      locked: true,
      lockUntil: invariantTime.add(const Duration(days: 7)),
      shared: true,
      members: <String>['เมย์'],
    );
    final transaction = SavingTransaction(
      id: 'tx',
      type: TxType.deposit,
      amountSatang: 120000,
      date: invariantTime,
      goalId: 'goal',
      note: 'ออม',
      expAwarded: 10,
      isPossibleDuplicate: true,
    );
    final quest = Quest(
      id: 'quest',
      title: 'ภารกิจ',
      description: 'รายละเอียด',
      period: 'weekly',
      target: 5,
      progress: 3,
      expReward: 40,
      claimed: false,
    );
    final badge = AchievementBadge(
      id: 'badge',
      name: 'เหรียญ',
      description: 'รายละเอียด',
      emoji: '🏅',
      condition: 'เงื่อนไข',
      unlocked: true,
      progress: 0.75,
    );
    final user = AppUser(
      name: 'เมย์',
      emoji: '🐷',
      exp: 99,
      consistencyWeeks: 4,
      mode: SaverMode.child,
      onboarded: true,
    );

    expect(LedgerEntry.fromJson(ledger.toJson()).toJson(), ledger.toJson());
    expect(Goal.fromJson(goal.toJson()).toJson(), goal.toJson());
    expect(
      SavingTransaction.fromJson(transaction.toJson()).toJson(),
      transaction.toJson(),
    );
    expect(Quest.fromJson(quest.toJson()).toJson(), quest.toJson());
    expect(
      AchievementBadge.fromJson(badge.toJson()).toJson(),
      badge.toJson(),
    );
    expect(AppUser.fromJson(user.toJson()).toJson(), user.toJson());
  });

  test('I9 corrupt persisted JSON is backed up and never cleared silently',
      () async {
    const corruptJson = '{not valid JSON';
    SharedPreferences.setMockInitialValues(<String, Object>{
      appStateStorageKey: corruptJson,
    });
    final app = AppState();

    await app.load();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(appStateCorruptBackupKey), corruptJson);
    expect(app.loadErrorMessage, isNotNull);
    expect(app.loadErrorMessage, isNotEmpty);
    expect(app.loaded, isTrue);
  });
}
