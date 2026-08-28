import 'dart:convert';

import '../models/models.dart';
import 'migrations.dart';

const String keepKapookBackupFormat = 'keepkapook-backup';

enum BackupValidationReason {
  malformedJson,
  notKeepKapookBackup,
  invalidData,
  newerSchema,
}

class BackupValidationException implements Exception {
  const BackupValidationException(this.reason, this.userMessage);

  final BackupValidationReason reason;
  final String userMessage;

  @override
  String toString() => userMessage;
}

class BackupPreview {
  const BackupPreview._({
    required this.migratedState,
    required this.schemaVersion,
    required this.exportedAt,
    required this.appVersion,
    required this.goalCount,
    required this.savingTransactionCount,
    required this.ledgerEntryCount,
    required this.totalSavedSatang,
    required this.unallocatedSatang,
  });

  final Map<String, dynamic> migratedState;
  final int schemaVersion;
  final DateTime exportedAt;
  final String appVersion;
  final int goalCount;
  final int savingTransactionCount;
  final int ledgerEntryCount;
  final int totalSavedSatang;
  final int unallocatedSatang;

  int get totalItemCount => savingTransactionCount + ledgerEntryCount;
}

String createBackupJson({
  required Map<String, dynamic> state,
  required DateTime exportedAt,
  required String appVersion,
}) {
  final version = state['schemaVersion'];
  if (version is! int || version <= 0 || appVersion.trim().isEmpty) {
    throw const FormatException('สร้างไฟล์สำรองไม่ได้');
  }

  return jsonEncode(<String, dynamic>{
    ...state,
    'backupFormat': keepKapookBackupFormat,
    'schemaVersion': version,
    'exportedAt': exportedAt.toUtc().toIso8601String(),
    'appVersion': appVersion.trim(),
  });
}

String backupFileName(DateTime exportedAt) {
  final year = exportedAt.year.toString().padLeft(4, '0');
  final month = exportedAt.month.toString().padLeft(2, '0');
  final day = exportedAt.day.toString().padLeft(2, '0');
  return 'keepkapook-backup-$year$month$day.json';
}

BackupPreview validateBackupJson(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    throw const BackupValidationException(
      BackupValidationReason.malformedJson,
      'อ่านไฟล์สำรองไม่สำเร็จ ไฟล์อาจเสียหายหรือไม่ใช่ JSON',
    );
  }

  if (decoded is! Map) {
    throw const BackupValidationException(
      BackupValidationReason.notKeepKapookBackup,
      'ไฟล์นี้ไม่ใช่ไฟล์สำรองของ KeepKapook',
    );
  }
  final backup = Map<String, dynamic>.from(decoded);
  if (backup['backupFormat'] != keepKapookBackupFormat) {
    throw const BackupValidationException(
      BackupValidationReason.notKeepKapookBackup,
      'ไฟล์นี้ไม่ใช่ไฟล์สำรองของ KeepKapook',
    );
  }

  final exportedAt = DateTime.tryParse(backup['exportedAt']?.toString() ?? '');
  final appVersion = backup['appVersion']?.toString().trim() ?? '';
  if (exportedAt == null || appVersion.isEmpty) {
    throw const BackupValidationException(
      BackupValidationReason.invalidData,
      'ข้อมูลในไฟล์สำรองไม่ครบหรือไม่ถูกต้อง จึงกู้คืนไม่ได้',
    );
  }

  late final Map<String, dynamic> migrated;
  try {
    final fromVersion = readSchemaVersion(backup);
    migrated = migrateState(backup, fromVersion);
  } on UnsupportedSchemaVersionException {
    throw const BackupValidationException(
      BackupValidationReason.newerSchema,
      'ไฟล์สำรองสร้างจากแอปเวอร์ชันใหม่กว่า กรุณาอัปเดตแอปก่อนกู้คืน',
    );
  } catch (_) {
    throw const BackupValidationException(
      BackupValidationReason.invalidData,
      'ข้อมูลในไฟล์สำรองไม่ครบหรือไม่ถูกต้อง จึงกู้คืนไม่ได้',
    );
  }

  try {
    AppUser.fromJson(_requireMap(migrated, 'user'));
    final goals = _parseList(migrated, 'goals', Goal.fromJson);
    final transactions =
        _parseList(migrated, 'transactions', SavingTransaction.fromJson);
    _parseList(migrated, 'quests', Quest.fromJson);
    _parseList(migrated, 'badges', AchievementBadge.fromJson);
    final ledger = _parseList(migrated, 'ledger', LedgerEntry.fromJson);
    final unallocatedSatang = migrated['unallocatedSatang'];
    if (unallocatedSatang is! int || unallocatedSatang < 0) {
      throw const FormatException('unallocatedSatang ไม่ถูกต้อง');
    }
    if (goals.any((goal) => goal.targetSatang < 0 || goal.currentSatang < 0) ||
        transactions.any((transaction) => transaction.amountSatang < 0) ||
        ledger.any((entry) => entry.amountSatang < 0)) {
      throw const FormatException('ยอดเงินต้องไม่ติดลบ');
    }

    return BackupPreview._(
      migratedState: Map<String, dynamic>.from(migrated),
      schemaVersion: migrated['schemaVersion'] as int,
      exportedAt: exportedAt.toUtc(),
      appVersion: appVersion,
      goalCount: goals.length,
      savingTransactionCount: transactions.length,
      ledgerEntryCount: ledger.length,
      totalSavedSatang:
          goals.fold<int>(0, (sum, goal) => sum + goal.currentSatang),
      unallocatedSatang: unallocatedSatang,
    );
  } catch (_) {
    throw const BackupValidationException(
      BackupValidationReason.invalidData,
      'ข้อมูลในไฟล์สำรองไม่ครบหรือไม่ถูกต้อง จึงกู้คืนไม่ได้',
    );
  }
}

Map<String, dynamic> _requireMap(
  Map<String, dynamic> state,
  String field,
) {
  final value = state[field];
  if (value is! Map) throw FormatException('$field ต้องเป็น JSON object');
  return Map<String, dynamic>.from(value);
}

List<T> _parseList<T>(
  Map<String, dynamic> state,
  String field,
  T Function(Map<String, dynamic>) fromJson,
) {
  final value = state[field];
  if (value is! List) throw FormatException('$field ต้องเป็น JSON array');
  return value.map((entry) {
    if (entry is! Map) throw FormatException('$field มีข้อมูลไม่ถูกต้อง');
    return fromJson(Map<String, dynamic>.from(entry));
  }).toList();
}
