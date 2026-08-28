import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/screens/history_screen.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'invariant_test_support.dart';

typedef _StateAction = void Function(AppState app);

AppState _cloneDefaults(AppState template) => AppState()
  ..loaded = true
  ..user = AppUser(name: 'เมย์', onboarded: true)
  ..quests =
      template.quests.map((quest) => Quest.fromJson(quest.toJson())).toList()
  ..badges = template.badges
      .map((badge) => AchievementBadge.fromJson(badge.toJson()))
      .toList();

void main() {
  configureInvariantTestEnvironment();

  testWidgets('I10 deleting a goal preserves its name in transaction history',
      (tester) async {
    final goal = invariantGoal(
      id: 'goal',
      name: 'ทริปญี่ปุ่น',
      targetSatang: 100000,
    );
    final app = AppState()
      ..loaded = true
      ..goals = <Goal>[goal];

    app.addSaving(
      amountSatang: 25000,
      goalId: goal.id,
      date: invariantTime,
    );
    expect(app.transactions.single.destinationGoalNameSnapshot, 'ทริปญี่ปุ่น');

    app.deleteGoal(goal.id);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ChangeNotifierProvider<AppState>.value(
          value: app,
          child: const HistoryScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('ทริปญี่ปุ่น'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.flushPendingSaves();
  });

  test('I11 every default quest has a reachable progress handler', () async {
    final template = await loadEmptyInvariantApp();
    final handlers = <String, _StateAction>{
      'q-deposit': (app) {
        app.goals = <Goal>[
          invariantGoal(
            id: 'goal',
            name: 'เป้าหมาย',
            targetSatang: 10000,
          ),
        ];
        app.addSaving(
          amountSatang: 100,
          goalId: 'goal',
          date: invariantTime,
        );
      },
      'q-allocate': (app) {
        app.goals = <Goal>[
          invariantGoal(
            id: 'goal',
            name: 'เป้าหมาย',
            targetSatang: 10000,
          ),
        ];
        app.unallocatedSatang = 100;
        app.allocateUnallocated(100, 'goal');
      },
      'q-weekly-consistency': (app) {
        for (var index = 0; index < 5; index++) {
          app.addLedger(
            LedgerType.expense,
            100,
            'อาหาร',
            '',
            date: invariantTime.add(Duration(days: index)),
          );
        }
      },
    };
    final violations = <String>[];

    for (final definition in template.quests) {
      final app = _cloneDefaults(template);
      final before =
          app.quests.firstWhere((quest) => quest.id == definition.id).progress;
      final handler = handlers[definition.id];
      if (handler == null) {
        violations.add('${definition.id}: no progress handler');
        continue;
      }
      handler(app);
      final after =
          app.quests.firstWhere((quest) => quest.id == definition.id).progress;
      if (after <= before) {
        violations.add('${definition.id}: handler made no progress');
      }
    }

    expect(violations, isEmpty);
  });

  test('I11 every default badge has a reachable unlock condition', () async {
    final template = await loadEmptyInvariantApp();
    final handlers = <String, _StateAction>{
      'b-first-drop': (app) {
        app.goals = <Goal>[
          invariantGoal(
            id: 'goal',
            name: 'เป้าหมาย',
            targetSatang: 10000,
          ),
        ];
        app.addSaving(
          amountSatang: 100,
          goalId: 'goal',
          date: invariantTime,
        );
      },
      'b-halfway': (app) {
        app.goals = <Goal>[
          invariantGoal(
            id: 'goal',
            name: 'เป้าหมาย',
            targetSatang: 1000,
          ),
        ];
        app.addSaving(
          amountSatang: 500,
          goalId: 'goal',
          date: invariantTime,
        );
      },
      'b-crusher': (app) {
        app.goals = <Goal>[
          invariantGoal(
            id: 'goal',
            name: 'เป้าหมาย',
            targetSatang: 1000,
          ),
        ];
        app.addSaving(
          amountSatang: 1000,
          goalId: 'goal',
          date: invariantTime,
        );
      },
      'b-triple': (app) {
        app.goals = List<Goal>.generate(
          3,
          (index) => invariantGoal(
            id: 'goal-$index',
            name: 'เป้าหมาย $index',
            targetSatang: 100,
          ),
        );
        for (final goal in app.goals) {
          app.addSaving(
            amountSatang: 100,
            goalId: goal.id,
            date: invariantTime,
          );
        }
      },
      'b-rhythm': (app) {
        for (var index = 0; index < 7; index++) {
          app.addLedger(
            LedgerType.expense,
            100,
            'อาหาร',
            '',
            date: invariantTime.add(Duration(days: index)),
          );
        }
      },
    };
    final violations = <String>[];

    for (final definition in template.badges) {
      final app = _cloneDefaults(template);
      final handler = handlers[definition.id];
      if (handler == null) {
        violations.add('${definition.id}: no unlock handler');
        continue;
      }
      handler(app);
      final unlocked =
          app.badges.firstWhere((badge) => badge.id == definition.id).unlocked;
      if (!unlocked) {
        violations.add('${definition.id}: condition did not unlock');
      }
    }

    expect(violations, isEmpty);
  });
}
