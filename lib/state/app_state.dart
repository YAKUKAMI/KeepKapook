import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/financial_summary.dart';
import '../utils/format.dart';
import '../utils/habit_streak.dart';
import '../utils/next_goal_offer.dart';
import '../utils/parser/parser.dart';
import '../utils/quick_entry.dart';
import '../utils/weekly_review.dart';
import 'backup.dart';
import 'domain_validation.dart';
import 'migrations.dart';

export 'domain_validation.dart';

part 'conversational_entries.dart';
part 'next_goal_actions.dart';
part 'quick_entries.dart';
part 'weekly_reviews.dart';

const appStateStorageKey = 'keepkapook_state_v1';
const appStateCorruptBackupKey = '${appStateStorageKey}_corrupt_backup';
const appStatePreImportBackupKey = '${appStateStorageKey}_pre_import_backup';
const _uuid = Uuid();

Map<String, dynamic> _jsonObject(Object? value) {
  if (value == null) return <String, dynamic>{};
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('ข้อมูลต้องเป็น JSON object');
}

List<T> _jsonList<T>(
  Object? value,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (value == null) return <T>[];
  if (value is! List) throw const FormatException('ข้อมูลต้องเป็น JSON array');
  return value.map((entry) => fromJson(_jsonObject(entry))).toList();
}

class SavingResult {
  final int exp;
  final Goal? completed;
  final int overflowSatang;
  SavingResult(this.exp, this.completed, this.overflowSatang);
}

class AppState extends ChangeNotifier {
  AppState({Future<bool> Function(String raw)? stateWriter})
      : _stateWriter = stateWriter;

  static const Duration _saveDebounceDuration = Duration(milliseconds: 300);

  final Future<bool> Function(String raw)? _stateWriter;
  Timer? _saveDebounce;
  Future<void> _saveQueue = Future<void>.value();
  String? _pendingSaveSnapshot;
  bool _disposed = false;

  AppUser user = AppUser();
  List<Goal> goals = [];
  List<SavingTransaction> transactions = [];
  List<Quest> quests = [];
  List<AchievementBadge> badges = [];
  List<LedgerEntry> ledger = [];
  int unallocatedSatang = 0;
  bool loaded = false;
  String? loadErrorMessage;
  int _recordSavedSerial = 0;

  int get recordSavedSerial => _recordSavedSerial;

  // ---------- persistence ----------
  Future<void> load() async {
    SharedPreferences? prefs;
    String? raw;
    loadErrorMessage = null;

    try {
      prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(appStateStorageKey);
      if (raw == null) {
        _initEmpty();
      } else {
        final decoded = jsonDecode(raw);
        final rawState = _jsonObject(decoded);
        final fromVersion = readSchemaVersion(rawState);
        final migrated = migrateState(rawState, fromVersion);
        _fromJson(migrated, hydrateCurrentDefinitions: true);

        final needsRewrite = !rawState.containsKey('schemaVersion') ||
            fromVersion != currentSchemaVersion;
        if (needsRewrite) {
          try {
            await prefs.setString(appStateStorageKey, jsonEncode(toJson()));
          } catch (_) {
            loadErrorMessage =
                'โหลดข้อมูลสำเร็จ แต่ยังอัปเดตรูปแบบจัดเก็บไม่ได้ กรุณาลองเปิดแอปใหม่';
          }
        }
      }
    } on UnsupportedSchemaVersionException {
      await _recoverFromLoadFailure(prefs, raw, newerVersion: true);
    } catch (_) {
      await _recoverFromLoadFailure(prefs, raw, newerVersion: false);
    }

    loaded = true;
    notifyListeners();
  }

