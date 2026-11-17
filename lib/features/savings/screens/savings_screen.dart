import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/savings_goal_model.dart';
import '../providers/savings_provider.dart';
import '../../profile/providers/profile_provider.dart';

class SavingsScreen extends ConsumerWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalsProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Goals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/savings/add'),
          ),
        ],
      ),
      body: goals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined,
                      size: 80,
                      color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
                  const SizedBox(height: 16),
                  Text('No savings goals yet', style: GoogleFonts.poppins()),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/savings/add'),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Goal'),
                  ),
                ],
              ),
            );
          }

          final totalSaved = list.fold(0.0, (sum, g) => sum + g.currentAmount);
          final totalTarget = list.fold(0.0, (sum, g) => sum + g.targetAmount);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.savings, Color(0xFF2EBF9B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Saved',
                            style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.85), fontSize: 13)),
                        Text(CurrencyFormatter.format(totalSaved, currency),
                            style: GoogleFonts.poppins(
                                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                        Text('of ${CurrencyFormatter.format(totalTarget, currency)}',
                            style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.7), fontSize: 12)),
                      ],
                    ),
                    CircularPercentIndicator(
                      radius: 40,
                      lineWidth: 6,
                      percent: totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0,
                      center: Text(
                        '${totalTarget > 0 ? (totalSaved / totalTarget * 100).toStringAsFixed(0) : 0}%',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      progressColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ...list.map((g) => _GoalCard(goal: g, currency: currency, isDark: isDark, ref: ref)),
            ],
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoalModel goal;
  final String currency;
  final bool isDark;
  final WidgetRef ref;

  const _GoalCard({
    required this.goal,
    required this.currency,
    required this.isDark,
    required this.ref,
  });

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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.savings.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.savings, color: AppColors.savings, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.goalName,
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    if (goal.deadline != null)
                      Text(
                        'Deadline: ${DateFormatter.formatDate(goal.deadline!)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    context.push('/savings/add', extra: {
                      'id': goal.id,
                      'goal_name': goal.goalName,
                      'target_amount': goal.targetAmount,
                      'current_amount': goal.currentAmount,
                      'deadline': goal.deadline?.toIso8601String().split('T')[0],
                      'notes': goal.notes,
                    });
                  }
                  if (v == 'delete') {
                    ref.read(savingsNotifierProvider.notifier).deleteGoal(goal.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.poppins())),
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: GoogleFonts.poppins(color: AppColors.error))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyFormatter.format(goal.currentAmount, currency),
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.savings),
              ),
              Text(
                '/ ${CurrencyFormatter.format(goal.targetAmount, currency)}',
                style: GoogleFonts.poppins(fontSize: 14, color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: goal.percentage / 100,
            backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
              goal.isCompleted ? AppColors.income : AppColors.savings,
            ),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${goal.percentage.toStringAsFixed(1)}% achieved',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: goal.isCompleted ? AppColors.income : AppColors.savings,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                goal.isCompleted
                    ? '🎉 Goal reached!'
                    : '${CurrencyFormatter.format(goal.remaining, currency)} to go',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
