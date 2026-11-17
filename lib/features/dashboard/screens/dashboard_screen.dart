import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/income_repository.dart';
import '../../../data/repositories/savings_repository.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/income_model.dart';
import '../../profile/providers/profile_provider.dart';
import '../../auth/providers/auth_provider.dart';

// Dashboard summary provider
final dashboardSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(now.year, now.month + 1, 0);

  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final incomeRepo = ref.watch(incomeRepositoryProvider);
  final savingsRepo = ref.watch(savingsRepositoryProvider);

  // Fire all 5 calls in parallel
  final results = await Future.wait([
    expenseRepo.getTotalExpenses(from: from, to: to),
    incomeRepo.getTotalIncome(from: from, to: to),
    savingsRepo.getTotalSavings(),
    expenseRepo.getExpenses(from: from, to: to),
    incomeRepo.getIncome(from: from, to: to),
  ]);
  final totalExpenses  = results[0] as double;
  final totalIncome    = results[1] as double;
  final totalSavings   = results[2] as double;
  final recentExpenses = results[3] as List<dynamic>;
  final recentIncome   = results[4] as List<dynamic>;

  // Merge and sort recent transactions
  final transactions = <Map<String, dynamic>>[];
  for (final e in recentExpenses) {
    transactions.add({
      'type': 'expense',
      'amount': e.amount,
      'category': e.category,
      'description': e.description ?? e.category,
      'date': e.date,
      'paymentMethod': e.paymentMethod,
    });
  }
  for (final i in recentIncome) {
    transactions.add({
      'type': 'income',
      'amount': i.amount,
      'category': i.category,
      'description': i.description ?? i.category,
      'date': i.date,
    });
  }
  transactions.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

  return {
    'totalIncome': totalIncome,
    'totalExpenses': totalExpenses,
    'totalSavings': totalSavings,
    'balance': totalIncome - totalExpenses,
    'recentTransactions': transactions.take(10).toList(),
  };
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good ${_greeting()}, 👋',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                    ),
                  ),
                  Text(
                    profile.value?.fullName ?? 'User',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => context.push('/notifications'),
                ),
                const SizedBox(width: 8),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month label
                    Text(
                      DateFormat('MMMM yyyy').format(now),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Summary Cards
                    summary.when(
                      loading: () => _buildSkeletonCards(),
                      error: (e, _) => Text('Error: $e'),
                      data: (data) => _buildSummaryCards(data, currency, isDark),
                    ),

                    const SizedBox(height: 24),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickActions(context),

                    const SizedBox(height: 24),

                    // Recent Transactions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/transactions'),
                          child: Text(
                            'See All',
                            style: GoogleFonts.poppins(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    summary.when(
                      loading: () => _buildSkeletonTransactions(),
                      error: (e, _) => const SizedBox(),
                      data: (data) => _buildRecentTransactions(
                        data['recentTransactions'] as List,
                        currency,
                        isDark,
                      ),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/add'),
        icon: const Icon(Icons.add),
        label: Text(
          'Add Expense',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildSummaryCards(
      Map<String, dynamic> data, String currency, bool isDark) {
    return Column(
      children: [
        // Balance Card (full width)
        _GradientCard(
          title: 'Total Balance',
          amount: (data['balance'] as num).toDouble(),
          currency: currency,
          gradient: (data['balance'] as num).toDouble() < 0
              ? const LinearGradient(
                  colors: [Color(0xFFEE5A24), Color(0xFFB71C1C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          icon: Icons.account_balance_wallet,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Income',
                amount: (data['totalIncome'] as num).toDouble(),
                currency: currency,
                color: AppColors.income,
                icon: Icons.arrow_downward,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Expenses',
                amount: (data['totalExpenses'] as num).toDouble(),
                currency: currency,
                color: AppColors.expense,
                icon: Icons.arrow_upward,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SummaryCard(
          title: 'Total Savings',
          amount: (data['totalSavings'] as num).toDouble(),
          currency: currency,
          color: AppColors.savings,
          icon: Icons.savings,
          isDark: isDark,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildSkeletonCards() {
    return Column(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {
        'icon': Icons.remove_circle_outline,
        'label': 'Add Expense',
        'color': AppColors.expense,
        'route': '/expenses/add',
      },
      {
        'icon': Icons.add_circle_outline,
        'label': 'Add Income',
        'color': AppColors.income,
        'route': '/income/add',
      },
      {
        'icon': Icons.account_balance_outlined,
        'label': 'Budget',
        'color': AppColors.budget,
        'route': '/budget',
      },
      {
        'icon': Icons.savings_outlined,
        'label': 'Goals',
        'color': AppColors.savings,
        'route': '/savings',
      },
    ];

    return Row(
      children: actions
          .map(
            (a) => Expanded(
              child: GestureDetector(
                onTap: () => context.push(a['route'] as String),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: (a['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (a['color'] as Color).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        a['icon'] as IconData,
                        color: a['color'] as Color,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a['label'] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: a['color'] as Color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRecentTransactions(
      List transactions, String currency, bool isDark) {
    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              ),
              const SizedBox(height: 12),
              Text(
                'No transactions this month',
                style: GoogleFonts.poppins(
                  color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: transactions
          .map<Widget>((t) => _TransactionTile(
                transaction: t as Map<String, dynamic>,
                currency: currency,
                isDark: isDark,
              ))
          .toList(),
    );
  }

  Widget _buildSkeletonTransactions() {
    return Column(
      children: List.generate(
        4,
        (i) => Container(
          height: 64,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _GradientCard extends StatelessWidget {
  final String title;
  final double amount;
  final String currency;
  final LinearGradient gradient;
  final IconData icon;

  const _GradientCard({
    required this.title,
    required this.amount,
    required this.currency,
    required this.gradient,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (amount < 0 ? const Color(0xFFEE5A24) : AppColors.primary)
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(amount, currency),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (amount < 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '⚠️ You spent more than you earned',
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            DateFormat('MMMM yyyy').format(DateTime.now()),
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final String currency;
  final Color color;
  final IconData icon;
  final bool isDark;
  final bool fullWidth;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.currency,
    required this.color,
    required this.icon,
    required this.isDark,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                  ),
                ),
                Text(
                  CurrencyFormatter.formatCompact(amount, currency),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> transaction;
  final String currency;
  final bool isDark;

  const _TransactionTile({
    required this.transaction,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction['type'] == 'expense';
    final color = isExpense ? AppColors.expense : AppColors.income;
    final date = transaction['date'] as DateTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _categoryEmoji(transaction['category'] as String),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['description'] as String,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${transaction['category']} • ${DateFormatter.formatShortDate(date)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? '-' : '+'}${CurrencyFormatter.format((transaction['amount'] as num).toDouble(), currency)}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _categoryEmoji(String category) {
    const icons = {
      'Food': '🍔',
      'Travel': '✈️',
      'Shopping': '🛍️',
      'Entertainment': '🎬',
      'Education': '📚',
      'Healthcare': '🏥',
      'Rent': '🏠',
      'Bills': '📄',
      'Fuel': '⛽',
      'Subscription': '📱',
      'Investment': '📈',
      'Salary': '💼',
      'Freelancing': '💻',
      'Business': '🏢',
      'Scholarship': '🎓',
      'Side Hustle': '🔧',
    };
    return icons[category] ?? '💰';
  }
}
