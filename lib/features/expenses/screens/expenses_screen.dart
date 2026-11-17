import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';
import '../providers/expense_provider.dart';
import '../../profile/providers/profile_provider.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = '';
  String _searchQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  ExpenseFilters get _filters => ExpenseFilters(
        from: _fromDate,
        to: _toDate,
        category: _selectedCategory.isEmpty ? null : _selectedCategory,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider(_filters));
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/expenses/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search expenses...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Category Filter
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _selectedCategory.isEmpty,
                  onSelected: (_) => setState(() => _selectedCategory = ''),
                ),
                ...AppConstants.expenseCategories.map(
                  (c) => _FilterChip(
                    label: c,
                    selected: _selectedCategory == c,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = c),
                  ),
                ),
              ],
            ),
          ),

          // Expense List
          Expanded(
            child: expenses.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyState(isDark: isDark);
                }

                // Group by date
                final grouped = <String, List<ExpenseModel>>{};
                for (final e in list) {
                  final key = DateFormatter.formatDate(e.date);
                  grouped.putIfAbsent(key, () => []).add(e);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.length,
                  itemBuilder: (ctx, i) {
                    final date = grouped.keys.elementAt(i);
                    final dayExpenses = grouped[date]!;
                    final dayTotal = dayExpenses.fold(
                        0.0, (sum, e) => sum + e.amount);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                date,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkSubtext
                                      : AppColors.lightSubtext,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(dayTotal, currency),
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...dayExpenses.map(
                          (e) => _ExpenseTile(
                            expense: e,
                            currency: currency,
                            isDark: isDark,
                            onEdit: () => context.push(
                              '/expenses/add',
                              extra: e.toMap()..['id'] = e.id,
                            ),
                            onDelete: () => _confirmDelete(context, e.id),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Expense', style: GoogleFonts.poppins()),
        content: Text('Are you sure you want to delete this expense?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(expenseNotifierProvider.notifier).deleteExpense(id);
            },
            child: Text('Delete',
                style: GoogleFonts.poppins(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText),
          ),
        ),
      ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  final ExpenseModel expense;
  final String currency;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExpenseTile({
    required this.expense,
    required this.currency,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  void _viewReceipt(BuildContext context, WidgetRef ref) {
    final repo = ref.read(expenseRepositoryProvider);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FutureBuilder<String>(
                future: repo.getReceiptSignedUrl(expense.receiptUrl!),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 300,
                      color: Colors.black,
                      child: const Center(
                          child: CircularProgressIndicator(color: Colors.white)),
                    );
                  }
                  if (snap.hasError || !snap.hasData) {
                    return Container(
                      height: 200,
                      color: Colors.black,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image, color: Colors.white54, size: 48),
                            SizedBox(height: 8),
                            Text('Could not load receipt',
                                style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
                    );
                  }
                  return InteractiveViewer(
                    child: Image.network(
                      snap.data!,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : Container(
                              height: 300,
                              color: Colors.black,
                              child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white)),
                            ),
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.black,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, color: Colors.white54, size: 48),
                              SizedBox(height: 8),
                              Text('Could not load receipt',
                                  style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.expense.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            AppConstants.categoryIcons[expense.category] ?? '💰',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          expense.description ?? expense.category,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${expense.category} • ${expense.paymentMethod}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-${CurrencyFormatter.format(expense.amount, currency)}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.expense,
                  ),
                ),
                if (expense.receiptUrl != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_outlined,
                          size: 11,
                          color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
                      const SizedBox(width: 2),
                      Text('receipt',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
                    ],
                  ),
              ],
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
                if (v == 'receipt') _viewReceipt(context, ref);
              },
              itemBuilder: (ctx) => [
                if (expense.receiptUrl != null)
                  PopupMenuItem(
                    value: 'receipt',
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 16),
                        const SizedBox(width: 8),
                        Text('View Receipt', style: GoogleFonts.poppins()),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 16),
                      const SizedBox(width: 8),
                      Text('Edit', style: GoogleFonts.poppins()),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text('Delete',
                          style: GoogleFonts.poppins(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 80,
              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
          const SizedBox(height: 16),
          Text('No expenses found',
              style: GoogleFonts.poppins(
                  color:
                      isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
        ],
      ),
    );
  }
}
