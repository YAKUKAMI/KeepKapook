// Data models — ตรงกับเวอร์ชันเว็บ (lib/types.ts)

enum GoalCategory { shopping, education, travel, emergency, investment, other }

enum GoalPriority { low, medium, high }

enum GoalStatus { active, completed }

enum SaverMode { child, adult }

enum TxType { deposit, unallocated, withdraw, transfer, adjust, slip }

// รายรับ-รายจ่าย (แยกจากการออม)
enum LedgerType { income, expense }

class LedgerEntry {
  String id;
  LedgerType type;
  double amount;
  String category;
  String note;
  DateTime date;

  LedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note = '',
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: j['id'],
        type: LedgerType.values.byName(j['type']),
        amount: (j['amount'] as num).toDouble(),
        category: j['category'] ?? 'อื่น ๆ',
        note: j['note'] ?? '',
        date: DateTime.parse(j['date']),
      );
}

class Goal {
  String id;
  String name;
  String description;
  double targetAmount;
  double currentAmount;
  DateTime startDate;
  DateTime targetDate;
  GoalCategory category;
  GoalPriority priority;
  String emoji;
  int themeColor; // ARGB
  GoalStatus status;
  DateTime? completedDate;
  bool flexible; // Cloud Pocket: กระเป๋าใช้จ่าย ไม่ผูกเป้าหมาย
  bool locked; // ล็อกเงิน
  DateTime? lockUntil;
  bool shared; // ออมด้วยกัน
  List<String> members;

  Goal({
    required this.id,
    required this.name,
    this.description = '',
    required this.targetAmount,
    this.currentAmount = 0,
    required this.startDate,
    required this.targetDate,
    this.category = GoalCategory.other,
    this.priority = GoalPriority.medium,
    this.emoji = '🎯',
    this.themeColor = 0xFF52C7A5,
    this.status = GoalStatus.active,
    this.completedDate,
    this.flexible = false,
    this.locked = false,
    this.lockUntil,
    this.shared = false,
    List<String>? members,
  }) : members = members ?? [];

  double get progress =>
      targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0, 1);
  double get remaining => (targetAmount - currentAmount).clamp(0, double.infinity);
  bool get isLockedNow =>
      locked && (lockUntil == null || lockUntil!.isAfter(DateTime.now()));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'startDate': startDate.toIso8601String(),
        'targetDate': targetDate.toIso8601String(),
        'category': category.name,
        'priority': priority.name,
        'emoji': emoji,
        'themeColor': themeColor,
        'status': status.name,
        'completedDate': completedDate?.toIso8601String(),
        'flexible': flexible,
        'locked': locked,
        'lockUntil': lockUntil?.toIso8601String(),
        'shared': shared,
        'members': members,
      };

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: j['id'],
        name: j['name'],
        description: j['description'] ?? '',
        targetAmount: (j['targetAmount'] as num).toDouble(),
        currentAmount: (j['currentAmount'] as num).toDouble(),
        startDate: DateTime.parse(j['startDate']),
        targetDate: DateTime.parse(j['targetDate']),
        category: GoalCategory.values.byName(j['category']),
        priority: GoalPriority.values.byName(j['priority']),
        emoji: j['emoji'] ?? '🎯',
        themeColor: j['themeColor'] ?? 0xFF52C7A5,
        status: GoalStatus.values.byName(j['status']),
        completedDate: j['completedDate'] != null
            ? DateTime.parse(j['completedDate'])
            : null,
        flexible: j['flexible'] ?? false,
        locked: j['locked'] ?? false,
        lockUntil:
            j['lockUntil'] != null ? DateTime.parse(j['lockUntil']) : null,
        shared: j['shared'] ?? false,
        members: (j['members'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class SavingTransaction {
  String id;
  TxType type;
  double amount;
  DateTime date;
  String? goalId;
  String note;
  int expAwarded;
  bool isPossibleDuplicate;

  SavingTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.goalId,
    this.note = '',
    this.expAwarded = 0,
    this.isPossibleDuplicate = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'date': date.toIso8601String(),
        'goalId': goalId,
        'note': note,
        'expAwarded': expAwarded,
        'isPossibleDuplicate': isPossibleDuplicate,
      };

  factory SavingTransaction.fromJson(Map<String, dynamic> j) =>
      SavingTransaction(
        id: j['id'],
        type: TxType.values.byName(j['type']),
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date']),
        goalId: j['goalId'],
        note: j['note'] ?? '',
        expAwarded: j['expAwarded'] ?? 0,
        isPossibleDuplicate: j['isPossibleDuplicate'] ?? false,
      );
}

class Quest {
  String id;
  String title;
  String description;
  String period; // 'daily' | 'weekly'
  int target;
  int progress;
  int expReward;
  bool claimed;

  Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.period,
    required this.target,
    this.progress = 0,
    required this.expReward,
    this.claimed = false,
  });

  bool get complete => progress >= target;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'period': period,
        'target': target,
        'progress': progress,
        'expReward': expReward,
        'claimed': claimed,
      };

  factory Quest.fromJson(Map<String, dynamic> j) => Quest(
        id: j['id'],
        title: j['title'],
        description: j['description'],
        period: j['period'],
        target: j['target'],
        progress: j['progress'] ?? 0,
        expReward: j['expReward'],
        claimed: j['claimed'] ?? false,
      );
}

class AchievementBadge {
  String id;
  String name;
  String description;
  String emoji;
  String condition;
  bool unlocked;
  double progress; // 0..1

  AchievementBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.condition,
    this.unlocked = false,
    this.progress = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'emoji': emoji,
        'condition': condition,
        'unlocked': unlocked,
        'progress': progress,
      };

  factory AchievementBadge.fromJson(Map<String, dynamic> j) => AchievementBadge(
        id: j['id'],
        name: j['name'],
        description: j['description'],
        emoji: j['emoji'],
        condition: j['condition'],
        unlocked: j['unlocked'] ?? false,
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
      );
}

class AppUser {
  String name;
  String emoji;
  int exp;
  int consistencyWeeks;
  SaverMode mode;
  bool onboarded;

  AppUser({
    this.name = '',
    this.emoji = '🐷',
    this.exp = 0,
    this.consistencyWeeks = 0,
    this.mode = SaverMode.adult,
    this.onboarded = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'emoji': emoji,
        'exp': exp,
        'consistencyWeeks': consistencyWeeks,
        'mode': mode.name,
        'onboarded': onboarded,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        name: j['name'] ?? 'กัปตัน',
        emoji: j['emoji'] ?? '🧑‍✈️',
        exp: j['exp'] ?? 0,
        consistencyWeeks: j['consistencyWeeks'] ?? 0,
        mode: SaverMode.values.byName(j['mode'] ?? 'adult'),
        onboarded: j['onboarded'] ?? true, // ผู้ใช้เก่าถือว่าผ่านแล้ว
      );
}
