part of 'app_state.dart';

class ConversationalSaveReceipt {
  ConversationalSaveReceipt({
    required Map<String, dynamic> beforeState,
    required this.ledgerEntryIds,
    required this.transactionIds,
    required this.expGained,
    required this.totalAmountSatang,
  }) : _beforeState = beforeState;

  final Map<String, dynamic> _beforeState;
  final List<String> ledgerEntryIds;
  final List<String> transactionIds;
  final int expGained;
  final int totalAmountSatang;
  bool _used = false;
}

class HistoryMutationResult {
  const HistoryMutationResult._(this.success, this.message);

  const HistoryMutationResult.success() : this._(true, null);
  const HistoryMutationResult.failure(String message) : this._(false, message);

  final bool success;
  final String? message;
}

extension ConversationalEntryActions on AppState {
  ConversationalSaveReceipt saveParsedEntries(
    List<ParsedLedgerItem> items, {
    String? goalId,
  }) {
    if (items.isEmpty) {
      throw DomainValidationException.operationNotAllowed(
        'ต้องมีอย่างน้อยหนึ่งรายการ',
      );
    }
    for (final item in items) {
      validateMoneyAmountSatang(item.amountSatang);
    }
    final hasGoalDeposit =
        items.any((item) => item.type == ParsedEntryType.goalDeposit);
    final destinationGoal = hasGoalDeposit
        ? goalId == null
            ? throw DomainValidationException.missingGoal('ไม่ได้ระบุ')
            : _requireGoal(goalId)
        : null;
    if (!hasGoalDeposit && goalId != null) {
      _requireGoal(goalId);
    }

    final beforeState = toJson();
    final beforeExp = user.exp;
    final ledgerEntryIds = <String>[];
    final transactionIds = <String>[];
    var totalAmountSatang = 0;

    try {
      for (final item in items) {
        totalAmountSatang += item.amountSatang;

        if (item.type == ParsedEntryType.goalDeposit) {
          final existingIds = transactions.map((tx) => tx.id).toSet();
          _addSaving(
            amountSatang: item.amountSatang,
            goal: destinationGoal,
            note: item.description,
            date: item.date.toUtc(),
            persist: false,
          );
          transactionIds.addAll(
            transactions
                .where((tx) => !existingIds.contains(tx.id))
                .map((tx) => tx.id),
          );
        } else {
          final id = _uuid.v4();
          ledger.insert(
            0,
            LedgerEntry(
              id: id,
              type: item.type == ParsedEntryType.income
                  ? LedgerType.income
                  : LedgerType.expense,
              amountSatang: item.amountSatang,
              category: item.category,
              note: item.description,
              date: item.date.toUtc(),
            ),
          );
          ledgerEntryIds.add(id);
          user.exp += 5;
        }
      }
    } catch (_) {
      _fromJson(beforeState);
      rethrow;
    }

    _recomputeBadges();
    _saveAndNotify();
    return ConversationalSaveReceipt(
      beforeState: beforeState,
      ledgerEntryIds: ledgerEntryIds,
      transactionIds: transactionIds,
      expGained: user.exp - beforeExp,
      totalAmountSatang: totalAmountSatang,
    );
  }

  bool undoConversationalSave(ConversationalSaveReceipt receipt) {
    if (receipt._used) return false;
    receipt._used = true;
    _fromJson(receipt._beforeState);
    _saveAndNotify();
    return true;
  }

