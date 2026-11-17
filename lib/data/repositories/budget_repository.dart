import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/budget_model.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'expense_repository.dart';

class BudgetRepository {
  final SupabaseClient _supabase;
  final String _userId;
  final ExpenseRepository _expenseRepo;

  BudgetRepository(this._supabase, this._userId, this._expenseRepo);

  Future<List<BudgetModel>> getBudgets({int? month, int? year}) async {
    var query = _supabase.from('budgets').select().eq('user_id', _userId);

    if (month != null) query = query.eq('month', month);
    if (year != null) query = query.eq('year', year);

    final data = await query.order('created_at', ascending: false);
    final budgets = data.map((e) => BudgetModel.fromMap(e)).toList();

    // Attach spent amounts
    final now = DateTime.now();
    final m = month ?? now.month;
    final y = year ?? now.year;
    final from = DateTime(y, m, 1);
    final to = DateTime(y, m + 1, 0);
    final categoryTotals =
        await _expenseRepo.getCategoryTotals(from: from, to: to);

    return budgets
        .map((b) => b.copyWith(spent: categoryTotals[b.category] ?? 0))
        .toList();
  }

  Future<BudgetModel> addBudget(BudgetModel budget) async {
    final data = await _supabase
        .from('budgets')
        .insert(budget.toMap())
        .select()
        .single();
    return BudgetModel.fromMap(data);
  }

  Future<BudgetModel> updateBudget(BudgetModel budget) async {
    final data = await _supabase
        .from('budgets')
        .update(budget.toMap())
        .eq('id', budget.id)
        .eq('user_id', _userId)
        .select()
        .single();
    return BudgetModel.fromMap(data);
  }

  Future<void> deleteBudget(String id) async {
    await _supabase
        .from('budgets')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = ref.watch(currentUserProvider);
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  return BudgetRepository(supabase, user?.id ?? '', expenseRepo);
});
