import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/budget_model.dart';
import '../providers/budget_provider.dart';
import '../../profile/providers/profile_provider.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  final now = DateTime.now();
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    _month = now.month;
    _year = now.year;
  }

  @override
  Widget build(BuildContext context) {
    final params = BudgetFilters(month: _month, year: _year);
    final budgets = ref.watch(budgetsProvider(params));
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/budget/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    if (_month == 1) {
                      _month = 12;
                      _year--;
                    } else {
                      _month--;
                    }
                  }),
                ),
                Text(
                  '${_monthName(_month)} $_year',
                  style: GoogleFonts.poppins(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    if (_month == 12) {
                      _month = 1;
                      _year++;
                    } else {
                      _month++;
                    }
                  }),
                ),
              ],
            ),
          ),

          Expanded(
            child: budgets.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_outlined,
                            size: 80,
                            color: isDark
                                ? AppColors.darkSubtext
                                : AppColors.lightSubtext),
                        const SizedBox(height: 16),
                        Text('No budgets for this month',
                            style: GoogleFonts.poppins()),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/budget/add'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Budget'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (ctx, i) =>
                      _BudgetCard(budget: list[i], currency: currency, isDark: isDark, ref: ref),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month - 1];
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetModel budget;
  final String currency;
  final bool isDark;
  final WidgetRef ref;

  const _BudgetCard({
    required this.budget,
    required this.currency,
    required this.isDark,
    required this.ref,
  });

  Color get _progressColor {
    if (budget.percentage >= 100) return AppColors.error;
    if (budget.percentage >= 75) return AppColors.warning;
    if (budget.percentage >= 50) return AppColors.budget;
    return AppColors.income;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppConstants.categoryIcons[budget.category] ?? '💰',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.category,
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      budget.isExceeded
                          ? 'Budget exceeded!'
                          : '${CurrencyFormatter.format(budget.remaining, currency)} remaining',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: budget.isExceeded
                            ? AppColors.error
                            : isDark
                                ? AppColors.darkSubtext
                                : AppColors.lightSubtext,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    context.push('/budget/add', extra: {
                      'id': budget.id,
                      'category': budget.category,
                      'amount': budget.amount,
                      'month': budget.month,
                      'year': budget.year,
                    });
                  }
                  if (v == 'delete') {
                    ref.read(budgetNotifierProvider.notifier).deleteBudget(budget.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit', style: GoogleFonts.poppins()),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: GoogleFonts.poppins(color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${CurrencyFormatter.format(budget.spent, currency)} spent',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              Text(
                'of ${CurrencyFormatter.format(budget.amount, currency)}',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearPercentIndicator(
            lineHeight: 8,
            percent: budget.percentage / 100,
            backgroundColor: isDark
                ? AppColors.darkBorder
                : AppColors.lightBorder,
            progressColor: _progressColor,
            barRadius: const Radius.circular(4),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 4),
          Text(
            '${budget.percentage.toStringAsFixed(1)}% used',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: _progressColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
