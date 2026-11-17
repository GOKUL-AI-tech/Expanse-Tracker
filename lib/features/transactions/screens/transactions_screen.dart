import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/transaction_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../expenses/providers/expense_provider.dart';
import '../../income/providers/income_provider.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _searchCtrl = TextEditingController();
  String _type = 'all'; // all, expense, income
  String _search = '';
  DateTime? _from;
  DateTime? _to;
  String _sortBy = 'date';
  int? _touchedPieIndex;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  TransactionFilters get _filters => TransactionFilters(
        type: _type == 'all' ? null : _type,
        search: _search.isEmpty ? null : _search,
        from: _from,
        to: _to,
      );

  Future<void> _deleteTransaction(Transaction t) async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Transaction',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
            'Delete "${t.description}"? This cannot be undone.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: AppColors.lightSubtext))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    bool success;
    if (t.type == 'expense') {
      success = await ref.read(expenseNotifierProvider.notifier).deleteExpense(t.id);
    } else {
      success = await ref.read(incomeNotifierProvider.notifier).deleteIncome(t.id);
    }
    ref.invalidate(allTransactionsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Transaction deleted' : 'Failed to delete'),
        backgroundColor: success ? AppColors.income : AppColors.error,
      ));
    }
  }

  void _editTransaction(Transaction t) {
    if (t.type == 'expense') {
      context.push('/expenses/add', extra: {
        'id': t.id,
        'amount': t.amount,
        'category': t.category,
        'description': t.description,
        'notes': t.notes,
        'payment_method': t.paymentMethod ?? 'Cash',
        'date': t.date.toIso8601String(),
      });
    } else {
      context.push('/income/add', extra: {
        'id': t.id,
        'amount': t.amount,
        'category': t.category,
        'description': t.description,
        'notes': t.notes,
        'date': t.date.toIso8601String(),
      });
    }
    // Refresh after returning
    ref.invalidate(allTransactionsProvider);
  }

  void _showActionSheet(Transaction t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (t.type == 'expense' ? AppColors.expense : AppColors.income)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_emoji(t.category), style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.description,
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(t.category,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
                ],
              )),
              Text(
                '${t.type == "expense" ? "-" : "+"}${CurrencyFormatter.format(t.amount, ref.read(currencyProvider))}',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: t.type == 'expense' ? AppColors.expense : AppColors.income),
              ),
            ]),
            const SizedBox(height: 20),
            // Edit button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: Text('Edit Transaction',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  _editTransaction(t);
                },
              ),
            ),
            const SizedBox(height: 10),
            // Delete button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_rounded, size: 18),
                label: Text('Delete Transaction',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  _deleteTransaction(t);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emoji(String category) {
    const icons = {
      'Food': '🍔', 'Travel': '✈️', 'Shopping': '🛍️', 'Entertainment': '🎬',
      'Education': '📚', 'Healthcare': '🏥', 'Rent': '🏠', 'Bills': '📄',
      'Fuel': '⛽', 'Subscription': '📱', 'Investment': '📈',
      'Salary': '💼', 'Freelancing': '💻', 'Business': '🏢', 'Scholarship': '🎓',
    };
    return icons[category] ?? '💰';
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(allTransactionsProvider(_filters));
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Type Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _TypeTab(label: 'All', value: 'all', selected: _type, onTap: (v) => setState(() => _type = v)),
                const SizedBox(width: 8),
                _TypeTab(label: 'Expense', value: 'expense', selected: _type, onTap: (v) => setState(() => _type = v), color: AppColors.expense),
                const SizedBox(width: 8),
                _TypeTab(label: 'Income', value: 'income', selected: _type, onTap: (v) => setState(() => _type = v), color: AppColors.income),
              ],
            ),
          ),

          Expanded(
            child: transactions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                // Sort
                final sorted = [...list];
                if (_sortBy == 'amount') sorted.sort((a, b) => b.amount.compareTo(a.amount));
                if (_sortBy == 'category') sorted.sort((a, b) => a.category.compareTo(b.category));

                if (sorted.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 80,
                            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
                        const SizedBox(height: 16),
                        Text('No transactions found', style: GoogleFonts.poppins()),
                      ],
                    ),
                  );
                }

                // Group by date
                final grouped = <String, List<Transaction>>{};
                for (final t in sorted) {
                  final key = DateFormatter.formatDate(t.date);
                  grouped.putIfAbsent(key, () => []).add(t);
                }

                // Build pie chart data
                final categoryTotals = <String, double>{};
                for (final t in sorted) {
                  categoryTotals[t.category] =
                      (categoryTotals[t.category] ?? 0) + t.amount;
                }
                final sortedCategories = categoryTotals.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: grouped.length + 1, // +1 for chart header
                  itemBuilder: (ctx, i) {
                    // First item: pie chart
                    if (i == 0) {
                      return _PieChartCard(
                        categories: sortedCategories,
                        currency: currency,
                        isDark: isDark,
                        type: _type,
                        touchedIndex: _touchedPieIndex,
                        onTouch: (idx) => setState(() => _touchedPieIndex = idx),
                      );
                    }

                    final dateIdx = i - 1;
                    final date = grouped.keys.elementAt(dateIdx);
                    final dayTxns = grouped[date]!;
                    final dayIncome = dayTxns.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
                    final dayExpense = dayTxns.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(date, style: GoogleFonts.poppins(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
                              Row(
                                children: [
                                  if (dayIncome > 0)
                                    Text('+${CurrencyFormatter.formatCompact(dayIncome, currency)}',
                                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.income)),
                                  if (dayIncome > 0 && dayExpense > 0) const Text('  '),
                                  if (dayExpense > 0)
                                    Text('-${CurrencyFormatter.formatCompact(dayExpense, currency)}',
                                        style: GoogleFonts.poppins(fontSize: 12, color: AppColors.expense)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ...dayTxns.map((t) => _SwipableTile(
                              transaction: t,
                              currency: currency,
                              isDark: isDark,
                              onEdit: () => _editTransaction(t),
                              onDelete: () => _deleteTransaction(t),
                              onLongPress: () => _showActionSheet(t),
                            )),
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

  void _showFilterSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Sort By',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['date', 'amount', 'category'].map((s) {
                final isSelected = _sortBy == s;
                return GestureDetector(
                  onTap: () {
                    setState(() => _sortBy = s);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected ? AppColors.primary : borderColor),
                    ),
                    child: Text(
                      s.toUpperCase(),
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : textColor),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text('Date Range',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.dateFilters.take(6).map((f) {
                final isActive = (_from != null || _to != null) &&
                    _dateRangeFromFilter(f).$1 == _from &&
                    _dateRangeFromFilter(f).$2 == _to;
                return GestureDetector(
                  onTap: () {
                    final range = _dateRangeFromFilter(f);
                    setState(() {
                      _from = range.$1;
                      _to = range.$2;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.accent.withOpacity(0.15) : cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isActive ? AppColors.accent : borderColor),
                    ),
                    child: Text(
                      f,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isActive ? AppColors.accent : textColor),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  (DateTime?, DateTime?) _dateRangeFromFilter(String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'Today':
        return (DateTime(now.year, now.month, now.day), now);
      case 'Last 7 Days':
        return (now.subtract(const Duration(days: 7)), now);
      case 'Last 30 Days':
        return (now.subtract(const Duration(days: 30)), now);
      case 'Last 3 Months':
        return (now.subtract(const Duration(days: 90)), now);
      case 'Last 6 Months':
        return (now.subtract(const Duration(days: 180)), now);
      case 'Last 1 Year':
        return (now.subtract(const Duration(days: 365)), now);
      default:
        return (null, null);
    }
  }
}

// ── Pie Chart Card ──────────────────────────────────────────────────────────

class _PieChartCard extends StatelessWidget {
  final List<MapEntry<String, double>> categories;
  final String currency;
  final bool isDark;
  final String type;
  final int? touchedIndex;
  final ValueChanged<int?> onTouch;

  const _PieChartCard({
    required this.categories,
    required this.currency,
    required this.isDark,
    required this.type,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    final total = categories.fold(0.0, (s, e) => s + e.value);
    final title = type == 'expense'
        ? 'Expense Breakdown'
        : type == 'income'
            ? 'Income Breakdown'
            : 'Category Breakdown';

    // Take top 6 categories, group rest as "Others"
    final top = categories.take(6).toList();
    final othersTotal = categories.skip(6).fold(0.0, (s, e) => s + e.value);
    if (othersTotal > 0) top.add(MapEntry('Others', othersTotal));

    final sections = List.generate(top.length, (i) {
      final isTouched = touchedIndex == i;
      final pct = total > 0 ? top[i].value / total * 100 : 0.0;
      return PieChartSectionData(
        color: AppColors.chartColors[i % AppColors.chartColors.length],
        value: top[i].value,
        title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
        radius: isTouched ? 68 : 56,
        titleStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        badgeWidget: isTouched
            ? null
            : null,
      );
    });

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(
                CurrencyFormatter.formatCompact(total, currency),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Pie chart
              SizedBox(
                height: 160,
                width: 160,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 36,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.touchedSection == null) {
                          onTouch(null);
                          return;
                        }
                        onTouch(response.touchedSection!.touchedSectionIndex);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(top.length, (i) {
                    final pct = total > 0 ? top[i].value / total * 100 : 0.0;
                    final color = AppColors.chartColors[i % AppColors.chartColors.length];
                    final isHighlighted = touchedIndex == i;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              top[i].key,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.normal,
                                color: isHighlighted
                                    ? color
                                    : (isDark ? AppColors.darkText : AppColors.lightText),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          if (touchedIndex != null && touchedIndex! < top.length) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.chartColors[touchedIndex! % AppColors.chartColors.length]
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    top[touchedIndex!].key,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    CurrencyFormatter.format(top[touchedIndex!].value, currency),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.chartColors[touchedIndex! % AppColors.chartColors.length],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Type Tab ────────────────────────────────────────────────────────────────

class _TypeTab extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;
  final Color? color;

  const _TypeTab({required this.label, required this.value, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? c.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? c : Colors.grey.withOpacity(0.4)),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13,
                color: isSelected ? c : null,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

// ── Swipable Transaction Tile ────────────────────────────────────────────────

class _SwipableTile extends StatelessWidget {
  final Transaction transaction;
  final String currency;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;

  const _SwipableTile({
    required this.transaction,
    required this.currency,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'expense';
    final color = isExpense ? AppColors.expense : AppColors.income;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // let the delete handler manage actual removal
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_emoji(transaction.category),
                    style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transaction.description,
                        style: GoogleFonts.poppins(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '${transaction.category}${transaction.paymentMethod != null ? ' • ${transaction.paymentMethod}' : ''}',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext),
                    ),
                  ],
                ),
              ),
              Text(
                '${isExpense ? '-' : '+'}${CurrencyFormatter.format(transaction.amount, currency)}',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600, color: color),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onLongPress,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.more_vert_rounded,
                      size: 20,
                      color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _emoji(String category) {
    const icons = {
      'Food': '🍔', 'Travel': '✈️', 'Shopping': '🛍️', 'Entertainment': '🎬',
      'Education': '📚', 'Healthcare': '🏥', 'Rent': '🏠', 'Bills': '📄',
      'Fuel': '⛽', 'Subscription': '📱', 'Investment': '📈',
      'Salary': '💼', 'Freelancing': '💻', 'Business': '🏢', 'Scholarship': '🎓',
    };
    return icons[category] ?? '💰';
  }
}
