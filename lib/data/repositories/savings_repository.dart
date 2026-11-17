import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/savings_goal_model.dart';
import '../../features/auth/providers/auth_provider.dart';

class SavingsRepository {
  final SupabaseClient _supabase;
  final String _userId;

  SavingsRepository(this._supabase, this._userId);

  Future<List<SavingsGoalModel>> getSavingsGoals() async {
    final data = await _supabase
        .from('savings_goals')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return data.map((e) => SavingsGoalModel.fromMap(e)).toList();
  }

  Future<SavingsGoalModel> addGoal(SavingsGoalModel goal) async {
    final data = await _supabase
        .from('savings_goals')
        .insert(goal.toMap())
        .select()
        .single();
    return SavingsGoalModel.fromMap(data);
  }

  Future<SavingsGoalModel> updateGoal(SavingsGoalModel goal) async {
    final data = await _supabase
        .from('savings_goals')
        .update(goal.toMap())
        .eq('id', goal.id)
        .eq('user_id', _userId)
        .select()
        .single();
    return SavingsGoalModel.fromMap(data);
  }

  Future<void> deleteGoal(String id) async {
    await _supabase
        .from('savings_goals')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<double> getTotalSavings() async {
    final goals = await getSavingsGoals();
    return goals.fold<double>(0.0, (sum, g) => sum + g.currentAmount);
  }
}

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = ref.watch(currentUserProvider);
  return SavingsRepository(supabase, user?.id ?? '');
});
