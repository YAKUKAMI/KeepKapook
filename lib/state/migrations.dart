import '../models/models.dart';
import '../utils/format.dart';

const int currentSchemaVersion = 3;

typedef StateMigration = Map<String, dynamic> Function(
  Map<String, dynamic> state,
);

/// แต่ละ key คือ version ต้นทาง เช่น key 1 ต้อง migrate v1 → v2
final Map<int, StateMigration> _migrationSteps = <int, StateMigration>{
  1: _migrateV1ToV2,
  2: _migrateV2ToV3,
};

Map<String, dynamic> _migrateV1ToV2(Map<String, dynamic> state) {
  final migrated = Map<String, dynamic>.from(state);

  migrated['goals'] = _migrateMoneyList(
    state['goals'],
    const <String, String>{
      'targetAmount': 'targetSatang',
      'currentAmount': 'currentSatang',
    },
  );
  migrated['transactions'] = _migrateMoneyList(
    state['transactions'],
    const <String, String>{'amount': 'amountSatang'},
  );
  migrated['ledger'] = _migrateMoneyList(
    state['ledger'],
    const <String, String>{'amount': 'amountSatang'},
  );

  if (migrated.containsKey('unallocatedSatang')) {
    if (migrated['unallocatedSatang'] is! int) {
      throw const FormatException('unallocatedSatang ต้องเป็นจำนวนเต็ม');
    }
  } else if (migrated.containsKey('unallocated')) {
    migrated['unallocatedSatang'] =
        _legacyBahtToSatang(migrated.remove('unallocated'));
  }

  return migrated;
}

Map<String, dynamic> _migrateV2ToV3(Map<String, dynamic> state) {
  final migrated = Map<String, dynamic>.from(state);
  final goalIdsByName = <String, List<String>>{};
  final rawGoals = state['goals'];
  if (rawGoals != null && rawGoals is! List) {
    throw const FormatException('goals ต้องเป็น JSON array');
  }
  for (final rawGoal in (rawGoals as List? ?? const <dynamic>[])) {
    if (rawGoal is! Map) {
      throw const FormatException('ข้อมูล goal ต้องเป็น JSON object');
    }
    final goal = Map<String, dynamic>.from(rawGoal);
    final id = goal['id']?.toString();
    final name = goal['name']?.toString();
    if (id == null || name == null) continue;
    goalIdsByName.putIfAbsent(name, () => <String>[]).add(id);
  }

  final rawTransactions = state['transactions'];
  if (rawTransactions != null && rawTransactions is! List) {
    throw const FormatException('transactions ต้องเป็น JSON array');
  }
  migrated['transactions'] =
      (rawTransactions as List? ?? const <dynamic>[]).map((rawTransaction) {
    if (rawTransaction is! Map) {
      throw const FormatException('ข้อมูล transaction ต้องเป็น JSON object');
    }
    final transaction = Map<String, dynamic>.from(rawTransaction);
    final type = _legacyTransactionType(transaction['type']);
    transaction['flow'] = transactionFlowForType(type).name;

    switch (type) {
      case TxType.deposit:
      case TxType.adjust:
      case TxType.slip:
        transaction['destinationGoalId'] = transaction['goalId'];
        transaction['goalId'] = null;
        break;
      case TxType.transfer:
        transaction['destinationGoalId'] = _recoverTransferDestination(
          transaction,
          goalIdsByName,
        );
        break;
      case TxType.unallocated:
      case TxType.withdraw:
        transaction['destinationGoalId'] = null;
        break;
    }
    return transaction;
  }).toList();
  return migrated;
}

TxType _legacyTransactionType(Object? value) {
  final name = value?.toString();
  for (final type in TxType.values) {
    if (type.name == name) return type;
  }
  // fromJson เดิมถือ type ที่หาย/ไม่รู้จักเป็น deposit เช่นกัน
  return TxType.deposit;
}

String? _recoverTransferDestination(
  Map<String, dynamic> transaction,
  Map<String, List<String>> goalIdsByName,
) {
  const prefix = 'โอนไป ';
  final note = transaction['note']?.toString() ?? '';
  if (!note.startsWith(prefix)) return null;
  final destinationName = note.substring(prefix.length);
  final sourceGoalId = transaction['goalId']?.toString();
  final matches = (goalIdsByName[destinationName] ?? const <String>[])
      .where((id) => id != sourceGoalId)
      .toList();
  return matches.length == 1 ? matches.single : null;
}

List<dynamic> _migrateMoneyList(
  Object? value,
  Map<String, String> renamedFields,
) {
  if (value == null) return <dynamic>[];
  if (value is! List) throw const FormatException('ข้อมูลต้องเป็น JSON array');

  return value.map((entry) {
    if (entry is! Map) {
      throw const FormatException('ข้อมูลต้องเป็น JSON object');
    }
    final migrated = Map<String, dynamic>.from(entry);
    for (final rename in renamedFields.entries) {
      if (migrated.containsKey(rename.value)) {
        if (migrated[rename.value] is! int) {
          throw FormatException('${rename.value} ต้องเป็นจำนวนเต็ม');
        }
      } else if (migrated.containsKey(rename.key)) {
        migrated[rename.value] =
            _legacyBahtToSatang(migrated.remove(rename.key));
      }
    }
    return migrated;
  }).toList();
}

int _legacyBahtToSatang(Object? value) {
  if (value is! num) throw const FormatException('ยอดเงินบาทเดิมไม่ถูกต้อง');
  final satang = parseMoneyToSatang(value.toString(), maxSatang: null);
  if (satang == null) throw const FormatException('ยอดเงินบาทเดิมไม่ถูกต้อง');
  return satang;
}

class UnsupportedSchemaVersionException implements Exception {
  const UnsupportedSchemaVersionException(this.version);

  final int version;

  @override
  String toString() =>
      'Schema version $version is newer than $currentSchemaVersion';
}

class MissingMigrationException implements Exception {
  const MissingMigrationException(this.fromVersion);

  final int fromVersion;

  @override
  String toString() => 'Missing migration from schema v$fromVersion';
}

/// ข้อมูลเดิมก่อนมีระบบ version ถือเป็น schema v1
int readSchemaVersion(Map<String, dynamic> state) {
  final value = state['schemaVersion'];
  if (value == null) return 1;
  if (value is int && value > 0) return value;
  if (value is num && value > 0 && value == value.toInt()) {
    return value.toInt();
  }
  throw const FormatException('schemaVersion ต้องเป็นจำนวนเต็มบวก');
}

/// Migrate ทีละขั้นจนถึง [currentSchemaVersion] โดยไม่แก้ Map ต้นฉบับ
Map<String, dynamic> migrateState(
  Map<String, dynamic> rawState,
  int fromVersion,
) {
  if (fromVersion <= 0) {
    throw const FormatException('schemaVersion ต้องเป็นจำนวนเต็มบวก');
  }
  if (fromVersion > currentSchemaVersion) {
    throw UnsupportedSchemaVersionException(fromVersion);
  }

  var version = fromVersion;
  var state = Map<String, dynamic>.from(rawState);

  while (version < currentSchemaVersion) {
    final migrate = _migrationSteps[version];
    if (migrate == null) throw MissingMigrationException(version);
    state = migrate(Map<String, dynamic>.from(state));
    version += 1;
    state['schemaVersion'] = version;
  }

  state['schemaVersion'] = currentSchemaVersion;
  return state;
}
