import '../models/models.dart';

enum NextGoalOfferKind { continueExisting, createNew }

class NextGoalOfferInput {
  const NextGoalOfferInput({
    required this.id,
    required this.name,
    required this.currentSatang,
    required this.targetSatang,
    required this.completed,
    required this.flexible,
  });

  factory NextGoalOfferInput.fromGoal(Goal goal) => NextGoalOfferInput(
        id: goal.id,
        name: goal.name,
        currentSatang: goal.currentSatang,
        targetSatang: goal.targetSatang,
        completed: goal.isCompleted,
        flexible: goal.flexible,
      );

  final String id;
  final String name;
  final int currentSatang;
  final int targetSatang;
  final bool completed;
  final bool flexible;

  int get remainingSatang {
    final remaining = targetSatang - currentSatang;
    return remaining > 0 ? remaining : 0;
  }
}

class NextGoalOffer {
  const NextGoalOffer._({
    required this.kind,
    required this.unallocatedSatang,
    this.goalId,
    this.goalName,
    this.remainingSatang = 0,
    this.allocatableSatang = 0,
  });

  const NextGoalOffer.continueExisting({
    required String goalId,
    required String goalName,
    required int remainingSatang,
    required int unallocatedSatang,
    required int allocatableSatang,
  }) : this._(
          kind: NextGoalOfferKind.continueExisting,
          goalId: goalId,
          goalName: goalName,
          remainingSatang: remainingSatang,
          unallocatedSatang: unallocatedSatang,
          allocatableSatang: allocatableSatang,
        );

  const NextGoalOffer.createNew({required int unallocatedSatang})
      : this._(
          kind: NextGoalOfferKind.createNew,
          unallocatedSatang: unallocatedSatang,
        );

  final NextGoalOfferKind kind;
  final String? goalId;
  final String? goalName;
  final int remainingSatang;
  final int unallocatedSatang;
  final int allocatableSatang;
}

NextGoalOffer selectNextGoalOffer({
  required Iterable<NextGoalOfferInput> goals,
  required Set<String> newlyCompletedGoalIds,
  required int unallocatedSatang,
}) {
  final availableSatang = unallocatedSatang > 0 ? unallocatedSatang : 0;
  final candidates = goals
      .where(
        (goal) =>
            !newlyCompletedGoalIds.contains(goal.id) &&
            !goal.completed &&
            !goal.flexible &&
            goal.remainingSatang > 0,
      )
      .toList()
    ..sort((left, right) {
      final byRemaining = left.remainingSatang.compareTo(right.remainingSatang);
      return byRemaining != 0 ? byRemaining : left.id.compareTo(right.id);
    });
  if (candidates.isEmpty) {
    return NextGoalOffer.createNew(unallocatedSatang: availableSatang);
  }

  final goal = candidates.first;
  final allocatableSatang = availableSatang < goal.remainingSatang
      ? availableSatang
      : goal.remainingSatang;
  return NextGoalOffer.continueExisting(
    goalId: goal.id,
    goalName: goal.name,
    remainingSatang: goal.remainingSatang,
    unallocatedSatang: availableSatang,
    allocatableSatang: allocatableSatang,
  );
}
