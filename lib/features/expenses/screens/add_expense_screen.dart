import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';
import '../providers/expense_provider.dart';
import '../../auth/providers/auth_provider.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? expense;
  const AddExpenseScreen({super.key, this.expense});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();

  String _category = AppConstants.expenseCategories.first;
  String _paymentMethod = AppConstants.paymentMethods.first;
  DateTime _date = DateTime.now();
  File? _receiptFile;
  String? _existingReceiptUrl;
  bool _isEditing = false;
  String? _expenseId;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _isEditing = true;
      final e = widget.expense!;
      _expenseId = e['id'] as String?;
      _amountCtrl.text = e['amount'].toString();
      _descCtrl.text = e['description'] ?? '';
      _notesCtrl.text = e['notes'] ?? '';
      _category = e['category'] ?? AppConstants.expenseCategories.first;
      _paymentMethod =
          e['payment_method'] ?? AppConstants.paymentMethods.first;
      _date = e['date'] != null ? DateTime.parse(e['date']) : DateTime.now();
      if (e['tags'] != null) {
        _tagsCtrl.text = (e['tags'] as List).join(', ');
      }
      _existingReceiptUrl = e['receipt_url'] as String?;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    _tagsCtrl.dispose();
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

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _receiptFile = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    String? receiptUrl = _existingReceiptUrl;
    if (_receiptFile != null) {
      final repo = ref.read(expenseRepositoryProvider);
      receiptUrl = await repo.uploadReceipt(_expenseId ?? const Uuid().v4(), _receiptFile!);
    }

    final expense = ExpenseModel(
      id: _expenseId ?? const Uuid().v4(),
      userId: user.id,
      amount: amount,
      category: _category,
      description: _descCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      receiptUrl: receiptUrl,
      tags: tags,
      paymentMethod: _paymentMethod,
      date: _date,
      createdAt: DateTime.now(),
    );

    // Navigate back immediately — don't make the user wait for the server
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Updating expense…' : 'Saving expense…'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
      context.pop();
    }

    // Save in the background
    bool success;
    if (_isEditing && _expenseId != null) {
      success = await ref
          .read(expenseNotifierProvider.notifier)
          .updateExpense(expense);
    } else {
      success = await ref
          .read(expenseNotifierProvider.notifier)
          .addExpense(expense);
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
    final state = ref.watch(expenseNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
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
            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.poppins(
                  fontSize: 32, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '  ',
                hintText: '0.00',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 32, fontWeight: FontWeight.w700),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Amount is required';
                if (double.tryParse(v) == null) return 'Enter a valid amount';
                if (double.parse(v) <= 0) return 'Amount must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Category
            Text('Category',
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.expenseCategories
                  .map(
                    (c) => GestureDetector(
                      onTap: () => setState(() => _category = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _category == c
                              ? AppColors.primary
                              : isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightDivider,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _category == c
                                ? AppColors.primary
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

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Date
            GestureDetector(
              onTap: _pickDate,
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

            // Payment Method
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                prefixIcon: Icon(Icons.payment_outlined),
              ),
              items: AppConstants.paymentMethods
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m, style: GoogleFonts.poppins()),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Tags
            TextFormField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
                prefixIcon: Icon(Icons.tag),
                hintText: 'food, monthly, essential',
              ),
            ),
            const SizedBox(height: 16),

            // Receipt
            GestureDetector(
              onTap: _pickReceipt,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightDivider,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: _receiptFile != null
                    // New file picked — show local image
                    ? Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_receiptFile!,
                                width: 60, height: 60, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Receipt selected',
                                style: GoogleFonts.poppins(fontSize: 14)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _receiptFile = null),
                          ),
                        ],
                      )
                    : _existingReceiptUrl != null
                        // Existing receipt from Supabase — show via signed URL
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: FutureBuilder<String>(
                                      future: ref.read(expenseRepositoryProvider)
                                          .getReceiptSignedUrl(_existingReceiptUrl!),
                                      builder: (_, snap) {
                                        if (snap.connectionState == ConnectionState.waiting) {
                                          return const SizedBox(
                                            width: 60, height: 60,
                                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          );
                                        }
                                        if (snap.hasError || !snap.hasData) {
                                          return Container(
                                            width: 60, height: 60,
                                            decoration: BoxDecoration(
                                              color: AppColors.expense.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.receipt_long, color: AppColors.expense),
                                          );
                                        }
                                        return Image.network(
                                          snap.data!,
                                          width: 60, height: 60,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 60, height: 60,
                                            decoration: BoxDecoration(
                                              color: AppColors.expense.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.receipt_long, color: AppColors.expense),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Receipt attached',
                                            style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                        Text('Tap to replace',
                                            style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppColors.darkSubtext
                                                    : AppColors.lightSubtext)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: AppColors.error),
                                    onPressed: () => setState(() {
                                      _existingReceiptUrl = null;
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          )
                        // No receipt yet
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.upload_file_outlined),
                              const SizedBox(width: 8),
                              Text('Upload Receipt',
                                  style: GoogleFonts.poppins(fontSize: 14)),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isLoading ? null : _save,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEditing ? 'Update Expense' : 'Add Expense'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
