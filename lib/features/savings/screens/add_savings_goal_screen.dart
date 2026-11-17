import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/savings_goal_model.dart';
import '../providers/savings_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AddSavingsGoalScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? goal;
  const AddSavingsGoalScreen({super.key, this.goal});

  @override
  ConsumerState<AddSavingsGoalScreen> createState() => _AddSavingsGoalScreenState();
}

class _AddSavingsGoalScreenState extends ConsumerState<AddSavingsGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _currentCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _deadline;
  bool _isEditing = false;
  String? _goalId;

  @override
  void initState() {
    super.initState();
    if (widget.goal != null) {
      _isEditing = true;
      final g = widget.goal!;
      _goalId = g['id'] as String?;
      _nameCtrl.text = g['goal_name'] ?? '';
      _targetCtrl.text = g['target_amount'].toString();
      _currentCtrl.text = g['current_amount'].toString();
      _notesCtrl.text = g['notes'] ?? '';
      _deadline = g['deadline'] != null ? DateTime.parse(g['deadline']) : null;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _currentCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final goal = SavingsGoalModel(
      id: _goalId ?? const Uuid().v4(),
      userId: user.id,
      goalName: _nameCtrl.text.trim(),
      targetAmount: double.tryParse(_targetCtrl.text.trim()) ?? 0,
      currentAmount: double.tryParse(_currentCtrl.text.trim()) ?? 0,
      deadline: _deadline,
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    bool success;
    if (_isEditing && _goalId != null) {
      success = await ref.read(savingsNotifierProvider.notifier).updateGoal(goal);
    } else {
      success = await ref.read(savingsNotifierProvider.notifier).addGoal(goal);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Goal updated' : 'Goal created'),
          backgroundColor: AppColors.savings,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(savingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Goal' : 'Create Savings Goal'),
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
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Goal Name',
                hintText: 'e.g. New Laptop, Emergency Fund',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Goal name is required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Target Amount',
                prefixIcon: Icon(Icons.track_changes),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Target amount is required';
                if (double.tryParse(v) == null) return 'Invalid amount';
                if (double.parse(v) <= 0) return 'Amount must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _currentCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Current Saved Amount',
                prefixIcon: Icon(Icons.savings_outlined),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (double.tryParse(v) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _pickDeadline,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightDivider,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      _deadline != null
                          ? DateFormat('dd MMMM yyyy').format(_deadline!)
                          : 'Set Deadline (optional)',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    const Spacer(),
                    if (_deadline != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _deadline = null),
                      )
                    else
                      const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.savings),
                child: state.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Update Goal' : 'Create Goal'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
