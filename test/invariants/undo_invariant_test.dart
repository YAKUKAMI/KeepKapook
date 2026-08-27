import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/utils/parser/parser.dart';

import 'invariant_test_support.dart';

void main() {
  configureInvariantTestEnvironment();

  test('I12 undo restores TOTAL EXP quest progress and badges exactly',
      () async {
    final app = await loadEmptyInvariantApp();
    app
      ..user = AppUser(name: 'เมย์', exp: 7, onboarded: true)
      ..goals = <Goal>[
        invariantGoal(
          id: 'goal',
          name: 'เป้าหมาย',
          targetSatang: 100000,
        ),
      ];
    final before = <String, Object>{
      'total': invariantTotal(app),
      'exp': app.user.exp,
      'quests': app.quests.map((quest) => quest.toJson()).toList(),
      'badges': app.badges.map((badge) => badge.toJson()).toList(),
      'transactions': app.transactions.map((tx) => tx.toJson()).toList(),
    };
    const confidence = FieldConfidence(
      amount: 1,
      type: 1,
      category: 1,
      date: 1,
    );

    final receipt = app.saveParsedEntries(
      <ParsedLedgerItem>[
        ParsedLedgerItem(
          amountSatang: 5000,
          type: ParsedEntryType.goalDeposit,
          category: 'เงินออม',
          date: invariantTime,
          description: 'ออม 50',
          confidence: confidence,
        ),
      ],
      goalId: 'goal',
    );
    expect(app.undoConversationalSave(receipt), isTrue);

    final after = <String, Object>{
      'total': invariantTotal(app),
      'exp': app.user.exp,
      'quests': app.quests.map((quest) => quest.toJson()).toList(),
      'badges': app.badges.map((badge) => badge.toJson()).toList(),
      'transactions': app.transactions.map((tx) => tx.toJson()).toList(),
    };
    expect(after, before);
  });
}
