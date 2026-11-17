import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/screens/main_shell.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/expenses/screens/add_expense_screen.dart';
import '../../features/income/screens/income_screen.dart';
import '../../features/income/screens/add_income_screen.dart';
import '../../features/budget/screens/budget_screen.dart';
import '../../features/budget/screens/add_budget_screen.dart';
import '../../features/savings/screens/savings_screen.dart';
import '../../features/savings/screens/add_savings_goal_screen.dart';
import '../../features/transactions/screens/transactions_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.value?.session != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Main Shell with Bottom Nav
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),

      // Expenses
      GoRoute(
        path: '/expenses',
        builder: (context, state) => const ExpensesScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) {
              final expense = state.extra as Map<String, dynamic>?;
              return AddExpenseScreen(expense: expense);
            },
          ),
        ],
      ),

      // Income
      GoRoute(
        path: '/income',
        builder: (context, state) => const IncomeScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) {
              final income = state.extra as Map<String, dynamic>?;
              return AddIncomeScreen(income: income);
            },
          ),
        ],
      ),

      // Budget
      GoRoute(
        path: '/budget',
        builder: (context, state) => const BudgetScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) {
              final budget = state.extra as Map<String, dynamic>?;
              return AddBudgetScreen(budget: budget);
            },
          ),
        ],
      ),

      // Savings Goals
      GoRoute(
        path: '/savings',
        builder: (context, state) => const SavingsScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (context, state) {
              final goal = state.extra as Map<String, dynamic>?;
              return AddSavingsGoalScreen(goal: goal);
            },
          ),
        ],
      ),

      // Reports
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),

      // Notifications
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});
