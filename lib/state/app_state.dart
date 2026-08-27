import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../utils/parser/parser.dart';
import 'backup.dart';
import 'migrations.dart';

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

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(appStateStorageKey, jsonEncode(toJson()));
  }

  void _saveAndNotify() {
    _save();
    notifyListeners();
  }

  Future<void> restoreBackup(BackupPreview backup) async {
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

  // ---------- ledger (รายรับ-รายจ่าย) ----------
  void addLedger(
    LedgerType type,
    int amountSatang,
    String category,
    String note,
  ) {
    if (amountSatang <= 0 || amountSatang > maxMoneyInputSatang) return;
    ledger.insert(
      0,
      LedgerEntry(
        id: _uuid.v4(),
        type: type,
        amountSatang: amountSatang,
        category: category,
        note: note,
        date: DateTime.now().toUtc(),
      ),
    );
    _save();
    notifyListeners();
  }

  void deleteLedger(String id) {
    ledger.removeWhere((e) => e.id == id);
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
    int amountSatang, {
    bool toUnallocated = true,
  }) {
    final g = goals.firstWhere((x) => x.id == id);
    if (g.isLockedNow) return;
    final takeSatang =
        amountSatang > g.currentSatang ? g.currentSatang : amountSatang;
    if (takeSatang <= 0) return;
    g.currentSatang -= takeSatang;
    if (g.status == GoalStatus.completed && g.currentSatang < g.targetSatang) {
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

  void transfer(String fromId, String toId, int amountSatang) {
    if (fromId == toId || amountSatang <= 0) return;
    final from = goals.firstWhere((x) => x.id == fromId);
    final to = goals.firstWhere((x) => x.id == toId);
    if (from.isLockedNow) return;
    var moveSatang =
        amountSatang > from.currentSatang ? from.currentSatang : amountSatang;
    final spaceSatang = to.flexible ? moveSatang : to.remainingSatang;
    moveSatang = moveSatang > spaceSatang ? spaceSatang : moveSatang;
    if (moveSatang <= 0) return;
    from.currentSatang -= moveSatang;
    to.currentSatang += moveSatang;
    if (to.targetSatang > 0 && to.currentSatang >= to.targetSatang) {
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
    final g = goals.firstWhere((x) => x.id == id);
    g.locked = until != null;
    g.lockUntil = until;
    _save();
    notifyListeners();
  }

  void toggleShared(String id, bool shared, List<String> members) {
    final g = goals.firstWhere((x) => x.id == id);
    g.shared = shared;
    g.members = members;
    _save();
    notifyListeners();
  }

  // ---------- derived ----------
  int get totalSavedSatang =>
      goals.fold<int>(0, (sum, goal) => sum + goal.currentSatang);
  int get grandTargetSatang =>
      goals.fold<int>(0, (sum, goal) => sum + goal.targetSatang);
  List<Goal> get activeGoals =>
      goals.where((g) => g.status == GoalStatus.active).toList();
  List<Goal> get completedGoals =>
      goals.where((g) => g.status == GoalStatus.completed).toList();

  // ---------- actions ----------
  Goal addGoal({
    required String name,
    required int targetSatang,
    required DateTime targetDate,
    String emoji = '🎯',
    GoalCategory category = GoalCategory.other,
    int themeColor = 0xFF52C7A5,
  }) {
    final g = Goal(
      id: 'g-${_uuid.v4()}',
      name: name,
      targetSatang: targetSatang,
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
    if (g.currentSatang >= g.targetSatang) {
      g.status = GoalStatus.completed;
      g.completedDate ??= DateTime.now();
    }
    _save();
    notifyListeners();
  }

  void deleteGoal(String id) {
    goals.removeWhere((g) => g.id == id);
    _save();
    notifyListeners();
  }

  /// เพิ่มเงินออม เข้ากระปุกเดียว หรือ (goalId == null) เข้ายังไม่จัดสรร
  SavingResult addSaving({
    required int amountSatang,
    String? goalId,
    String note = '',
    DateTime? date,
    TxType source = TxType.deposit,
  }) =>
      _addSaving(
        amountSatang: amountSatang,
        goalId: goalId,
        note: note,
        date: date,
        source: source,
        persist: true,
      );

  SavingResult _addSaving({
    required int amountSatang,
    String? goalId,
    String note = '',
    DateTime? date,
    TxType source = TxType.deposit,
    required bool persist,
  }) {
    if (amountSatang <= 0 || amountSatang > maxMoneyInputSatang) {
      return SavingResult(0, null, 0);
    }
    final now = (date ?? DateTime.now()).toUtc();
    int exp = 0;
    int overflowSatang = 0;
    Goal? completed;

    if (goalId != null) {
      final g = goals.firstWhere((x) => x.id == goalId);
      final spaceSatang = g.remainingSatang;
      final putSatang = amountSatang < spaceSatang ? amountSatang : spaceSatang;
      overflowSatang = amountSatang - putSatang;
      final before = g.progress;
      g.currentSatang += putSatang;
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
      exp += 10; // base
      transactions.insert(
        0,
        SavingTransaction(
          id: _uuid.v4(),
          type: source,
          amountSatang: putSatang,
          date: now,
          goalId: goalId,
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
          note: goalId != null ? 'ส่วนเกินจากกระปุกที่เต็ม' : note,
        ),
      );
    }

    // quest: บันทึกเงินออม
    for (final q in quests) {
      if (q.id == 'q-deposit' && !q.claimed && goalId != null) {
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

  void allocateUnallocated(int amountSatang, String goalId) {
    if (amountSatang <= 0) return;
    if (amountSatang > unallocatedSatang) {
      amountSatang = unallocatedSatang;
    }
    unallocatedSatang -= amountSatang;
    addSaving(
      amountSatang: amountSatang,
      goalId: goalId,
    ); // overflow กลับเข้า pool เอง
  }

  int claimQuest(String id) {
    final q = quests.firstWhere((x) => x.id == id,
        orElse: () => Quest(
            id: '',
            title: '',
            description: '',
            period: '',
            target: 1,
            expReward: 0));
    if (q.id.isEmpty || q.claimed || !q.complete) return 0;
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
    required int targetSatang,
    required DateTime targetDate,
    String emoji = '🎯',
  }) {
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
      targetSatang: targetSatang,
      targetDate: targetDate,
      emoji: emoji,
    );
  }

  void _recomputeBadges() {
    final completedCount = completedGoals.length;
    final anyHalf = goals.any((g) => g.progress >= 0.5);
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
