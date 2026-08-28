import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/migrations.dart';

void main() {
  test('I14 every historical schema fixture migrates through the full chain',
      () {
    for (var version = 1; version < currentSchemaVersion; version++) {
      final fixture = _readFixture(version);
      final totalBefore = _totalSatang(fixture, version);
      final expBefore = _userExp(fixture);
      final goalIdsBefore = _ids(fixture, 'goals');
      final transactionIdsBefore = _ids(fixture, 'transactions');
      final unlockedBadgeIdsBefore = _unlockedBadgeIds(fixture);

      final migrated = migrateState(fixture, version);

      expect(migrated['schemaVersion'], currentSchemaVersion,
          reason: 'fixture v$version did not reach current schema');
      expect(_totalSatang(migrated, currentSchemaVersion), totalBefore,
          reason: 'fixture v$version changed TOTAL');
      expect(_userExp(migrated), expBefore,
          reason: 'fixture v$version changed EXP');
      expect(_ids(migrated, 'goals'), containsAll(goalIdsBefore),
          reason: 'fixture v$version lost a goal');
      expect(_ids(migrated, 'transactions'), containsAll(transactionIdsBefore),
          reason: 'fixture v$version lost a transaction');
      expect(
        _unlockedBadgeIds(migrated),
        containsAll(unlockedBadgeIdsBefore),
        reason: 'fixture v$version lost an unlocked badge',
      );

      for (final rawGoal in migrated['goals'] as List) {
        Goal.fromJson(Map<String, dynamic>.from(rawGoal as Map));
      }
      for (final rawTransaction in migrated['transactions'] as List) {
        SavingTransaction.fromJson(
          Map<String, dynamic>.from(rawTransaction as Map),
        );
      }
    }
  });
}

Map<String, dynamic> _readFixture(int version) {
  final file = File('test/fixtures/schema/v$version.json');
  expect(file.existsSync(), isTrue,
      reason: 'missing schema fixture for v$version');
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}

int _totalSatang(Map<String, dynamic> state, int version) {
  var total = 0;
  for (final rawGoal in state['goals'] as List? ?? const <dynamic>[]) {
    final goal = Map<String, dynamic>.from(rawGoal as Map);
    total += version == 1
        ? _legacyBahtToSatang(goal['currentAmount'])
        : goal['currentSatang'] as int;
  }
  total += version == 1
      ? _legacyBahtToSatang(state['unallocated'])
      : state['unallocatedSatang'] as int? ?? 0;
  return total;
}

int _legacyBahtToSatang(Object? value) => ((value as num) * 100).round();

int _userExp(Map<String, dynamic> state) =>
    (state['user'] as Map?)?['exp'] as int? ?? 0;

Set<String> _ids(Map<String, dynamic> state, String field) =>
    (state[field] as List? ?? const <dynamic>[])
        .map((entry) => (entry as Map)['id'] as String)
        .toSet();

Set<String> _unlockedBadgeIds(Map<String, dynamic> state) =>
    (state['badges'] as List? ?? const <dynamic>[])
        .where((entry) => (entry as Map)['unlocked'] == true)
        .map((entry) => (entry as Map)['id'] as String)
        .toSet();
