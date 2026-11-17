import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../dashboard/screens/dashboard_screen.dart';

// Stable key — value equality prevents FutureProvider.family re-fetching on every rebuild
class ExpenseFilters {
  final DateTime? from;
  final DateTime? to;
  final String? category;
  final String? searchQuery;

  const ExpenseFilters({this.from, this.to, this.category, this.searchQuery});

  @override
  bool operator ==(Object other) =>
      other is ExpenseFilters &&
      other.from == from &&
      other.to == to &&
      other.category == category &&
      other.searchQuery == searchQuery;

  @override
  int get hashCode => Object.hash(from, to, category, searchQuery);
}

final expensesProvider =
    FutureProvider.family<List<ExpenseModel>, ExpenseFilters>((ref, filters) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpenses(
    from: filters.from,
    to: filters.to,
    category: filters.category,
    searchQuery: filters.searchQuery,
  );
});

class ExpenseNotifier extends StateNotifier<AsyncValue<void>> {
  final ExpenseRepository _repo;
  final Ref _ref;

  ExpenseNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<bool> addExpense(ExpenseModel expense) async {
    try {
      await _repo.addExpense(expense);
      _ref.invalidate(expensesProvider);
      _ref.invalidate(dashboardSummaryProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }

  Future<bool> updateExpense(ExpenseModel expense) async {
    try {
      await _repo.updateExpense(expense);
      _ref.invalidate(expensesProvider);
      _ref.invalidate(dashboardSummaryProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }

  Future<bool> deleteExpense(String id) async {
    try {
      await _repo.deleteExpense(id);
      _ref.invalidate(expensesProvider);
      _ref.invalidate(dashboardSummaryProvider);
      return true;
    } catch (e, s) {
      state = AsyncValue.error(e, s);
      return false;
    }
  }
}

final expenseNotifierProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<void>>((ref) {
  return ExpenseNotifier(ref.watch(expenseRepositoryProvider), ref);
});
