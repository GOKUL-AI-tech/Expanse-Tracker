import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/expense_model.dart';
import '../../features/auth/providers/auth_provider.dart';

class ExpenseRepository {
  final SupabaseClient _supabase;
  final String _userId;

  ExpenseRepository(this._supabase, this._userId);

  Future<List<ExpenseModel>> getExpenses({
    DateTime? from,
    DateTime? to,
    String? category,
    String? searchQuery,
  }) async {
    var query = _supabase
        .from('expenses')
        .select()
        .eq('user_id', _userId)
        .order('date', ascending: false);

    final data = await query;
    var expenses = data.map((e) => ExpenseModel.fromMap(e)).toList();

    if (from != null) {
      expenses = expenses.where((e) => e.date.isAfter(from.subtract(const Duration(days: 1)))).toList();
    }
    if (to != null) {
      expenses = expenses.where((e) => e.date.isBefore(to.add(const Duration(days: 1)))).toList();
    }
    if (category != null && category.isNotEmpty) {
      expenses = expenses.where((e) => e.category == category).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      expenses = expenses.where((e) =>
          (e.description?.toLowerCase().contains(q) ?? false) ||
          e.category.toLowerCase().contains(q)).toList();
    }

    return expenses;
  }

  Future<ExpenseModel> addExpense(ExpenseModel expense) async {
    final data = await _supabase
        .from('expenses')
        .insert(expense.toMap())
        .select()
        .single();
    return ExpenseModel.fromMap(data);
  }

  Future<ExpenseModel> updateExpense(ExpenseModel expense) async {
    final data = await _supabase
        .from('expenses')
        .update(expense.toMap())
        .eq('id', expense.id)
        .eq('user_id', _userId)
        .select()
        .single();
    return ExpenseModel.fromMap(data);
  }

  Future<void> deleteExpense(String id) async {
    await _supabase
        .from('expenses')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  Future<String> uploadReceipt(String expenseId, File file) async {
    final ext = file.path.split('.').last;
    final path = '$_userId/$expenseId.$ext';
    await _supabase.storage.from('receipts').upload(
      path,
      file,
      fileOptions: const FileOptions(upsert: true),
    );
    // Store the storage path, not a public URL.
    // We'll generate signed URLs at display time.
    return path;
  }

  /// Returns a short-lived signed URL for displaying a receipt.
  /// Accepts either a raw storage path OR a legacy full URL
  /// (older records stored the full public URL).
  Future<String> getReceiptSignedUrl(String pathOrLegacyUrl) async {
    String storagePath = pathOrLegacyUrl;
    // Handle legacy records where the full URL was stored
    if (pathOrLegacyUrl.contains('/receipts/')) {
      storagePath = pathOrLegacyUrl.split('/receipts/').last;
      // Strip any query params (e.g. ?token=...)
      storagePath = storagePath.split('?').first;
    }
    return await _supabase.storage
        .from('receipts')
        .createSignedUrl(storagePath, 60 * 60); // 1 hour
  }

  Future<void> deleteReceipt(String pathOrLegacyUrl) async {
    String storagePath = pathOrLegacyUrl;
    if (pathOrLegacyUrl.contains('/receipts/')) {
      storagePath = pathOrLegacyUrl.split('/receipts/').last.split('?').first;
    }
    await _supabase.storage.from('receipts').remove([storagePath]);
  }

  Future<Map<String, double>> getCategoryTotals({
    DateTime? from,
    DateTime? to,
  }) async {
    final expenses = await getExpenses(from: from, to: to);
    final Map<String, double> totals = {};
    for (final e in expenses) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
    }
    return totals;
  }

  Future<double> getTotalExpenses({DateTime? from, DateTime? to}) async {
    final expenses = await getExpenses(from: from, to: to);
    return expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final user = ref.watch(currentUserProvider);
  return ExpenseRepository(supabase, user?.id ?? '');
});
