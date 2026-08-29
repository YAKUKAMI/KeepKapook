part of 'app_state.dart';

extension NextGoalActions on AppState {
  NextGoalOffer nextGoalOfferAfter(Set<String> newlyCompletedGoalIds) {
    return selectNextGoalOffer(
      goals: goals.map(NextGoalOfferInput.fromGoal),
      newlyCompletedGoalIds: newlyCompletedGoalIds,
      unallocatedSatang: unallocatedSatang,
    );
  }
}
