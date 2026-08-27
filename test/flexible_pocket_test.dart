import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/screens/goal_detail_screen.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:keepkapook/utils/coach.dart';
import 'package:keepkapook/widgets/goal_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Goal _goal({
  required String id,
  required String name,
  required int targetSatang,
  int currentSatang = 0,
  bool flexible = false,
  GoalStatus status = GoalStatus.active,
}) =>
    Goal(
      id: id,
      name: name,
      targetSatang: targetSatang,
      currentSatang: currentSatang,
      startDate: DateTime.utc(2026, 8, 27),
      targetDate: DateTime.utc(2027, 8, 27),
      flexible: flexible,
      status: status,
    );

int _total(AppState app) => app.goals.fold<int>(
      app.unallocatedSatang,
      (sum, goal) => sum + goal.currentSatang,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('flexible รับเงินไม่จำกัดและไม่ให้ milestone EXP หรือสถานะถึงเป้า', () {
    final pocket = _goal(
      id: 'flexible',
      name: 'ใช้จ่ายประจำวัน',
      targetSatang: 1000,
      currentSatang: 900,
      flexible: true,
      status: GoalStatus.completed,
    );
    final app = AppState()
      ..goals = <Goal>[pocket]
      ..unallocatedSatang = 50;

    final result = app.addSaving(
      amountSatang: 500,
      goalId: pocket.id,
      date: DateTime.utc(2026, 8, 27),
    );

    expect(pocket.currentSatang, 1400);
    expect(app.unallocatedSatang, 50);
    expect(result.overflowSatang, 0);
    expect(result.exp, 10);
    expect(result.completed, isNull);
    expect(pocket.hasSavingsTarget, isFalse);
    expect(pocket.progress, 0);
    expect(pocket.remainingSatang, 0);
    expect(pocket.isCompleted, isFalse);
    expect(pocket.status, GoalStatus.active);
    expect(pocket.completedDate, isNull);
    expect(app.activeGoals, contains(pocket));
    expect(app.completedGoals, isNot(contains(pocket)));
    expect(app.targetedSavedSatang, 0);
    expect(app.grandTargetSatang, 0);
  });

  test('goal ปกติยังได้ milestone EXP และสถานะตาม progress เดิม', () {
    final goal = _goal(
      id: 'goal',
      name: 'เป้าหมายปกติ',
      targetSatang: 1000,
      currentSatang: 200,
    );
    final app = AppState()..goals = <Goal>[goal];

    final result = app.addSaving(
      amountSatang: 300,
      goalId: goal.id,
      date: DateTime.utc(2026, 8, 27),
    );

    expect(goal.currentSatang, 500);
    expect(goal.progress, 0.5);
    expect(result.exp, 60);
    expect(goal.status, GoalStatus.active);
  });

  test('flexible ไม่มี plan หรือ recovery ที่อาศัย remaining', () {
    final pocket = _goal(
      id: 'flexible',
      name: 'ใช้จ่ายประจำวัน',
      targetSatang: 0,
      currentSatang: 1500,
      flexible: true,
    );

    final plan = planStatus(pocket);

    expect(plan.behind, isFalse);
    expect(plan.shortfallSatang, 0);
    expect(
      () => recoveryOptions(pocket, plan, 100),
      throwsArgumentError,
    );
  });

  test('allocate เข้า flexible รับเงินทั้งหมดโดย TOTAL คงเดิม', () {
    final pocket = _goal(
      id: 'flexible',
      name: 'ใช้จ่ายประจำวัน',
      targetSatang: 0,
      currentSatang: 1500,
      flexible: true,
    );
    final app = AppState()
      ..goals = <Goal>[pocket]
      ..unallocatedSatang = 3000;
    final before = _total(app);

    app.allocateUnallocated(1000, pocket.id);

    expect(pocket.currentSatang, 2500);
    expect(app.unallocatedSatang, 2000);
    expect(_total(app), before);
  });

  test('transfer เข้าออกและ withdraw จาก flexible รักษา TOTAL', () {
    final source = _goal(
      id: 'source',
      name: 'ต้นทาง',
      targetSatang: 10000,
      currentSatang: 5000,
    );
    final pocket = _goal(
      id: 'flexible',
      name: 'ใช้จ่ายประจำวัน',
      targetSatang: 0,
      currentSatang: 1500,
      flexible: true,
    );
    final destination = _goal(
      id: 'destination',
      name: 'ปลายทาง',
      targetSatang: 10000,
    );
    final app = AppState()
      ..goals = <Goal>[source, pocket, destination]
      ..unallocatedSatang = 700;
    final before = _total(app);

    app.transfer(source.id, pocket.id, 2000);
    expect(source.currentSatang, 3000);
    expect(pocket.currentSatang, 3500);
    expect(_total(app), before);

    app.transfer(pocket.id, destination.id, 1000);
    expect(pocket.currentSatang, 2500);
    expect(destination.currentSatang, 1000);
    expect(_total(app), before);

    app.withdrawFromGoal(pocket.id, 500);
    expect(pocket.currentSatang, 2000);
    expect(app.unallocatedSatang, 1200);
    expect(_total(app), before);
  });

  testWidgets('GoalCard flexible แสดงยอดสะสมโดยไม่มีเปอร์เซ็นต์หรือเป้าหมาย',
      (tester) async {
    final pocket = _goal(
      id: 'flexible',
      name: 'ใช้จ่ายประจำวัน',
      targetSatang: 0,
      currentSatang: 251500,
      flexible: true,
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: GoalCard(goal: pocket))),
    );

    expect(find.text('ยอดสะสม'), findsOneWidget);
    expect(find.text('฿2,515'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('รายละเอียด flexible แสดงยอดสะสมโดยไม่เรียก progress เป้าหมาย',
      (tester) async {
    final pocket = _goal(
      id: 'flexible',
      name: 'ใช้จ่ายประจำวัน',
      targetSatang: 0,
      currentSatang: 251500,
      flexible: true,
    );
    final app = AppState()
      ..loaded = true
      ..goals = <Goal>[pocket];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(home: GoalDetailScreen(goalId: pocket.id)),
      ),
    );

    expect(find.text('ยอดสะสม'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });
}
