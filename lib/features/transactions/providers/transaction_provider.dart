import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/income_repository.dart';

class Transaction {
  final String id;
  final String type; // 'expense' or 'income'
  final double amount;
  final String category;
  final String description;
  final DateTime date;
  final String? paymentMethod;
  final String? notes;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
    this.paymentMethod,
    this.notes,
  });
}

// Proper filter class with value equality so FutureProvider.family doesn't
// treat every rebuild as a new key and re-fetch infinitely.
class TransactionFilters {
  final String? type;
  final String? search;
  final DateTime? from;
  final DateTime? to;

  const TransactionFilters({this.type, this.search, this.from, this.to});

  @override
  bool operator ==(Object other) =>
      other is TransactionFilters &&
      other.type == type &&
      other.search == search &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(type, search, from, to);
}

final allTransactionsProvider =
    FutureProvider.family<List<Transaction>, TransactionFilters>(
        (ref, filters) async {
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final incomeRepo = ref.watch(incomeRepositoryProvider);

  final transactions = <Transaction>[];

  if (filters.type == null || filters.type == 'expense') {
    final expenses = await expenseRepo.getExpenses(
      from: filters.from,
      to: filters.to,
      searchQuery: filters.search,
    );
    for (final e in expenses) {
      transactions.add(Transaction(
        id: e.id,
        type: 'expense',
        amount: e.amount,
        category: e.category,
        description: e.description ?? e.category,
        date: e.date,
        paymentMethod: e.paymentMethod,
        notes: e.notes,
      ));
    }
  }

  if (filters.type == null || filters.type == 'income') {
    final incomes = await incomeRepo.getIncome(
      from: filters.from,
      to: filters.to,
      searchQuery: filters.search,
    );
    for (final i in incomes) {
      transactions.add(Transaction(
        id: i.id,
        type: 'income',
        amount: i.amount,
        category: i.category,
        description: i.description ?? i.category,
        date: i.date,
      ));
    }
  }

  transactions.sort((a, b) => b.date.compareTo(a.date));
  return transactions;
});
