import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/budget_model.dart';
import '../providers/budget_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AddBudgetScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? budget;
  const AddBudgetScreen({super.key, this.budget});

  @override
  ConsumerState<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends ConsumerState<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();

  String _category = AppConstants.expenseCategories.first;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  bool _isEditing = false;
  String? _budgetId;

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _isEditing = true;
      final b = widget.budget!;
      _budgetId = b['id'] as String?;
      _amountCtrl.text = b['amount'].toString();
      _category = b['category'] ?? AppConstants.expenseCategories.first;
      _month = b['month'] ?? DateTime.now().month;
      _year = b['year'] ?? DateTime.now().year;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final budget = BudgetModel(
      id: _budgetId ?? const Uuid().v4(),
      userId: user.id,
      category: _category,
      amount: double.tryParse(_amountCtrl.text.trim()) ?? 0,
      month: _month,
      year: _year,
      createdAt: DateTime.now(),
    );

    bool success;
    if (_isEditing && _budgetId != null) {
      success = await ref.read(budgetNotifierProvider.notifier).updateBudget(budget);
    } else {
      success = await ref.read(budgetNotifierProvider.notifier).addBudget(budget);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Budget updated' : 'Budget created'),
          backgroundColor: AppColors.income,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(budgetNotifierProvider);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Budget' : 'Create Budget'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Budget Amount', hintText: '0.00'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Amount is required';
                if (double.tryParse(v) == null) return 'Invalid amount';
                if (double.parse(v) <= 0) return 'Amount must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 20),

            Text('Category', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.expenseCategories.map((c) => GestureDetector(
                onTap: () => setState(() => _category = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _category == c ? AppColors.primary : isDark ? AppColors.darkCard : AppColors.lightDivider,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _category == c ? AppColors.primary : isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    '${AppConstants.categoryIcons[c] ?? ''} $c',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: _category == c ? Colors.white : null,
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _month,
                    decoration: const InputDecoration(labelText: 'Month'),
                    items: List.generate(12, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text(months[i], style: GoogleFonts.poppins()),
                    )),
                    onChanged: (v) => setState(() => _month = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _year,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(
                      value: y,
                      child: Text('$y', style: GoogleFonts.poppins()),
                    )).toList(),
                    onChanged: (v) => setState(() => _year = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _save,
                child: state.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Update Budget' : 'Create Budget'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
