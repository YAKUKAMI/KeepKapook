import 'format.dart';

const List<int> defaultQuickSavingAmountsSatang = <int>[2000, 5000, 10000];

String? validateQuickSavingAmounts(List<int> amountsSatang) {
  if (amountsSatang.length != 3) {
    return 'ต้องกำหนดจำนวนลัดให้ครบ 3 ค่า';
  }
  if (amountsSatang.any(
    (amount) => amount <= 0 || amount > maxMoneyInputSatang,
  )) {
    return 'แต่ละค่าต้องมากกว่า 0 และไม่เกินเพดานต่อรายการ';
  }
  if (amountsSatang.toSet().length != amountsSatang.length) {
    return 'จำนวนลัดต้องไม่ซ้ำกัน';
  }
  return null;
}

List<int> validQuickSavingAmountsOrDefault(Iterable<int> values) {
  final amounts = List<int>.from(values);
  return validateQuickSavingAmounts(amounts) == null
      ? List<int>.unmodifiable(amounts)
      : defaultQuickSavingAmountsSatang;
}

class QuickGoalOption {
  const QuickGoalOption({required this.id, required this.name});

  final String id;
  final String name;
}

enum QuickGoalSelectionMode { unavailable, direct, choose }

class QuickGoalSelection {
  const QuickGoalSelection({required this.mode, this.selectedGoalId});

  final QuickGoalSelectionMode mode;
  final String? selectedGoalId;
}

QuickGoalSelection decideQuickGoalSelection(List<QuickGoalOption> goals) {
  if (goals.isEmpty) {
    return const QuickGoalSelection(mode: QuickGoalSelectionMode.unavailable);
  }
  if (goals.length == 1) {
    return QuickGoalSelection(
      mode: QuickGoalSelectionMode.direct,
      selectedGoalId: goals.single.id,
    );
  }
  return const QuickGoalSelection(mode: QuickGoalSelectionMode.choose);
}

class QuickSavingFeedback {
  const QuickSavingFeedback({
    required this.goalName,
    required this.beforeSatang,
    required this.afterSatang,
    required this.targetSatang,
    required this.flexible,
    required this.expGained,
    required this.progressPercent,
  });

  final String goalName;
  final int beforeSatang;
  final int afterSatang;
  final int targetSatang;
  final bool flexible;
  final int expGained;
  final int? progressPercent;
}

QuickSavingFeedback buildQuickSavingFeedback({
  required String goalName,
  required int beforeSatang,
  required int afterSatang,
  required int targetSatang,
  required bool flexible,
  required int expGained,
}) {
  final progressPercent = flexible || targetSatang <= 0
      ? null
      : ((afterSatang * 100) ~/ targetSatang).clamp(0, 100);
  return QuickSavingFeedback(
    goalName: goalName,
    beforeSatang: beforeSatang,
    afterSatang: afterSatang,
    targetSatang: targetSatang,
    flexible: flexible,
    expGained: expGained,
    progressPercent: progressPercent,
  );
}
