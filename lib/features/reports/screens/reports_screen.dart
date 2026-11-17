import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/income_repository.dart';
import '../../profile/providers/profile_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _reportType = 'Monthly';
  DateTime _selectedDate = DateTime.now();
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _isGeneratingPdf = false;
  bool _isGeneratingCsv = false;

  final _reportTypes = [
    ('Daily', Icons.today_rounded),
    ('Weekly', Icons.view_week_rounded),
    ('Monthly', Icons.calendar_month_rounded),
    ('Yearly', Icons.calendar_today_rounded),
    ('Custom', Icons.date_range_rounded),
  ];

  Future<(DateTime, DateTime)> _getDateRange() async {
    final now = _selectedDate;
    switch (_reportType) {
      case 'Daily':
        return (DateTime(now.year, now.month, now.day),
            DateTime(now.year, now.month, now.day, 23, 59, 59));
      case 'Weekly':
        final start = now.subtract(Duration(days: now.weekday - 1));
        return (DateTime(start.year, start.month, start.day),
            DateTime(start.year, start.month, start.day + 6, 23, 59, 59));
      case 'Monthly':
        return (DateTime(now.year, now.month, 1),
            DateTime(now.year, now.month + 1, 0, 23, 59, 59));
      case 'Yearly':
        return (DateTime(now.year, 1, 1),
            DateTime(now.year, 12, 31, 23, 59, 59));
      case 'Custom':
        final from = _customFrom ?? DateTime(now.year, now.month, 1);
        final to = _customTo ?? now;
        return (from, to);
      default:
        return (DateTime(now.year, now.month, 1),
            DateTime(now.year, now.month + 1, 0));
    }
  }

  Future<void> _pickCustomRange() async {
    final ThemeData pickerTheme = Theme.of(context).copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.lightText,
      ),
    );

    final from = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: _customFrom ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'SELECT START DATE',
      builder: (ctx, child) => Theme(data: pickerTheme, child: child!),
    );
    if (from == null || !mounted) return;

    final to = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: (_customTo != null && _customTo!.isAfter(from))
          ? _customTo!
          : from,
      firstDate: from,
      lastDate: DateTime.now(),
      helpText: 'SELECT END DATE',
      builder: (ctx, child) => Theme(data: pickerTheme, child: child!),
    );
    if (to == null || !mounted) return;

    setState(() {
      _customFrom = from;
      _customTo = to;
    });
  }

  String get _periodLabel {
    if (_reportType == 'Monthly') {
      return DateFormat('MMMM yyyy').format(_selectedDate);
    } else if (_reportType == 'Yearly') {
      return _selectedDate.year.toString();
    } else if (_reportType == 'Daily') {
      return DateFormat('dd MMMM yyyy').format(_selectedDate);
    } else if (_reportType == 'Weekly') {
      final start =
          _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return '${DateFormat('dd MMM').format(start)} – ${DateFormat('dd MMM yyyy').format(end)}';
    } else if (_reportType == 'Custom') {
      if (_customFrom != null && _customTo != null) {
        return '${DateFormat('dd MMM').format(_customFrom!)} – ${DateFormat('dd MMM yyyy').format(_customTo!)}';
      }
      return 'Tap to select dates';
    }
    return '';
  }

  void _stepDate(int delta) {
    setState(() {
      if (_reportType == 'Monthly') {
        _selectedDate =
            DateTime(_selectedDate.year, _selectedDate.month + delta);
      } else if (_reportType == 'Yearly') {
        _selectedDate = DateTime(_selectedDate.year + delta);
      } else {
        _selectedDate = _selectedDate.add(Duration(days: delta));
      }
    });
  }

  Future<void> _exportCSV() async {
    setState(() => _isGeneratingCsv = true);
    try {
      final expenseRepo = ref.read(expenseRepositoryProvider);
      final incomeRepo = ref.read(incomeRepositoryProvider);
      final currency = ref.read(currencyProvider);
      final range = await _getDateRange();

      final expenses =
          await expenseRepo.getExpenses(from: range.$1, to: range.$2);
      final incomes =
          await incomeRepo.getIncome(from: range.$1, to: range.$2);

      final rows = <List<dynamic>>[
        ['Type', 'Date', 'Category', 'Description', 'Amount ($currency)', 'Payment Method'],
        ...expenses.map((e) => [
              'Expense',
              DateFormat('dd/MM/yyyy').format(e.date),
              e.category,
              e.description ?? '',
              e.amount,
              e.paymentMethod,
            ]),
        ...incomes.map((i) => [
              'Income',
              DateFormat('dd/MM/yyyy').format(i.date),
              i.category,
              i.description ?? '',
              i.amount,
              '',
            ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: '$_reportType Report');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('CSV exported successfully!'),
          backgroundColor: AppColors.income,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      setState(() => _isGeneratingCsv = false);
    }
  }

  // PDF-safe amount: replaces Unicode currency symbols with ASCII equivalents
  // because the built-in PDF fonts (Helvetica/Times) don't support Unicode
  String _pdfAmount(double amount, String currency) {
    const symbols = {
      'INR': 'Rs.',
      'USD': 'USD ',
      'EUR': 'EUR ',
      'GBP': 'GBP ',
      'AED': 'AED ',
      'SGD': 'SGD ',
    };
    final symbol = symbols[currency] ?? '$currency ';
    final formatted = NumberFormat('#,##,##0.00').format(amount.abs());
    return amount < 0 ? '-$symbol$formatted' : '$symbol$formatted';
  }

  Future<void> _exportPDF() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final expenseRepo = ref.read(expenseRepositoryProvider);
      final incomeRepo = ref.read(incomeRepositoryProvider);
      final currency = ref.read(currencyProvider);
      final range = await _getDateRange();

      final expenses =
          await expenseRepo.getExpenses(from: range.$1, to: range.$2);
      final incomes =
          await incomeRepo.getIncome(from: range.$1, to: range.$2);
      final totalExpenses = expenses.fold(0.0, (s, e) => s + e.amount);
      final totalIncome = incomes.fold(0.0, (s, i) => s + i.amount);
      final balance = totalIncome - totalExpenses;

      // Color palette
      const headerBg   = PdfColor.fromInt(0xFF6C63FF); // primary purple
      const incomeBg   = PdfColor.fromInt(0xFFE8FBF5);
      const incomeText = PdfColor.fromInt(0xFF00C896);
      const expenseBg  = PdfColor.fromInt(0xFFFFEEEE);
      const expenseText= PdfColor.fromInt(0xFFFF6B6B);
      const rowAlt     = PdfColor.fromInt(0xFFF8F9FE);
      const tableHead  = PdfColor.fromInt(0xFF1A1A2E);
      const grey       = PdfColor.fromInt(0xFF6B7280);

      final pdf = pw.Document();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Container(
          decoration: const pw.BoxDecoration(color: headerBg),
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('EXPENSE TRACKER PRO',
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                  pw.Text('$_reportType Financial Report',
                      style: const pw.TextStyle(
                          fontSize: 11, color: const PdfColor(1, 1, 1, 0.75))),
                ],
              ),
              pw.Text(
                DateFormat('dd MMM yyyy').format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 10, color: const PdfColor(1, 1, 1, 0.75)),
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated by Expense Tracker Pro',
                  style: const pw.TextStyle(fontSize: 9, color: grey)),
              pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 9, color: grey)),
            ],
          ),
        ),
        build: (ctx) => [
          pw.SizedBox(height: 20),

          // Period bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: pw.BoxDecoration(
              color: rowAlt,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(children: [
              pw.Text('Period: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              pw.Text(
                '${DateFormat('dd MMM yyyy').format(range.$1)}  to  ${DateFormat('dd MMM yyyy').format(range.$2)}',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ]),
          ),
          pw.SizedBox(height: 20),

          // Summary cards row
          pw.Row(children: [
            // Income card
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: incomeBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: incomeText, width: 0.5),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(children: [
                  pw.Container(width: 8, height: 8,
                      decoration: const pw.BoxDecoration(color: incomeText, shape: pw.BoxShape.circle)),
                  pw.SizedBox(width: 6),
                  pw.Text('TOTAL INCOME',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: incomeText)),
                ]),
                pw.SizedBox(height: 6),
                pw.Text(_pdfAmount(totalIncome, currency),
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: incomeText)),
              ]),
            )),
            pw.SizedBox(width: 12),
            // Expense card
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: expenseBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: expenseText, width: 0.5),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(children: [
                  pw.Container(width: 8, height: 8,
                      decoration: const pw.BoxDecoration(color: expenseText, shape: pw.BoxShape.circle)),
                  pw.SizedBox(width: 6),
                  pw.Text('TOTAL EXPENSES',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: expenseText)),
                ]),
                pw.SizedBox(height: 6),
                pw.Text(_pdfAmount(totalExpenses, currency),
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: expenseText)),
              ]),
            )),
            pw.SizedBox(width: 12),
            // Balance card
            pw.Expanded(child: pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: balance >= 0 ? incomeBg : expenseBg,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(
                    color: balance >= 0 ? incomeText : expenseText, width: 0.5),
              ),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Row(children: [
                  pw.Container(width: 8, height: 8,
                      decoration: pw.BoxDecoration(
                          color: balance >= 0 ? incomeText : expenseText,
                          shape: pw.BoxShape.circle)),
                  pw.SizedBox(width: 6),
                  pw.Text('NET BALANCE',
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold,
                          color: balance >= 0 ? incomeText : expenseText)),
                ]),
                pw.SizedBox(height: 6),
                pw.Text(_pdfAmount(balance, currency),
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold,
                        color: balance >= 0 ? incomeText : expenseText)),
              ]),
            )),
          ]),
          pw.SizedBox(height: 28),

          // Expenses table
          if (expenses.isNotEmpty) ...[
            pw.Row(children: [
              pw.Container(width: 4, height: 18,
                  decoration: const pw.BoxDecoration(color: expenseText)),
              pw.SizedBox(width: 8),
              pw.Text('EXPENSES',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold, color: tableHead)),
              pw.SizedBox(width: 8),
              pw.Text('(${expenses.length} transactions)',
                  style: const pw.TextStyle(fontSize: 10, color: grey)),
            ]),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                bottom: const pw.BorderSide(color: PdfColors.grey300),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: tableHead),
                  children: ['Date', 'Category', 'Description', 'Amount'].map((h) =>
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: pw.Text(h,
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                    ),
                  ).toList(),
                ),
                // Data rows
                ...expenses.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : rowAlt),
                    children: [
                      DateFormat('dd/MM/yy').format(e.date),
                      e.category,
                      e.description ?? '',
                      _pdfAmount(e.amount, currency),
                    ].map((cell) =>
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: pw.Text(cell,
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ).toList(),
                  );
                }),
                // Total row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: expenseBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: pw.Text('TOTAL',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(),
                    pw.SizedBox(),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: pw.Text(_pdfAmount(totalExpenses, currency),
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold,
                              color: expenseText)),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),
          ],

          // Income table
          if (incomes.isNotEmpty) ...[
            pw.Row(children: [
              pw.Container(width: 4, height: 18,
                  decoration: const pw.BoxDecoration(color: incomeText)),
              pw.SizedBox(width: 8),
              pw.Text('INCOME',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold, color: tableHead)),
              pw.SizedBox(width: 8),
              pw.Text('(${incomes.length} transactions)',
                  style: const pw.TextStyle(fontSize: 10, color: grey)),
            ]),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder(
                horizontalInside: const pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                bottom: const pw.BorderSide(color: PdfColors.grey300),
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.5),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: tableHead),
                  children: ['Date', 'Category', 'Description', 'Amount'].map((h) =>
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: pw.Text(h,
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white)),
                    ),
                  ).toList(),
                ),
                ...incomes.asMap().entries.map((entry) {
                  final i = entry.key;
                  final inc = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : rowAlt),
                    children: [
                      DateFormat('dd/MM/yy').format(inc.date),
                      inc.category,
                      inc.description ?? '',
                      _pdfAmount(inc.amount, currency),
                    ].map((cell) =>
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: pw.Text(cell, style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ).toList(),
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: incomeBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: pw.Text('TOTAL',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(),
                    pw.SizedBox(),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: pw.Text(_pdfAmount(totalIncome, currency),
                          style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold,
                              color: incomeText)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ));

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)],
          text: '$_reportType Report PDF');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF exported successfully!'),
          backgroundColor: AppColors.income,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: Text('Reports',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Report Type ──────────────────────────────────────────────
            Text('Report Type',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _reportTypes.map((item) {
                final isSelected = _reportType == item.$1;
                return GestureDetector(
                  onTap: () => setState(() => _reportType = item.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : borderColor,
                        width: isSelected ? 0 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.$2,
                          size: 16,
                          color: isSelected ? Colors.white : subColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.$1,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // ── Period Selector ──────────────────────────────────────────
            Text('Period',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
            const SizedBox(height: 12),

            if (_reportType == 'Custom') ...[
              // Custom: tap to open calendar
              GestureDetector(
                onTap: _pickCustomRange,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.calendar_month_rounded,
                            color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date Range',
                                style: GoogleFonts.poppins(
                                    fontSize: 11, color: subColor)),
                            Text(_periodLabel,
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: textColor)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: subColor),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Arrow-based period nav
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left_rounded,
                          color: textColor, size: 28),
                      onPressed: () => _stepDate(-1),
                    ),
                    Expanded(
                      child: Text(
                        _periodLabel,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded,
                          color: textColor, size: 28),
                      onPressed: () => _stepDate(1),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),

            // ── Export Format ────────────────────────────────────────────
            Text('Export Format',
                style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ExportButton(
                    label: 'Export PDF',
                    sublabel: 'Formatted report',
                    icon: Icons.picture_as_pdf_rounded,
                    color: const Color(0xFFFF6B6B),
                    isLoading: _isGeneratingPdf,
                    isDisabled: _isGeneratingCsv,
                    onTap: _exportPDF,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ExportButton(
                    label: 'Export CSV',
                    sublabel: 'Raw data table',
                    icon: Icons.table_chart_rounded,
                    color: AppColors.income,
                    isLoading: _isGeneratingCsv,
                    isDisabled: _isGeneratingPdf,
                    onTap: _exportCSV,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Info Card ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reports include all expenses and income for the selected period. PDF gives a formatted view; CSV is best for spreadsheets.',
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final bool isDark;
  final bool isLoading;
  final bool isDisabled;
  final VoidCallback onTap;

  const _ExportButton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.isLoading,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final blocked = isLoading || isDisabled;
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: GestureDetector(
      onTap: blocked ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          color: color, strokeWidth: 2))
                  : Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(sublabel,
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.lightSubtext)),
          ],
        ),
      ),
      ),
    );
  }
}
