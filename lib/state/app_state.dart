import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../utils/format.dart';

const _storageKey = 'keepkapook_state_v1';
const _uuid = Uuid();

class SavingResult {
  final int exp;
  final Goal? completed;
  final double overflow;
  SavingResult(this.exp, this.completed, this.overflow);
}

class AppState extends ChangeNotifier {
  AppUser user = AppUser();
  List<Goal> goals = [];
  List<SavingTransaction> transactions = [];
  List<Quest> quests = [];
  List<AchievementBadge> badges = [];
  List<LedgerEntry> ledger = [];
  double unallocated = 750;
  bool loaded = false;

  // ---------- persistence ----------
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        _fromJson(jsonDecode(raw));
      } catch (_) {
        _initEmpty();
      }
    } else {
      _initEmpty();
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_toJson()));
  }

  Map<String, dynamic> _toJson() => {
        'user': user.toJson(),
        'goals': goals.map((g) => g.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'quests': quests.map((q) => q.toJson()).toList(),
        'badges': badges.map((b) => b.toJson()).toList(),
        'ledger': ledger.map((e) => e.toJson()).toList(),
        'unallocated': unallocated,
      };

  void _fromJson(Map<String, dynamic> j) {
    user = AppUser.fromJson(j['user']);
    goals = (j['goals'] as List).map((e) => Goal.fromJson(e)).toList();
    transactions =
        (j['transactions'] as List).map((e) => SavingTransaction.fromJson(e)).toList();
    quests = ((j['quests'] as List?) ?? []).map((e) => Quest.fromJson(e)).toList();
    badges = ((j['badges'] as List?) ?? []).map((e) => AchievementBadge.fromJson(e)).toList();
    ledger = ((j['ledger'] as List?) ?? []).map((e) => LedgerEntry.fromJson(e)).toList();
    if (quests.isEmpty) quests = _defaultQuests();
    if (badges.isEmpty) badges = _defaultBadges();
    unallocated = (j['unallocated'] as num).toDouble();
  }

  // ---------- ledger (รายรับ-รายจ่าย) ----------
  void addLedger(LedgerType type, double amount, String category, String note) {
    ledger.insert(
      0,
      LedgerEntry(
        id: _uuid.v4(),
        type: type,
        amount: amount,
        category: category,
        note: note,
        date: DateTime.now(),
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

  double get monthIncome => _monthSum(LedgerType.income);
  double get monthExpense => _monthSum(LedgerType.expense);

  double _monthSum(LedgerType t) {
    final now = DateTime.now();
    return ledger
        .where((e) =>
            e.type == t && e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (s, e) => s + e.amount);
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
      targetAmount: 0,
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

  void withdrawFromGoal(String id, double amount, {bool toUnallocated = true}) {
    final g = goals.firstWhere((x) => x.id == id);
    if (g.isLockedNow) return;
    final take = amount > g.currentAmount ? g.currentAmount : amount;
    if (take <= 0) return;
    g.currentAmount -= take;
    if (g.status == GoalStatus.completed && g.currentAmount < g.targetAmount) {
      g.status = GoalStatus.active;
      g.completedDate = null;
    }
    if (toUnallocated) unallocated += take;
    transactions.insert(
      0,
      SavingTransaction(
        id: _uuid.v4(),
        type: TxType.withdraw,
        amount: take,
        date: DateTime.now(),
        goalId: id,
        note: 'ถอนออก',
      ),
    );
    _save();
    notifyListeners();
  }

  void transfer(String fromId, String toId, double amount) {
    if (fromId == toId || amount <= 0) return;
    final from = goals.firstWhere((x) => x.id == fromId);
    final to = goals.firstWhere((x) => x.id == toId);
    if (from.isLockedNow) return;
    var move = amount > from.currentAmount ? from.currentAmount : amount;
    final space = to.flexible ? move : to.remaining;
    move = move > space ? space : move;
    if (move <= 0) return;
    from.currentAmount -= move;
    to.currentAmount += move;
    if (to.targetAmount > 0 && to.currentAmount >= to.targetAmount) {
      to.status = GoalStatus.completed;
      to.completedDate = DateTime.now();
    }
    final now = DateTime.now();
    transactions.insert(0, SavingTransaction(id: _uuid.v4(), type: TxType.transfer, amount: move, date: now, goalId: fromId, note: 'โอนไป ${to.name}'));
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
  double get totalSaved => goals.fold(0.0, (s, g) => s + g.currentAmount);
  double get grandTarget => goals.fold(0.0, (s, g) => s + g.targetAmount);
  List<Goal> get activeGoals =>
      goals.where((g) => g.status == GoalStatus.active).toList();
  List<Goal> get completedGoals =>
      goals.where((g) => g.status == GoalStatus.completed).toList();

  // ---------- actions ----------
  Goal addGoal({
    required String name,
    required double target,
    required DateTime targetDate,
    String emoji = '🎯',
    GoalCategory category = GoalCategory.other,
    int themeColor = 0xFF52C7A5,
  }) {
    final g = Goal(
      id: 'g-${_uuid.v4()}',
      name: name,
      targetAmount: target,
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
    if (g.currentAmount >= g.targetAmount) {
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
    required double amount,
    String? goalId,
    String note = '',
    DateTime? date,
    TxType source = TxType.deposit,
  }) {
    final now = date ?? DateTime.now();
    int exp = 0;
    double overflow = 0;
    Goal? completed;

    if (goalId != null) {
      final g = goals.firstWhere((x) => x.id == goalId);
      final space = g.remaining;
      final put = amount < space ? amount : space;
      overflow = amount - put;
      final before = g.progress;
      g.currentAmount += put;
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
          amount: put,
          date: now,
          goalId: goalId,
          note: note,
          expAwarded: exp,
        ),
      );
    } else {
      overflow = amount;
    }

    if (overflow > 0) {
      unallocated += overflow;
      transactions.insert(
        0,
        SavingTransaction(
          id: _uuid.v4(),
          type: TxType.unallocated,
          amount: overflow,
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
    _save();
    notifyListeners();
    return SavingResult(exp, completed, overflow);
  }

  void allocateUnallocated(double amount, String goalId) {
    if (amount <= 0) return;
    if (amount > unallocated) amount = unallocated;
    unallocated -= amount;
    addSaving(amount: amount, goalId: goalId); // overflow กลับเข้า pool เอง
  }

  int claimQuest(String id) {
    final q = quests.firstWhere((x) => x.id == id,
        orElse: () => Quest(
            id: '', title: '', description: '', period: '', target: 1, expReward: 0));
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
    required double target,
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
    unallocated = 0;
    quests = _defaultQuests();
    badges = _defaultBadges();
    addGoal(name: goalName, target: target, targetDate: targetDate, emoji: emoji);
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
  double get dailyCap => dailyDepositCap(user.mode.name, level);

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
    unallocated = 0;
    quests = _defaultQuests();
    badges = _defaultBadges();
    _recomputeBadges();
  }

  List<Quest> _defaultQuests() => [
        Quest(id: 'q-deposit', title: 'บันทึกเงินออม', description: 'เพิ่มเงินเข้ากระปุกวันนี้', period: 'daily', target: 1, expReward: 15),
        Quest(id: 'q-allocate', title: 'จัดสรรเงิน', description: 'จัดสรรเงินที่ยังไม่เลือกเป้าหมาย', period: 'daily', target: 1, expReward: 15),
        Quest(id: 'q-weekly-review', title: 'ทบทวนเป้าหมาย', description: 'เปิดดูกระปุก 3 ครั้งสัปดาห์นี้', period: 'weekly', target: 3, expReward: 40),
        Quest(id: 'q-weekly-consistency', title: 'รักษาความสม่ำเสมอ', description: 'ออมตามแผน 5 ครั้งสัปดาห์นี้', period: 'weekly', target: 5, expReward: 40),
      ];

  List<AchievementBadge> _defaultBadges() => [
        AchievementBadge(id: 'b-first-drop', name: 'First Drop', description: 'ออมครั้งแรก', emoji: '💧', condition: 'บันทึกเงินออมครั้งแรก'),
        AchievementBadge(id: 'b-rhythm', name: '7-Day Rhythm', description: 'ทำตามแผน 7 ครั้ง', emoji: '🎵', condition: 'ออมตามแผน 7 ครั้ง'),
        AchievementBadge(id: 'b-halfway', name: 'Halfway Hero', description: 'กระปุกถึง 50%', emoji: '⛰️', condition: 'กระปุกใดถึง 50%'),
        AchievementBadge(id: 'b-crusher', name: 'Goal Crusher', description: 'สำเร็จเป้าหมายแรก', emoji: '🏆', condition: 'ทำเป้าหมายสำเร็จ 1 อัน'),
        AchievementBadge(id: 'b-triple', name: 'Triple Keeper', description: 'สำเร็จ 3 เป้าหมาย', emoji: '👑', condition: 'ทำเป้าหมายสำเร็จ 3 อัน'),
        AchievementBadge(id: 'b-memory', name: 'Memory Maker', description: 'เพิ่มรูป 10 รูป', emoji: '📸', condition: 'เพิ่มรูปใน Album 10 รูป'),
      ];
}