  bool updateLedgerEntry({
    required String id,
    required LedgerType type,
    required num amountSatang,
    required String category,
    required String note,
    required DateTime date,
  }) {
    final validatedAmountSatang = validateMoneyAmountSatang(amountSatang);
    final index = ledger.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      throw DomainValidationException.missingEntity('รายการบัญชี', id);
    }
    final entry = ledger[index];
    entry
      ..type = type
      ..amountSatang = validatedAmountSatang
      ..category = category
      ..note = note
      ..date = date.toUtc();
    _saveAndNotify();
    return true;
  }

  bool updateLedgerCategory(String id, String category) {
    final index = ledger.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      throw DomainValidationException.missingEntity('รายการบัญชี', id);
    }
    ledger[index].category = category;
    _saveAndNotify();
    return true;
  }

  bool updateLedgerDate(String id, DateTime date) {
    final index = ledger.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      throw DomainValidationException.missingEntity('รายการบัญชี', id);
    }
    ledger[index].date = date.toUtc();
    _saveAndNotify();
    return true;
  }

  HistoryMutationResult updateSavingTransaction({
    required String id,
    required num amountSatang,
    required String note,
    required DateTime date,
  }) {
    final validatedAmountSatang = validateMoneyAmountSatang(amountSatang);
    final index = transactions.indexWhere((tx) => tx.id == id);
    if (index < 0) {
      throw DomainValidationException.missingEntity('ประวัติเงินออม', id);
    }
    final transaction = transactions[index];
    final deltaSatang = validatedAmountSatang - transaction.amountSatang;
    final adjustment = _applyTransactionDelta(transaction, deltaSatang);
    if (!adjustment.success) return adjustment;

    transaction
      ..amountSatang = validatedAmountSatang
      ..note = note
      ..date = date.toUtc();
    _refreshGoalStatuses(date.toUtc());
    _saveAndNotify();
    return const HistoryMutationResult.success();
  }

  HistoryMutationResult deleteSavingTransaction(String id) {
    final index = transactions.indexWhere((tx) => tx.id == id);
    if (index < 0) {
      throw DomainValidationException.missingEntity('ประวัติเงินออม', id);
    }
    final transaction = transactions[index];
    final adjustment = _applyTransactionDelta(
      transaction,
      -transaction.amountSatang,
    );
    if (!adjustment.success) return adjustment;

    transactions.removeAt(index);
    _refreshGoalStatuses(DateTime.now().toUtc());
    _saveAndNotify();
    return const HistoryMutationResult.success();
  }

  HistoryMutationResult _applyTransactionDelta(
    SavingTransaction transaction,
    int deltaSatang,
  ) {
    if (deltaSatang == 0) return const HistoryMutationResult.success();

    Goal? sourceGoal;
    if (transaction.goalId != null) {
      for (final goal in goals) {
        if (goal.id == transaction.goalId) sourceGoal = goal;
      }
    }

    switch (transaction.type) {
      case TxType.deposit:
      case TxType.adjust:
      case TxType.slip:
        if (sourceGoal == null ||
            !_canSetGoalBalance(
              sourceGoal,
              sourceGoal.currentSatang + deltaSatang,
            )) {
          return const HistoryMutationResult.failure(
            'แก้ยอดนี้ไม่ได้ เพราะยอดกระปุกปัจจุบันไม่พอหรือจะเกินเป้าหมาย',
          );
        }
        sourceGoal.currentSatang += deltaSatang;
        break;
      case TxType.unallocated:
        if (unallocatedSatang + deltaSatang < 0) {
          return const HistoryMutationResult.failure(
            'แก้ยอดนี้ไม่ได้ เพราะเงินที่ยังไม่จัดสรรถูกใช้ไปแล้ว',
          );
        }
        unallocatedSatang += deltaSatang;
        break;
      case TxType.withdraw:
        if (sourceGoal == null ||
            !_canSetGoalBalance(
              sourceGoal,
              sourceGoal.currentSatang - deltaSatang,
            ) ||
            unallocatedSatang + deltaSatang < 0) {
          return const HistoryMutationResult.failure(
            'แก้รายการถอนนี้ไม่ได้ เพราะยอดที่เกี่ยวข้องไม่เพียงพอ',
          );
        }
        sourceGoal.currentSatang -= deltaSatang;
        unallocatedSatang += deltaSatang;
        break;
      case TxType.transfer:
        final destinationGoal = _transferDestination(transaction);
        if (sourceGoal == null ||
            destinationGoal == null ||
            !_canSetGoalBalance(
              sourceGoal,
              sourceGoal.currentSatang - deltaSatang,
            ) ||
            !_canSetGoalBalance(
              destinationGoal,
              destinationGoal.currentSatang + deltaSatang,
            )) {
          return const HistoryMutationResult.failure(
            'แก้รายการโอนนี้ไม่ได้ เพราะหากระปุกปลายทางไม่พบหรือยอดไม่พอ',
          );
        }
        sourceGoal.currentSatang -= deltaSatang;
        destinationGoal.currentSatang += deltaSatang;
        break;
    }
    return const HistoryMutationResult.success();
  }

  bool _canSetGoalBalance(Goal goal, int valueSatang) {
    if (valueSatang < 0) return false;
    if (goal.flexible || goal.targetSatang <= 0) return true;
    return valueSatang <= goal.targetSatang;
  }

  Goal? _transferDestination(SavingTransaction transaction) {
    const prefix = 'โอนไป ';
    if (!transaction.note.startsWith(prefix)) return null;
    final destinationName = transaction.note.substring(prefix.length).trim();
    final matches = goals
        .where(
          (goal) =>
              goal.id != transaction.goalId && goal.name == destinationName,
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  void _refreshGoalStatuses(DateTime at) {
    for (final goal in goals) {
      if (goal.flexible) {
        goal.status = GoalStatus.active;
        goal.completedDate = null;
      } else if (goal.hasSavingsTarget &&
          goal.currentSatang >= goal.targetSatang) {
        goal.status = GoalStatus.completed;
        goal.completedDate ??= at;
      } else if (goal.status == GoalStatus.completed) {
        goal.status = GoalStatus.active;
        goal.completedDate = null;
      }
    }
  }
}
