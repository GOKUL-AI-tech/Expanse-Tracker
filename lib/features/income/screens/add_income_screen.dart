import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/income_model.dart';
import '../providers/income_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AddIncomeScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? income;
  const AddIncomeScreen({super.key, this.income});

  @override
  ConsumerState<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends ConsumerState<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _category = AppConstants.incomeCategories.first;
  DateTime _date = DateTime.now();
  bool _isEditing = false;
  String? _incomeId;

  @override
  void initState() {
    super.initState();
    if (widget.income != null) {
      _isEditing = true;
      final i = widget.income!;
      _incomeId = i['id'] as String?;
      _amountCtrl.text = i['amount'].toString();
      _descCtrl.text = i['description'] ?? '';
      _notesCtrl.text = i['notes'] ?? '';
      _category = i['category'] ?? AppConstants.incomeCategories.first;
      _date = i['date'] != null ? DateTime.parse(i['date']) : DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final income = IncomeModel(
      id: _incomeId ?? const Uuid().v4(),
      userId: user.id,
      amount: double.tryParse(_amountCtrl.text.trim()) ?? 0,
      category: _category,
      description: _descCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      date: _date,
      createdAt: DateTime.now(),
    );

    // Navigate back immediately
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Updating income…' : 'Saving income…'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      context.pop();
    }

    // Save in the background
    bool success;
    if (_isEditing && _incomeId != null) {
      success = await ref.read(incomeNotifierProvider.notifier).updateIncome(income);
    } else {
      success = await ref.read(incomeNotifierProvider.notifier).addIncome(income);
    }

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(incomeNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Income' : 'Add Income'),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(
                  fontSize: 32, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Amount is required';
                if (double.tryParse(v) == null) return 'Invalid amount';
                if (double.parse(v) <= 0) return 'Amount must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 20),

            Text('Category',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.incomeCategories
                  .map(
                    (c) => GestureDetector(
                      onTap: () => setState(() => _category = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _category == c
                              ? AppColors.income
                              : isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightDivider,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _category == c
                                ? AppColors.income
                                : isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                          ),
                        ),
                        child: Text(
                          '${AppConstants.categoryIcons[c] ?? ''} $c',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _category == c
                                ? Colors.white
                                : isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard
                      : AppColors.lightDivider,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd MMMM yyyy').format(_date),
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    const Spacer(),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.income,
                ),
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEditing ? 'Update Income' : 'Add Income'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
