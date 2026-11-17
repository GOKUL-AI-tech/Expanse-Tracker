import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/budget_model.dart';
import '../../../data/repositories/budget_repository.dart';

class BudgetFilters {
  final int? month;
  final int? year;

  const BudgetFilters({this.month, this.year});

  @override
  bool operator ==(Object other) =>
      other is BudgetFilters && other.month == month && other.year == year;

  @override
  int get hashCode => Object.hash(month, year);
}

final budgetsProvider =
    FutureProvider.family<List<BudgetModel>, BudgetFilters>((ref, filters) async {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.getBudgets(month: filters.month, year: filters.year);
});

class BudgetNotifier extends StateNotifier<AsyncValue<void>> {
  final BudgetRepository _repo;
  final Ref _ref;

  BudgetNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<bool> addBudget(BudgetModel budget) async {
    state = const AsyncValue.loading();
    try {
      await _repo.addBudget(budget);
      state = const AsyncValue.data(null);
      _ref.invalidate(budgetsProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }

  Future<bool> updateBudget(BudgetModel budget) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateBudget(budget);
      state = const AsyncValue.data(null);
      _ref.invalidate(budgetsProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }

  Future<bool> deleteBudget(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.deleteBudget(id);
      state = const AsyncValue.data(null);
      _ref.invalidate(budgetsProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }
}

final budgetNotifierProvider =
    StateNotifierProvider<BudgetNotifier, AsyncValue<void>>((ref) {
  return BudgetNotifier(ref.watch(budgetRepositoryProvider), ref);
});
