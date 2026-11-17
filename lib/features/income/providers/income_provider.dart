import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/income_model.dart';
import '../../../data/repositories/income_repository.dart';
import '../../dashboard/screens/dashboard_screen.dart';

class IncomeFilters {
  final String? category;
  final String? searchQuery;

  const IncomeFilters({this.category, this.searchQuery});

  @override
  bool operator ==(Object other) =>
      other is IncomeFilters &&
      other.category == category &&
      other.searchQuery == searchQuery;

  @override
  int get hashCode => Object.hash(category, searchQuery);
}

final incomeListProvider =
    FutureProvider.family<List<IncomeModel>, IncomeFilters>((ref, filters) async {
  final repo = ref.watch(incomeRepositoryProvider);
  return repo.getIncome(
    category: filters.category,
    searchQuery: filters.searchQuery,
  );
});

class IncomeNotifier extends StateNotifier<AsyncValue<void>> {
  final IncomeRepository _repo;
  final Ref _ref;

  IncomeNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<bool> addIncome(IncomeModel income) async {
    try {
      await _repo.addIncome(income);
      _ref.invalidate(incomeListProvider);
      _ref.invalidate(dashboardSummaryProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }

  Future<bool> updateIncome(IncomeModel income) async {
    try {
      await _repo.updateIncome(income);
      _ref.invalidate(incomeListProvider);
      _ref.invalidate(dashboardSummaryProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }

  Future<bool> deleteIncome(String id) async {
    try {
      await _repo.deleteIncome(id);
      _ref.invalidate(incomeListProvider);
      _ref.invalidate(dashboardSummaryProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }
}

final incomeNotifierProvider =
    StateNotifierProvider<IncomeNotifier, AsyncValue<void>>((ref) {
  return IncomeNotifier(ref.watch(incomeRepositoryProvider), ref);
});
