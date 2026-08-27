// Data models — ตรงกับเวอร์ชันเว็บ (lib/types.ts)

final DateTime _jsonEpoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

String _stringValue(Object? value, String fallback) =>
    value == null ? fallback : value.toString();

double _doubleValue(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

int _intValue(Object? value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  throw const FormatException('ค่าจำนวนเต็มใน JSON ไม่ถูกต้อง');
}

bool _boolValue(Object? value, bool fallback) =>
    value is bool ? value : fallback;

DateTime _dateValue(Object? value, [DateTime? fallback]) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ?? fallback ?? _jsonEpoch;
}

DateTime? _nullableDateValue(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

T _enumValue<T extends Enum>(List<T> values, Object? value, T fallback) {
  final name = value?.toString();
  for (final candidate in values) {
    if (candidate.name == name) return candidate;
  }
  return fallback;
}

enum GoalCategory { shopping, education, travel, emergency, investment, other }

enum GoalPriority { low, medium, high }

enum GoalStatus { active, completed }

enum SaverMode { child, adult }

enum TxType { deposit, unallocated, withdraw, transfer, adjust, slip }

enum TransactionFlow { externalIn, externalOut, internal, adjustment }

TransactionFlow transactionFlowForType(TxType type) {
  switch (type) {
    case TxType.deposit:
    case TxType.unallocated:
    case TxType.slip:
      return TransactionFlow.externalIn;
    case TxType.withdraw:
      return TransactionFlow.externalOut;
    case TxType.transfer:
      return TransactionFlow.internal;
    case TxType.adjust:
      return TransactionFlow.adjustment;
  }
}

// รายรับ-รายจ่าย (แยกจากการออม)
enum LedgerType { income, expense }

class LedgerEntry {
  String id;
  LedgerType type;
  int amountSatang;
  String category;
  String note;
  DateTime date;

  LedgerEntry({
    required this.id,
    required this.type,
    required this.amountSatang,
    required this.category,
    this.note = '',
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'amountSatang': amountSatang,
        'category': category,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: _stringValue(j['id'], ''),
        type: _enumValue(
          LedgerType.values,
          j['type'],
          LedgerType.expense,
        ),
        amountSatang: _intValue(j['amountSatang']),
        category: _stringValue(j['category'], 'อื่น ๆ'),
        note: _stringValue(j['note'], ''),
        date: _dateValue(j['date']),
      );
}

class Goal {
  String id;
  String name;
  String description;
  int targetSatang;
  int currentSatang;
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
    required this.targetSatang,
    this.currentSatang = 0,
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
  }) : members = members ?? [] {
    if (flexible) {
      status = GoalStatus.active;
      completedDate = null;
    }
  }

  bool get hasSavingsTarget => !flexible && targetSatang > 0;
  bool get isCompleted => hasSavingsTarget && status == GoalStatus.completed;
  double get progress =>
      hasSavingsTarget ? (currentSatang / targetSatang).clamp(0, 1) : 0;
  int get remainingSatang {
    if (!hasSavingsTarget) return 0;
    final remaining = targetSatang - currentSatang;
    if (remaining <= 0) return 0;
    return remaining > targetSatang ? targetSatang : remaining;
  }

  bool get isLockedNow =>
      locked && (lockUntil == null || lockUntil!.isAfter(DateTime.now()));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'targetSatang': targetSatang,
        'currentSatang': currentSatang,
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
        id: _stringValue(j['id'], ''),
        name: _stringValue(j['name'], ''),
        description: _stringValue(j['description'], ''),
        targetSatang: _intValue(j['targetSatang']),
        currentSatang: _intValue(j['currentSatang']),
        startDate: _dateValue(j['startDate']),
        targetDate: _dateValue(j['targetDate']),
        category: _enumValue(
          GoalCategory.values,
          j['category'],
          GoalCategory.other,
        ),
        priority: _enumValue(
          GoalPriority.values,
          j['priority'],
          GoalPriority.medium,
        ),
        emoji: _stringValue(j['emoji'], '🎯'),
        themeColor: _intValue(j['themeColor'], 0xFF52C7A5),
        status: _enumValue(
          GoalStatus.values,
          j['status'],
          GoalStatus.active,
        ),
        completedDate: _nullableDateValue(j['completedDate']),
        flexible: _boolValue(j['flexible'], false),
        locked: _boolValue(j['locked'], false),
        lockUntil: _nullableDateValue(j['lockUntil']),
        shared: _boolValue(j['shared'], false),
        members:
            (j['members'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

class SavingTransaction {
  String id;
  TxType type;
  TransactionFlow flow;
  int amountSatang;
  DateTime date;
  String? goalId;
  String? destinationGoalId;
  String note;
  int expAwarded;
  bool isPossibleDuplicate;

  SavingTransaction({
    required this.id,
    required this.type,
    TransactionFlow? flow,
    required this.amountSatang,
    required this.date,
    this.goalId,
    this.destinationGoalId,
    this.note = '',
    this.expAwarded = 0,
    this.isPossibleDuplicate = false,
  }) : flow = flow ?? transactionFlowForType(type);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'flow': flow.name,
        'amountSatang': amountSatang,
        'date': date.toIso8601String(),
        'goalId': goalId,
        'destinationGoalId': destinationGoalId,
        'note': note,
        'expAwarded': expAwarded,
        'isPossibleDuplicate': isPossibleDuplicate,
      };

  factory SavingTransaction.fromJson(Map<String, dynamic> j) {
    final type = _enumValue(TxType.values, j['type'], TxType.deposit);
    return SavingTransaction(
      id: _stringValue(j['id'], ''),
      type: type,
      flow: _enumValue(
        TransactionFlow.values,
        j['flow'],
        transactionFlowForType(type),
      ),
      amountSatang: _intValue(j['amountSatang']),
      date: _dateValue(j['date']),
      goalId: j['goalId']?.toString(),
      destinationGoalId: j['destinationGoalId']?.toString(),
      note: _stringValue(j['note'], ''),
      expAwarded: _intValue(j['expAwarded']),
      isPossibleDuplicate: _boolValue(j['isPossibleDuplicate'], false),
    );
  }
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
        id: _stringValue(j['id'], ''),
        title: _stringValue(j['title'], ''),
        description: _stringValue(j['description'], ''),
        period: _stringValue(j['period'], 'daily'),
        target: _intValue(j['target'], 1),
        progress: _intValue(j['progress']),
        expReward: _intValue(j['expReward']),
        claimed: _boolValue(j['claimed'], false),
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
        id: _stringValue(j['id'], ''),
        name: _stringValue(j['name'], ''),
        description: _stringValue(j['description'], ''),
        emoji: _stringValue(j['emoji'], '🏅'),
        condition: _stringValue(j['condition'], ''),
        unlocked: _boolValue(j['unlocked'], false),
        progress: _doubleValue(j['progress']),
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
        name: _stringValue(j['name'], 'กัปตัน'),
        emoji: _stringValue(j['emoji'], '🧑‍✈️'),
        exp: _intValue(j['exp']),
        consistencyWeeks: _intValue(j['consistencyWeeks']),
        mode: _enumValue(SaverMode.values, j['mode'], SaverMode.adult),
        onboarded: _boolValue(
          j['onboarded'],
          true, // ผู้ใช้เก่าถือว่าผ่านแล้ว
        ),
      );
}
