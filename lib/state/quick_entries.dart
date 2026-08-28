part of 'app_state.dart';

enum QuickRecordKind { saving, expense }

class QuickRecordReceipt {
  QuickRecordReceipt._({
    required Map<String, dynamic> beforeState,
    required this.kind,
    required this.amountSatang,
    required this.expGained,
    this.savingFeedback,
    this.monthExpenseSatang,
  }) : _beforeState = beforeState;

  final Map<String, dynamic> _beforeState;
  final QuickRecordKind kind;
  final int amountSatang;
  final int expGained;
  final QuickSavingFeedback? savingFeedback;
  final int? monthExpenseSatang;
  bool _used = false;
}

extension QuickEntryActions on AppState {
  QuickRecordReceipt quickSave({
    required num amountSatang,
    required String goalId,
    DateTime? date,
  }) {
    final validatedAmountSatang = validateMoneyAmountSatang(amountSatang);
    final goal = _requireGoal(goalId);
    final beforeState = toJson();
    final beforeExp = user.exp;
    final beforeGoalSatang = goal.currentSatang;

    addSaving(
      amountSatang: validatedAmountSatang,
      goalId: goal.id,
      date: date,
    );

    return QuickRecordReceipt._(
      beforeState: beforeState,
      kind: QuickRecordKind.saving,
      amountSatang: validatedAmountSatang,
      expGained: user.exp - beforeExp,
      savingFeedback: buildQuickSavingFeedback(
        goalName: goal.name,
        beforeSatang: beforeGoalSatang,
        afterSatang: goal.currentSatang,
        targetSatang: goal.targetSatang,
        flexible: goal.flexible,
        expGained: user.exp - beforeExp,
      ),
    );
  }

  QuickRecordReceipt quickExpense({
    required num amountSatang,
    required String category,
    DateTime? date,
  }) {
    final validatedAmountSatang = validateMoneyAmountSatang(amountSatang);
    if (!expenseCategories.contains(category)) {
      throw DomainValidationException.operationNotAllowed(
        'หมวดรายจ่ายไม่ถูกต้อง',
      );
    }
    final recordedAt = date ?? DateTime.now();
    final beforeState = toJson();
    final beforeExp = user.exp;

    addLedger(
      LedgerType.expense,
      validatedAmountSatang,
      category,
      '',
      date: recordedAt,
    );

    return QuickRecordReceipt._(
      beforeState: beforeState,
      kind: QuickRecordKind.expense,
      amountSatang: validatedAmountSatang,
      expGained: user.exp - beforeExp,
      monthExpenseSatang: ledgerMonthSummary(now: recordedAt).expenseSatang,
    );
  }

  bool undoQuickRecord(QuickRecordReceipt receipt) {
    if (receipt._used) return false;
    receipt._used = true;
    _fromJson(receipt._beforeState);
    _saveAndNotify();
    return true;
  }
}
