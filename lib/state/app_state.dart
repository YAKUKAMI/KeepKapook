import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../utils/parser/parser.dart';
import 'backup.dart';
import 'domain_validation.dart';
import 'migrations.dart';

export 'domain_validation.dart';

part 'conversational_entries.dart';

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
        _fromJson(migrated);

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
      _fromJson(backup.migratedState);
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

  void _fromJson(Map<String, dynamic> j) {
    user = AppUser.fromJson(_jsonObject(j['user']));
    goals = _jsonList(j['goals'], Goal.fromJson);
    transactions = _jsonList(j['transactions'], SavingTransaction.fromJson);
    quests = _jsonList(j['quests'], Quest.fromJson);
    badges = _jsonList(j['badges'], AchievementBadge.fromJson);
    ledger = _jsonList(j['ledger'], LedgerEntry.fromJson);
    if (quests.isEmpty) quests = _defaultQuests();
    if (badges.isEmpty) badges = _defaultBadges();
    unallocatedSatang = j['unallocatedSatang'] as int? ?? 0;
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
    String note,
  ) {
    final validatedAmountSatang = validateMoneyAmountSatang(amountSatang);
    ledger.insert(
      0,
      LedgerEntry(
        id: _uuid.v4(),
        type: type,
        amountSatang: validatedAmountSatang,
        category: category,
        note: note,
        date: DateTime.now().toUtc(),
      ),
    );
    _save();
    notifyListeners();
  }

  void deleteLedger(String id) {
    final index = ledger.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      throw DomainValidationException.missingEntity('รายการบัญชี', id);
    }
    ledger.removeAt(index);
    _save();
    notifyListeners();
  }

  int get monthIncomeSatang => _monthSumSatang(LedgerType.income);
  int get monthExpenseSatang => _monthSumSatang(LedgerType.expense);

  int _monthSumSatang(LedgerType t) {
    final now = DateTime.now();
    return ledger.where((e) {
      final localDate = e.date.toLocal();
      return e.type == t &&
          localDate.year == now.year &&
          localDate.month == now.month;
    }).fold<int>(0, (sum, entry) => sum + entry.amountSatang);
  }

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
        type: TxType.withdraw,
        amountSatang: takeSatang,
        date: DateTime.now(),
        goalId: id,
        note: 'ถอนออก',
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
    final now = DateTime.now();
    transactions.insert(
      0,
      SavingTransaction(
        id: _uuid.v4(),
        type: TxType.transfer,
        amountSatang: moveSatang,
        date: now,
        goalId: fromId,
        note: 'โอนไป ${to.name}',
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
  int get totalSavedSatang =>
      goals.fold<int>(0, (sum, goal) => sum + goal.currentSatang);
  int get targetedSavedSatang => goals
      .where((goal) => goal.hasSavingsTarget)
      .fold<int>(0, (sum, goal) => sum + goal.currentSatang);
  int get grandTargetSatang => goals
      .where((goal) => goal.hasSavingsTarget)
      .fold<int>(0, (sum, goal) => sum + goal.targetSatang);
  List<Goal> get activeGoals =>
      goals.where((goal) => !goal.isCompleted).toList();
  List<Goal> get completedGoals =>
      goals.where((goal) => goal.isCompleted).toList();

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
    _save();
    notifyListeners();
  }

  void deleteGoal(String id) {
    final goal = _requireGoal(id);
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
    int exp = 0;
    int overflowSatang = 0;
    Goal? completed;

    if (goal != null) {
      final g = goal;
      final spaceSatang = g.flexible ? amountSatang : g.remainingSatang;
      final putSatang = amountSatang < spaceSatang ? amountSatang : spaceSatang;
      overflowSatang = amountSatang - putSatang;
      final before = g.flexible ? 0.0 : g.progress;
      g.currentSatang += putSatang;
      if (g.flexible) {
        g.status = GoalStatus.active;
        g.completedDate = null;
      } else {
        final after = g.progress;
        final milestones = {0.25: 20, 0.5: 30, 0.75: 40, 1.0: 100};
        milestones.forEach((m, e) {
          if (before < m && after >= m) exp += e;
        });
        if (after >= 1.0) {
          g.status = GoalStatus.completed;
          g.completedDate = now;
          completed = g;
        }
      }
      exp += 10; // base
      transactions.insert(
        0,
        SavingTransaction(
          id: _uuid.v4(),
          type: source,
          amountSatang: putSatang,
          date: now,
          goalId: goal.id,
          note: note,
          expAwarded: exp,
        ),
      );
    } else {
      overflowSatang = amountSatang;
    }

    if (overflowSatang > 0) {
      unallocatedSatang += overflowSatang;
      transactions.insert(
        0,
        SavingTransaction(
          id: _uuid.v4(),
          type: TxType.unallocated,
          amountSatang: overflowSatang,
          date: now,
          note: goal != null ? 'ส่วนเกินจากกระปุกที่เต็ม' : note,
        ),
      );
    }

    // quest: บันทึกเงินออม
    for (final q in quests) {
      if (q.id == 'q-deposit' && !q.claimed && goal != null) {
        q.progress = (q.progress + 1).clamp(0, q.target);
      }
    }

    user.exp += exp;
    _recomputeBadges();
    if (persist) {
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
      persist: true,
    ); // overflow กลับเข้า pool เอง
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

  void _recomputeBadges() {
    final completedCount = completedGoals.length;
    final anyHalf = goals.any(
      (goal) => goal.hasSavingsTarget && goal.progress >= 0.5,
    );
    for (final b in badges) {
      if (b.id == 'b-first-drop') {
        b.unlocked = transactions.isNotEmpty;
        b.progress = b.unlocked ? 1 : 0;
      } else if (b.id == 'b-halfway') {
        b.unlocked = anyHalf;
        if (anyHalf) b.progress = 1;
      } else if (b.id == 'b-crusher') {
        b.unlocked = completedCount >= 1;
        b.progress = completedCount.clamp(0, 1).toDouble();
      } else if (b.id == 'b-triple') {
        b.unlocked = completedCount >= 3;
        b.progress = (completedCount / 3).clamp(0, 1);
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
            id: 'q-weekly-review',
            title: 'ทบทวนเป้าหมาย',
            description: 'เปิดดูกระปุก 3 ครั้งสัปดาห์นี้',
            period: 'weekly',
            target: 3,
            expReward: 40),
        Quest(
            id: 'q-weekly-consistency',
            title: 'รักษาความสม่ำเสมอ',
            description: 'ออมตามแผน 5 ครั้งสัปดาห์นี้',
            period: 'weekly',
            target: 5,
            expReward: 40),
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
            description: 'ทำตามแผน 7 ครั้ง',
            emoji: '🎵',
            condition: 'ออมตามแผน 7 ครั้ง'),
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
        AchievementBadge(
            id: 'b-memory',
            name: 'Memory Maker',
            description: 'เพิ่มรูป 10 รูป',
            emoji: '📸',
            condition: 'เพิ่มรูปใน Album 10 รูป'),
      ];
}
