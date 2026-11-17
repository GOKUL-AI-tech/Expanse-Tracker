import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/savings_goal_model.dart';
import '../../../data/repositories/savings_repository.dart';

final savingsGoalsProvider = FutureProvider<List<SavingsGoalModel>>((ref) async {
  final repo = ref.watch(savingsRepositoryProvider);
  return repo.getSavingsGoals();
});

class SavingsNotifier extends StateNotifier<AsyncValue<void>> {
  final SavingsRepository _repo;
  final Ref _ref;

  SavingsNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<bool> addGoal(SavingsGoalModel goal) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addGoal(goal);
      state = const AsyncValue.data(null);
      _ref.invalidate(savingsGoalsProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }

  Future<bool> updateGoal(SavingsGoalModel goal) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateGoal(goal);
      state = const AsyncValue.data(null);
      _ref.invalidate(savingsGoalsProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }

  Future<bool> deleteGoal(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteGoal(id);
      state = const AsyncValue.data(null);
      _ref.invalidate(savingsGoalsProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }
}

final savingsNotifierProvider =
    StateNotifierProvider<SavingsNotifier, AsyncValue<void>>((ref) {
  return SavingsNotifier(ref.watch(savingsRepositoryProvider), ref);
});
