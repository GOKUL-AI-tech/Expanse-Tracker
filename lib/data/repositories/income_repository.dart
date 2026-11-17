import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/income_model.dart';
import '../../features/auth/providers/auth_provider.dart';

class IncomeRepository {
  final SupabaseClient _supabase;
  final String _userId;

  IncomeRepository(this._supabase, this._userId);

  Future<List<IncomeModel>> getIncome({
    DateTime? from,
    DateTime? to,
    String? category,
    String? searchQuery,
  }) async {
    final data = await _supabase
        .from('income')
        .select()
        .eq('user_id', _userId)
        .order('date', ascending: false);

    var incomes = data.map((e) => IncomeModel.fromMap(e)).toList();

    if (from != null) {
      incomes = incomes.where((i) => i.date.isAfter(from.subtract(const Duration(days: 1)))).toList();
    }
    if (to != null) {
      incomes = incomes.where((i) => i.date.isBefore(to.add(const Duration(days: 1)))).toList();
    }
    if (category != null && category.isNotEmpty) {
      incomes = incomes.where((i) => i.category == category).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      incomes = incomes.where((i) =>
          (i.description?.toLowerCase().contains(q) ?? false) ||
          i.category.toLowerCase().contains(q)).toList();
    }

    return incomes;
  }

  Future<IncomeModel> addIncome(IncomeModel income) async {
    final data = await _supabase
        .from('income')
        .insert(income.toMap())
        .select()
        .single();
    return IncomeModel.fromMap(data);
  }

  Future<IncomeModel> updateIncome(IncomeModel income) async {
    final data = await _supabase
        .from('income')
        .update(income.toMap())
        .eq('id', income.id)
        .eq('user_id', _userId)
        .select()
        .single();
    return IncomeModel.fromMap(data);
  }

  Future<void> deleteIncome(String id) async {
    await _supabase
        .from('income')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<double> getTotalIncome({DateTime? from, DateTime? to}) async {
    final incomes = await getIncome(from: from, to: to);
    return incomes.fold<double>(0.0, (sum, i) => sum + i.amount);
  }

  Future<Map<String, double>> getCategoryTotals({
    DateTime? from,
    DateTime? to,
  }) async {
    final incomes = await getIncome(from: from, to: to);
    final Map<String, double> totals = {};
    for (final i in incomes) {
      totals[i.category] = (totals[i.category] ?? 0) + i.amount;
    }
    return totals;
  }
}

final incomeRepositoryProvider = Provider<IncomeRepository>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = ref.watch(currentUserProvider);
  return IncomeRepository(supabase, user?.id ?? '');
});
