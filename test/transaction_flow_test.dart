import 'package:flutter_test/flutter_test.dart';
import 'package:keepkapook/models/models.dart';
import 'package:keepkapook/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Goal _goal(String id, {int currentSatang = 0}) => Goal(
      id: id,
      name: id,
      targetSatang: 100000,
      currentSatang: currentSatang,
      startDate: DateTime.utc(2026, 8, 27),
      targetDate: DateTime.utc(2027, 8, 27),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('TxType เดิม map เป็น flow โดยไม่ปะปนชนิดกับทิศทางเงิน', () {
    expect(
      transactionFlowForType(TxType.deposit),
      TransactionFlow.externalIn,
    );
    expect(
      transactionFlowForType(TxType.unallocated),
      TransactionFlow.externalIn,
    );
    expect(
      transactionFlowForType(TxType.withdraw),
      TransactionFlow.externalOut,
    );
    expect(
      transactionFlowForType(TxType.transfer),
      TransactionFlow.internal,
    );
    expect(
      transactionFlowForType(TxType.adjust),
      TransactionFlow.adjustment,
    );
    expect(
      transactionFlowForType(TxType.slip),
      TransactionFlow.externalIn,
    );
  });

  test('รายการใหม่เก็บ source destination flow และ note แยกกัน', () {
    final source = _goal('source', currentSatang: 5000);
    final destination = _goal('destination');
    final app = AppState()
      ..goals = <Goal>[source, destination]
      ..unallocatedSatang = 1000;

    app.addSaving(
      amountSatang: 200,
      goalId: destination.id,
      note: 'เงินค่าขนม',
      date: DateTime.utc(2026, 8, 27),
    );
    expect(app.transactions.first.flow, TransactionFlow.externalIn);
    expect(app.transactions.first.goalId, isNull);
    expect(app.transactions.first.destinationGoalId, destination.id);
    expect(app.transactions.first.note, 'เงินค่าขนม');

    app.transfer(source.id, destination.id, 300);
    expect(app.transactions.first.flow, TransactionFlow.internal);
    expect(app.transactions.first.goalId, source.id);
    expect(app.transactions.first.destinationGoalId, destination.id);
    expect(app.transactions.first.note, isEmpty);

    app.allocateUnallocated(400, destination.id);
    expect(app.transactions.first.flow, TransactionFlow.internal);
    expect(app.transactions.first.goalId, isNull);
    expect(app.transactions.first.destinationGoalId, destination.id);
    expect(app.transactions.first.note, isEmpty);

    app.withdrawFromGoal(source.id, 100);
    expect(app.transactions.first.flow, TransactionFlow.internal);
    expect(app.transactions.first.goalId, source.id);
    expect(app.transactions.first.destinationGoalId, isNull);
    expect(app.transactions.first.note, isEmpty);

    app.withdrawFromGoal(source.id, 100, toUnallocated: false);
    expect(app.transactions.first.flow, TransactionFlow.externalOut);
    expect(app.transactions.first.goalId, source.id);
    expect(app.transactions.first.destinationGoalId, isNull);
    expect(app.transactions.first.note, isEmpty);
  });

  test('แก้และลบ transfer ใช้ destinationGoalId โดยไม่อ่าน note', () {
    final source = _goal('source', currentSatang: 4000);
    final destination = _goal('destination', currentSatang: 1000);
    final transaction = SavingTransaction(
      id: 'transfer',
      type: TxType.transfer,
      flow: TransactionFlow.internal,
      amountSatang: 1000,
      date: DateTime.utc(2026, 8, 27),
      goalId: source.id,
      destinationGoalId: destination.id,
      note: 'บันทึกอิสระที่ไม่มีชื่อปลายทาง',
    );
    final app = AppState()
      ..goals = <Goal>[source, destination]
      ..transactions = <SavingTransaction>[transaction];

    final edited = app.updateSavingTransaction(
      id: transaction.id,
      amountSatang: 2000,
      note: 'แก้เฉพาะข้อความ',
      date: DateTime.utc(2026, 8, 28),
    );

    expect(edited.success, isTrue);
    expect(source.currentSatang, 3000);
    expect(destination.currentSatang, 2000);
    expect(transaction.note, 'แก้เฉพาะข้อความ');

    final deleted = app.deleteSavingTransaction(transaction.id);
    expect(deleted.success, isTrue);
    expect(source.currentSatang, 5000);
    expect(destination.currentSatang, 0);
  });

  test('transfer เก่าที่ไม่มี destinationGoalId แก้หรือลบไม่ได้', () {
    final source = _goal('source', currentSatang: 4000);
    final transaction = SavingTransaction(
      id: 'legacy-transfer',
      type: TxType.transfer,
      amountSatang: 1000,
      date: DateTime.utc(2026, 8, 27),
      goalId: source.id,
      note: 'โอนไป กระปุกที่ถูกลบ',
    );
    final app = AppState()
      ..goals = <Goal>[source]
      ..transactions = <SavingTransaction>[transaction];
    final before = app.toJson();

    final edited = app.updateSavingTransaction(
      id: transaction.id,
      amountSatang: 2000,
      note: 'ห้ามแก้',
      date: DateTime.utc(2026, 8, 28),
    );
    final deleted = app.deleteSavingTransaction(transaction.id);

    expect(edited.success, isFalse);
    expect(edited.message, contains('ไม่มีข้อมูลกระปุกปลายทาง'));
    expect(deleted.success, isFalse);
    expect(deleted.message, contains('ไม่มีข้อมูลกระปุกปลายทาง'));
    expect(app.toJson(), before);
  });
}