  Future<void> _recoverFromLoadFailure(
    SharedPreferences? prefs,
    String? raw, {
    required bool newerVersion,
  }) async {
    var backupSaved = false;
    if (prefs != null && raw != null) {
      try {
        backupSaved = await prefs.setString(appStateCorruptBackupKey, raw);
      } catch (_) {
        backupSaved = false;
      }
    }

    _initEmpty();
    final backupText = backupSaved
        ? 'ระบบเก็บสำเนาข้อมูลเดิมไว้แล้ว'
        : 'ระบบไม่สามารถเก็บสำเนาข้อมูลเดิมได้';
    loadErrorMessage = newerVersion
        ? 'ข้อมูลในเครื่องสร้างด้วยแอปเวอร์ชันใหม่กว่า จึงยังโหลดไม่ได้ '
            'กรุณาอัปเดตแอป $backupText'
        : 'โหลดข้อมูลไม่สำเร็จ $backupText และเริ่มแอปด้วยข้อมูลว่าง';
  }

  void clearLoadErrorMessage() {
    if (loadErrorMessage == null) return;
    loadErrorMessage = null;
    notifyListeners();
  }

  void _save() {
    _pendingSaveSnapshot = jsonEncode(toJson());
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDuration, _enqueuePendingSave);
  }

  void _enqueuePendingSave() {
    final snapshot = _pendingSaveSnapshot;
    if (snapshot == null) return;
    _pendingSaveSnapshot = null;
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _saveQueue = _saveQueue.then((_) => _writeSnapshot(snapshot));
  }

  Future<void> _writeSnapshot(String snapshot) async {
    try {
      final writer = _stateWriter;
      final saved = writer != null
          ? await writer(snapshot)
          : await (await SharedPreferences.getInstance()).setString(
              appStateStorageKey,
              snapshot,
            );
      if (!saved) throw StateError('SharedPreferences ปฏิเสธการเขียนข้อมูล');
    } catch (_) {
      loadErrorMessage =
          'บันทึกข้อมูลล่าสุดไม่สำเร็จ กรุณาอย่าปิดแอปและลองทำรายการอีกครั้ง';
      if (!_disposed) notifyListeners();
    }
  }

  /// รอให้ snapshot ล่าสุดเขียนเสร็จ ใช้ก่อน side effect ที่ต้องเห็น state ล่าสุด
  /// และใช้เป็น test seam ของ debounce/ordered queue
  Future<void> flushPendingSaves() async {
    _enqueuePendingSave();
    await _saveQueue;
  }

  void _saveAndNotify() {
    _save();
    notifyListeners();
  }

  Future<void> restoreBackup(BackupPreview backup) async {
    await flushPendingSaves();
    final prefs = await SharedPreferences.getInstance();
    final currentState = toJson();
    final currentRaw = jsonEncode(currentState);
    final backupSaved =
        await prefs.setString(appStatePreImportBackupKey, currentRaw);
    if (!backupSaved) {
      throw StateError('สำรองข้อมูลปัจจุบันก่อนกู้คืนไม่สำเร็จ');
    }

    try {
      _fromJson(backup.migratedState, hydrateCurrentDefinitions: true);
      final restoredRaw = jsonEncode(toJson());
      final restored = await prefs.setString(appStateStorageKey, restoredRaw);
      if (!restored) throw StateError('เขียนข้อมูลที่กู้คืนไม่สำเร็จ');
    } catch (_) {
      _fromJson(currentState);
      rethrow;
    }

    loaded = true;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'user': user.toJson(),
        'goals': goals.map((g) => g.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'quests': quests.map((q) => q.toJson()).toList(),
        'badges': badges.map((b) => b.toJson()).toList(),
        'ledger': ledger.map((e) => e.toJson()).toList(),
        'unallocatedSatang': unallocatedSatang,
      };

  void _fromJson(
    Map<String, dynamic> j, {
    bool hydrateCurrentDefinitions = false,
  }) {
    user = AppUser.fromJson(_jsonObject(j['user']));
    goals = _jsonList(j['goals'], Goal.fromJson);
    transactions = _jsonList(j['transactions'], SavingTransaction.fromJson);
    quests = _jsonList(j['quests'], Quest.fromJson);
    badges = _jsonList(j['badges'], AchievementBadge.fromJson);
    ledger = _jsonList(j['ledger'], LedgerEntry.fromJson);
    unallocatedSatang = j['unallocatedSatang'] as int? ?? 0;
    if (hydrateCurrentDefinitions) {
      _ensureGamificationDefinitions();
      _refreshHabitRewards(asOf: DateTime.now());
    }
  }

  @override
  void dispose() {
    _enqueuePendingSave();
    _disposed = true;
    super.dispose();
  }

  // ---------- ledger (รายรับ-รายจ่าย) ----------
  void addLedger(
    LedgerType type,
    num amountSatang,
    String category,
    String note, {
    DateTime? date,
  }) {
    final validatedAmountSatang = validateMoneyAmountSatang(amountSatang);
    final recordedAt = (date ?? DateTime.now()).toUtc();
    ledger.insert(
      0,
      LedgerEntry(
        id: _uuid.v4(),
        type: type,
        amountSatang: validatedAmountSatang,
        category: category,
        note: note,
        date: recordedAt,
      ),
    );
    _refreshHabitRewards(asOf: recordedAt);
    _recordSavedSerial++;
    _saveAndNotify();
  }

  void deleteLedger(String id) {
    final index = ledger.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      throw DomainValidationException.missingEntity('รายการบัญชี', id);
    }
    ledger.removeAt(index);
    _refreshHabitRewards(asOf: DateTime.now());
    _saveAndNotify();
  }

  LedgerPeriodSummary ledgerMonthSummary({required DateTime now}) =>
      summarizeLedgerMonth(ledger, now: now);
  int get monthIncomeSatang =>
      ledgerMonthSummary(now: DateTime.now()).incomeSatang;
  int get monthExpenseSatang =>
      ledgerMonthSummary(now: DateTime.now()).expenseSatang;

  // ---------- pocket / transfer / lock / shared ----------
  Goal? _goalById(String id) =>
      goals.where((goal) => goal.id == id).firstOrNull;

  Goal _requireGoal(String id) {
    final goal = _goalById(id);
    if (goal == null) throw DomainValidationException.missingGoal(id);
    return goal;
  }

  Goal createPocket({
    required String name,
    String emoji = '👛',
    int themeColor = 0xFF176B58,
  }) {
    final g = Goal(
      id: 'p-${_uuid.v4()}',
      name: name,
      targetSatang: 0,
      startDate: DateTime.now(),
      targetDate: DateTime.now().add(const Duration(days: 365)),
      emoji: emoji,
      themeColor: themeColor,
      flexible: true,
    );
    goals.insert(0, g);
    _save();
    notifyListeners();
    return g;
  }

  void withdrawFromGoal(
    String id,
    num amountSatang, {
    bool toUnallocated = true,
  }) {
    final validatedAmountSatang = validateMoneyAmountSatang(amountSatang);
    final g = _requireGoal(id);
    if (g.isLockedNow) return;
    final takeSatang = validatedAmountSatang > g.currentSatang
        ? g.currentSatang
        : validatedAmountSatang;
    if (takeSatang <= 0) return;
    g.currentSatang -= takeSatang;
    if (g.flexible) {
      g.status = GoalStatus.active;
      g.completedDate = null;
    } else if (g.isCompleted && g.currentSatang < g.targetSatang) {
      g.status = GoalStatus.active;
      g.completedDate = null;
    }
    if (toUnallocated) unallocatedSatang += takeSatang;
    transactions.insert(
      0,
      SavingTransaction(
        id: _uuid.v4(),
        type: toUnallocated ? TxType.deallocate : TxType.withdraw,
        amountSatang: takeSatang,
        date: DateTime.now(),
        goalId: id,
        sourceGoalNameSnapshot: g.name,
      ),
    );
    _save();
    notifyListeners();
  }

  void transfer(String fromId, String toId, num amountSatang) {
    final validatedAmountSatang = validateMoneyAmountSatang(amountSatang);
    if (fromId == toId) {
      throw DomainValidationException.sameGoalTransfer();
    }
    final from = _requireGoal(fromId);
    final to = _requireGoal(toId);
    if (from.isLockedNow) return;
    var moveSatang = validatedAmountSatang > from.currentSatang
        ? from.currentSatang
        : validatedAmountSatang;
    final spaceSatang = to.flexible ? moveSatang : to.remainingSatang;
    moveSatang = moveSatang > spaceSatang ? spaceSatang : moveSatang;
    if (moveSatang <= 0) return;
    from.currentSatang -= moveSatang;
    to.currentSatang += moveSatang;
    if (from.flexible) {
      from.status = GoalStatus.active;
      from.completedDate = null;
    }
    if (to.flexible) {
      to.status = GoalStatus.active;
      to.completedDate = null;
    } else if (to.hasSavingsTarget && to.currentSatang >= to.targetSatang) {
      to.status = GoalStatus.completed;
      to.completedDate = DateTime.now();
    }
    _recordReachedMilestone(to);
    final now = DateTime.now();
    transactions.insert(
      0,
      SavingTransaction(
        id: _uuid.v4(),
        type: TxType.transfer,
        amountSatang: moveSatang,
        date: now,
        goalId: fromId,
        destinationGoalId: toId,
        sourceGoalNameSnapshot: from.name,
        destinationGoalNameSnapshot: to.name,
      ),
    );
    _save();
    notifyListeners();
  }

  void setLock(String id, DateTime? until) {
    final g = _requireGoal(id);
    g.locked = until != null;
    g.lockUntil = until;
    _save();
    notifyListeners();
  }

  void toggleShared(String id, bool shared, List<String> members) {
    final g = _requireGoal(id);
    g.shared = shared;
    g.members = members;
    _save();
    notifyListeners();
  }

  // ---------- derived ----------
  GoalTotalsSummary get goalTotals => summarizeGoalTotals(goals);
  int get totalSavedSatang => goalTotals.totalSavedSatang;
  int get targetedSavedSatang => goalTotals.targetedSavedSatang;
  int get grandTargetSatang => goalTotals.targetSatang;
  List<Goal> get activeGoals =>
      goals.where((goal) => !goal.isCompleted).toList();
  List<Goal> get completedGoals =>
      goals.where((goal) => goal.isCompleted).toList();
  List<HabitEntry> get habitEntries => collectHabitEntries(
        ledger: ledger,
        transactions: transactions,
      );
  HabitStreakSummary habitSummary({required DateTime now}) =>
      summarizeHabitEntries(habitEntries, asOf: now);

  // ---------- actions ----------
  Goal addGoal({
    required String name,
    required num targetSatang,
    required DateTime targetDate,
    String emoji = '🎯',
    GoalCategory category = GoalCategory.other,
    int themeColor = 0xFF52C7A5,
  }) {
    final validatedTargetSatang = validateMoneyAmountSatang(
      targetSatang,
      fieldName: 'targetSatang',
    );
    final g = Goal(
      id: 'g-${_uuid.v4()}',
      name: name,
      targetSatang: validatedTargetSatang,
      startDate: DateTime.now(),
      targetDate: targetDate,
      emoji: emoji,
      category: category,
      themeColor: themeColor,
    );
    goals.insert(0, g);
    _save();
    notifyListeners();
    return g;
  }

  void updateGoal(Goal g) {
    _requireGoal(g.id);
    if (g.flexible) {
      g.status = GoalStatus.active;
      g.completedDate = null;
    } else if (g.hasSavingsTarget && g.currentSatang >= g.targetSatang) {
      g.status = GoalStatus.completed;
      g.completedDate ??= DateTime.now();
    }
    _recordReachedMilestone(g);
    _save();
    notifyListeners();
  }

  void deleteGoal(String id) {
    final goal = _requireGoal(id);
    for (final transaction in transactions) {
      if (transaction.goalId == id) {
        transaction.sourceGoalNameSnapshot ??= goal.name;
      }
      if (transaction.destinationGoalId == id) {
        transaction.destinationGoalNameSnapshot ??= goal.name;
      }
    }
    goals.remove(goal);
    _save();
    notifyListeners();
  }

  /// เพิ่มเงินออม เข้ากระปุกเดียว หรือ (goalId == null) เข้ายังไม่จัดสรร
  SavingResult addSaving({
    required num amountSatang,
    String? goalId,
    String note = '',
    DateTime? date,
    TxType source = TxType.deposit,
  }) {
    final validatedAmountSatang = validateMoneyAmountSatang(amountSatang);
    final goal = goalId == null ? null : _requireGoal(goalId);
    if (transactionFlowForType(source) != TransactionFlow.externalIn) {
      throw DomainValidationException.operationNotAllowed(
        'addSaving รองรับเฉพาะเงินเข้าจากภายนอก',
      );
    }
    return _addSaving(
      amountSatang: validatedAmountSatang,
      goal: goal,
      note: note,
      date: date,
      source: source,
      persist: true,
    );
  }

  SavingResult _addSaving({
    required int amountSatang,
    required Goal? goal,
    String note = '',
    DateTime? date,
    TxType source = TxType.deposit,
    required bool persist,
  }) {
    final now = (date ?? DateTime.now()).toUtc();
    final transactionFlow = transactionFlowForType(source);
    var exp = transactionFlow == TransactionFlow.externalIn ? 10 : 0;
    int overflowSatang = 0;
    Goal? completed;
    var recordedExp = false;

    if (goal != null) {
      final g = goal;
      final spaceSatang = g.flexible ? amountSatang : g.remainingSatang;
      final putSatang = amountSatang < spaceSatang ? amountSatang : spaceSatang;
      overflowSatang = amountSatang - putSatang;
      g.currentSatang += putSatang;
      if (g.flexible) {
        g.status = GoalStatus.active;
        g.completedDate = null;
      } else {
        final after = g.progress;
        if (transactionFlow == TransactionFlow.externalIn) {
          exp += _awardNewMilestones(g);
        } else {
          _recordReachedMilestone(g);
        }
        if (after >= 1.0) {
          g.status = GoalStatus.completed;
          g.completedDate = now;
          completed = g;
        }
      }
      if (putSatang > 0) {
        transactions.insert(
          0,
          SavingTransaction(
            id: _uuid.v4(),
            type: source,
            amountSatang: putSatang,
            date: now,
            destinationGoalId: goal.id,
            destinationGoalNameSnapshot: goal.name,
            note: note,
            expAwarded: exp,
          ),
        );
        recordedExp = true;
      }
    } else {
      overflowSatang = amountSatang;
    }

    if (overflowSatang > 0) {
      unallocatedSatang += overflowSatang;
      if (transactionFlow == TransactionFlow.externalIn) {
        transactions.insert(
          0,
          SavingTransaction(
            id: _uuid.v4(),
            type: TxType.unallocated,
            amountSatang: overflowSatang,
            date: now,
            note: note,
            expAwarded: recordedExp ? 0 : exp,
          ),
        );
      }
    }

    if (transactionFlow == TransactionFlow.externalIn) {
      _progressQuest('q-deposit');
    }

    user.exp += exp;
    _refreshHabitRewards(asOf: now);
    if (persist) {
      _recordSavedSerial++;
      _save();
      notifyListeners();
    }
    return SavingResult(exp, completed, overflowSatang);
  }

  void allocateUnallocated(num amountSatang, String goalId) {
    final validatedAmountSatang = validateMoneyAmountSatang(amountSatang);
    final goal = _requireGoal(goalId);
    if (unallocatedSatang <= 0) return;
    final allocatedSatang = validatedAmountSatang > unallocatedSatang
        ? unallocatedSatang
        : validatedAmountSatang;
    unallocatedSatang -= allocatedSatang;
    _addSaving(
      amountSatang: allocatedSatang,
      goal: goal,
      source: TxType.allocate,
      persist: false,
    ); // overflow กลับเข้า pool เอง
    _progressQuest('q-allocate');
    _saveAndNotify();
  }

  void _progressQuest(String id) {
    final quest = quests.where((entry) => entry.id == id).firstOrNull;
    if (quest == null || quest.claimed) return;
    quest.progress = (quest.progress + 1).clamp(0, quest.target);
  }

  void _refreshHabitRewards({required DateTime asOf}) {
    final entries = habitEntries;
    final summary = summarizeHabitEntries(
      entries,
      asOf: latestHabitTimestamp(entries, fallback: asOf),
    );
    final quest =
        quests.where((entry) => entry.id == 'q-weekly-consistency').firstOrNull;
    if (quest != null && !quest.claimed) {
      final reached = habitProgressToward(summary, quest.target);
      if (reached > quest.progress) quest.progress = reached;
    }
    _recomputeBadges(habit: summary);
  }

  int _awardNewMilestones(Goal goal) {
    final before = goal.highestMilestonePercent;
    _recordReachedMilestone(goal);
    var exp = 0;
    for (final milestone in const <(int, int)>[
      (25, 20),
      (50, 30),
      (75, 40),
      (100, 100),
    ]) {
      if (milestone.$1 > before &&
          milestone.$1 <= goal.highestMilestonePercent) {
        exp += milestone.$2;
      }
    }
    return exp;
  }

  void _recordReachedMilestone(Goal goal) {
    if (!goal.hasSavingsTarget) return;
    for (final percent in const <int>[25, 50, 75, 100]) {
      if (goal.currentSatang * 100 >= goal.targetSatang * percent &&
          percent > goal.highestMilestonePercent) {
        goal.highestMilestonePercent = percent;
      }
    }
  }

  int claimQuest(String id) {
    final q = quests.where((quest) => quest.id == id).firstOrNull;
    if (q == null || q.claimed || !q.complete) return 0;
    q.claimed = true;
    user.exp += q.expReward;
    _save();
    notifyListeners();
    return q.expReward;
  }

  void setName(String name) {
    user.name = name;
    _save();
    notifyListeners();
  }

  void setMode(SaverMode mode) {
    user.mode = mode;
    _save();
    notifyListeners();
  }

  // เริ่มใช้งานครั้งแรก: ตั้งชื่อ+โหมด และสร้างกระปุกแรก
  void completeOnboarding({
    required String name,
    required SaverMode mode,
    required String goalName,
    required num targetSatang,
    required DateTime targetDate,
    String emoji = '🎯',
  }) {
    final validatedTargetSatang = validateMoneyAmountSatang(
      targetSatang,
      fieldName: 'targetSatang',
    );
    user.name = name;
    user.mode = mode;
    user.exp = 0;
    user.onboarded = true;
    goals = [];
    transactions = [];
    ledger = [];
    unallocatedSatang = 0;
    quests = _defaultQuests();
    badges = _defaultBadges();
    addGoal(
      name: goalName,
      targetSatang: validatedTargetSatang,
      targetDate: targetDate,
      emoji: emoji,
    );
  }

  void _recomputeBadges({HabitStreakSummary? habit}) {
    final habitSummaryValue = habit ?? habitSummary(now: DateTime.now());
    final completedCount = completedGoals.length;
    final anyHalf = goals.any(
      (goal) => goal.hasSavingsTarget && goal.progress >= 0.5,
    );
    for (final b in badges) {
      if (b.id == 'b-first-drop') {
        b.unlocked = b.unlocked || transactions.isNotEmpty;
        b.progress = b.unlocked ? 1 : 0;
      } else if (b.id == 'b-rhythm') {
        b.unlocked = b.unlocked || hasReachedHabitTarget(habitSummaryValue, 7);
        final recalculatedProgress = habitProgressRatio(habitSummaryValue, 7);
        if (recalculatedProgress > b.progress) {
          b.progress = recalculatedProgress;
        }
      } else if (b.id == 'b-halfway') {
        b.unlocked = b.unlocked || anyHalf;
        if (b.unlocked) b.progress = 1;
      } else if (b.id == 'b-crusher') {
        b.unlocked = b.unlocked || completedCount >= 1;
        if (b.unlocked) b.progress = 1;
      } else if (b.id == 'b-triple') {
        b.unlocked = b.unlocked || completedCount >= 3;
        final recalculatedProgress =
            (completedCount / 3).clamp(0, 1).toDouble();
        if (recalculatedProgress > b.progress) {
          b.progress = recalculatedProgress;
        }
      }
    }
  }

  int get level => levelFromExp(user.exp);
  int get dailyCapSatang => dailyDepositCapSatang(user.mode.name, level);

  // ล้างข้อมูลทั้งหมด → เริ่มใหม่ (ผ่าน onboarding)
  void resetDemo() {
    _initEmpty();
    _save();
    notifyListeners();
  }

  // สถานะเริ่มต้น: ว่างเปล่า ยังไม่ onboarded (ไม่มีข้อมูลตัวอย่าง)
  void _initEmpty() {
    user = AppUser(name: '', exp: 0, consistencyWeeks: 0, onboarded: false);
    goals = [];
    transactions = [];
    ledger = [];
    unallocatedSatang = 0;
    quests = _defaultQuests();
    badges = _defaultBadges();
    _recomputeBadges();
  }

  void _ensureGamificationDefinitions() {
    for (final definition in _defaultQuests()) {
      if (!quests.any((entry) => entry.id == definition.id)) {
        quests.add(definition);
      }
    }
    for (final definition in _defaultBadges()) {
      if (!badges.any((entry) => entry.id == definition.id)) {
        badges.add(definition);
      }
    }
  }

  List<Quest> _defaultQuests() => [
        Quest(
            id: 'q-deposit',
            title: 'บันทึกเงินออม',
            description: 'เพิ่มเงินเข้ากระปุกวันนี้',
            period: 'daily',
            target: 1,
            expReward: 15),
        Quest(
            id: 'q-allocate',
            title: 'จัดสรรเงิน',
            description: 'จัดสรรเงินที่ยังไม่เลือกเป้าหมาย',
            period: 'daily',
            target: 1,
            expReward: 15),
        Quest(
            id: 'q-weekly-consistency',
            title: 'รักษาความสม่ำเสมอ',
            description: 'บันทึกต่อเนื่องให้ครบ 5 วัน',
            period: 'weekly',
            target: 5,
            expReward: 40),
        Quest(
            id: 'q-weekly-review',
            title: 'ทบทวนสัปดาห์',
            description: 'เปิดดูสรุปสัปดาห์ล่าสุด',
            period: 'weekly',
            target: 1,
            expReward: 25),
      ];

  List<AchievementBadge> _defaultBadges() => [
        AchievementBadge(
            id: 'b-first-drop',
            name: 'First Drop',
            description: 'ออมครั้งแรก',
            emoji: '💧',
            condition: 'บันทึกเงินออมครั้งแรก'),
        AchievementBadge(
            id: 'b-rhythm',
            name: '7-Day Rhythm',
            description: 'บันทึกต่อเนื่องครบ 7 วัน',
            emoji: '🎵',
            condition: 'ทำ streak จากวันบันทึกครบ 7 วัน'),
        AchievementBadge(
            id: 'b-halfway',
            name: 'Halfway Hero',
            description: 'กระปุกถึง 50%',
            emoji: '⛰️',
            condition: 'กระปุกใดถึง 50%'),
        AchievementBadge(
            id: 'b-crusher',
            name: 'Goal Crusher',
            description: 'สำเร็จเป้าหมายแรก',
            emoji: '🏆',
            condition: 'ทำเป้าหมายสำเร็จ 1 อัน'),
        AchievementBadge(
            id: 'b-triple',
            name: 'Triple Keeper',
            description: 'สำเร็จ 3 เป้าหมาย',
            emoji: '👑',
            condition: 'ทำเป้าหมายสำเร็จ 3 อัน'),
      ];
}
