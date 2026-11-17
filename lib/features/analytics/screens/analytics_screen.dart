import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/income_repository.dart';
import '../../profile/providers/profile_provider.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final analyticsDataProvider =
    FutureProvider.family<Map<String, dynamic>, _AnalyticsKey>(
        (ref, key) async {
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  final incomeRepo = ref.watch(incomeRepositoryProvider);

  final from = key.from;
  final to = key.to;
  final now = DateTime.now();

  // Build month ranges for trend (last 6 months)
  final monthRanges = List.generate(6, (i) {
    final month = DateTime(now.year, now.month - (5 - i), 1);
    final monthEnd = DateTime(now.year, now.month - (5 - i) + 1, 0);
    final label = DateFormat('MMM').format(month);
    return (label: label, from: month, to: monthEnd);
  });

  // Fire ALL calls in parallel
  final results = await Future.wait([
    expenseRepo.getCategoryTotals(from: from, to: to),       // 0
    incomeRepo.getCategoryTotals(from: from, to: to),        // 1
    expenseRepo.getTotalExpenses(from: from, to: to),        // 2
    incomeRepo.getTotalIncome(from: from, to: to),           // 3
    // Monthly expense totals (6 months)
    ...monthRanges.map((r) => expenseRepo.getTotalExpenses(from: r.from, to: r.to)),  // 4–9
    // Monthly income totals (6 months)
    ...monthRanges.map((r) => incomeRepo.getTotalIncome(from: r.from, to: r.to)),     // 10–15
  ]);

  final expenseCategoryTotals = results[0] as Map<String, double>;
  final incomeCategoryTotals  = results[1] as Map<String, double>;
  final totalExpenses          = (results[2] as double);
  final totalIncome            = (results[3] as double);

  final monthlyExpenses = <String, double>{};
  final monthlyIncome   = <String, double>{};
  for (int i = 0; i < 6; i++) {
    monthlyExpenses[monthRanges[i].label] = results[4 + i] as double;
    monthlyIncome[monthRanges[i].label]   = results[10 + i] as double;
  }

  return {
    'expenseCategoryTotals': expenseCategoryTotals,
    'incomeCategoryTotals': incomeCategoryTotals,
    'totalExpenses': totalExpenses,
    'totalIncome': totalIncome,
    'netSavings': totalIncome - totalExpenses,
    'spendingRatio':
        totalIncome > 0 ? (totalExpenses / totalIncome * 100) : 0.0,
    'monthlyExpenses': monthlyExpenses,
    'monthlyIncome': monthlyIncome,
  };
});

class _AnalyticsKey {
  final DateTime? from;
  final DateTime? to;

  const _AnalyticsKey({this.from, this.to});

  @override
  bool operator ==(Object other) =>
      other is _AnalyticsKey && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  // Default: this month
  late DateTime _from;
  late DateTime _to;
  String _quickLabel = 'This Month';
  int _touchedExpense = -1;
  int _touchedIncome = -1;
  late TabController _tabCtrl;

  final _quickFilters = <String, (DateTime?, DateTime?)>{};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
    _buildQuickFilters();
  }

  void _buildQuickFilters() {
    final now = DateTime.now();
    _quickFilters.addAll({
      'This Month': (DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0)),
      'Last 3M': (now.subtract(const Duration(days: 90)), now),
      'Last 6M': (now.subtract(const Duration(days: 180)), now),
      'This Year': (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31)),
      'Lifetime': (null, null),
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  _AnalyticsKey get _key => _AnalyticsKey(from: _from, to: _to);

  String get _dateRangeLabel {
    if (_quickLabel == 'Lifetime') return 'All Time';
    return '${DateFormat('dd MMM').format(_from)} – ${DateFormat('dd MMM yy').format(_to)}';
  }

  Future<void> _pickDateRange() async {
    DateTime tempFrom = _from;
    DateTime tempTo = _to;

    // Pick FROM date
    final from = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: tempFrom,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'SELECT START DATE',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.lightText,
          ),
        ),
        child: child!,
      ),
    );
    if (from == null || !mounted) return;
    tempFrom = from;

    // Pick TO date
    final to = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: tempTo.isAfter(tempFrom) ? tempTo : tempFrom,
      firstDate: tempFrom,
      lastDate: DateTime.now(),
      helpText: 'SELECT END DATE',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppColors.lightText,
          ),
        ),
        child: child!,
      ),
    );
    if (to == null || !mounted) return;

    setState(() {
      _from = tempFrom;
      _to = to;
      _quickLabel = 'Custom';
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(analyticsDataProvider(_key));
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(analyticsDataProvider),
          child: CustomScrollView(
            slivers: [
              // Dark header
              SliverToBoxAdapter(
                  child: _buildHeader(isDark, currency, data)),
              // Body content as sliver
              data.when(
                loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverFillRemaining(
                    child: Center(child: Text('Error: $e'))),
                data: (d) => SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                        _buildBodyChildren(d, currency, isDark)),
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }

  // ── Dark Header ─────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark, String currency,
      AsyncValue<Map<String, dynamic>> data) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A3E), Color(0xFF2D2B6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text('Analytics',
                      style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined,
                        color: Colors.white70),
                    onPressed: () => context.push('/reports'),
                  ),
                ],
              ),
            ),

            // Date range row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Quick filter chips
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quickFilters.keys.map((label) {
                          final isSelected = _quickLabel == label;
                          return GestureDetector(
                            onTap: () {
                              final range = _quickFilters[label]!;
                              setState(() {
                                _quickLabel = label;
                                if (range.$1 == null) {
                                  // Lifetime: use a very old date
                                  _from = DateTime(2000);
                                  _to = DateTime.now();
                                } else {
                                  _from = range.$1!;
                                  _to = range.$2!;
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(label,
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.white70)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Calendar picker button
                  GestureDetector(
                    onTap: _pickDateRange,
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Icon(Icons.calendar_month_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Selected range label
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                _dateRangeLabel,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.white54),
              ),
            ),

            // Summary stat row
            data.when(
              loading: () => const SizedBox(height: 80),
              error: (_, __) => const SizedBox(height: 80),
              data: (d) {
                final income = (d['totalIncome'] as num).toDouble();
                final expense = (d['totalExpenses'] as num).toDouble();
                final balance = income - expense;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Row(
                    children: [
                      _HeaderStat(
                          label: 'Income',
                          value: CurrencyFormatter.formatCompact(
                              income, currency),
                          color: const Color(0xFF00E5B4)),
                      _HeaderDivider(),
                      _HeaderStat(
                          label: 'Expenses',
                          value: CurrencyFormatter.formatCompact(
                              expense, currency),
                          color: const Color(0xFFFF8E8E)),
                      _HeaderDivider(),
                      _HeaderStat(
                          label: 'Balance',
                          value: CurrencyFormatter.formatCompact(
                              balance.abs(), currency),
                          color: balance >= 0
                              ? const Color(0xFF82CFFF)
                              : const Color(0xFFFF8E8E)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Body children (returns flat list for SliverChildListDelegate) ───────────

  List<Widget> _buildBodyChildren(
      Map<String, dynamic> data, String currency, bool isDark) {
    final expenseTotals =
        Map<String, double>.from(data['expenseCategoryTotals']);
    final incomeTotals =
        Map<String, double>.from(data['incomeCategoryTotals']);
    final monthlyExpenses =
        Map<String, double>.from(data['monthlyExpenses']);
    final monthlyIncome = Map<String, double>.from(data['monthlyIncome']);
    final totalExpenses = (data['totalExpenses'] as num).toDouble();
    final totalIncome = (data['totalIncome'] as num).toDouble();
    final spendingRatio = (data['spendingRatio'] as num).toDouble();

    return [
      // ── Spending Health ────────────────────────────────────────────
      _SectionLabel('Spending Health', Icons.health_and_safety_rounded,
          const Color(0xFF9D50FF), isDark),
      const SizedBox(height: 10),
      _SpendHealthCard(
          ratio: spendingRatio,
          income: totalIncome,
          expense: totalExpenses,
          currency: currency,
          isDark: isDark),
      const SizedBox(height: 24),

      // ── Monthly Trend (Bar) ────────────────────────────────────────
      _SectionLabel('Monthly Overview', Icons.bar_chart_rounded,
          AppColors.primary, isDark),
      const SizedBox(height: 10),
      _buildBarChart(monthlyExpenses, monthlyIncome, isDark),
      const SizedBox(height: 24),

      // ── Trend Line ─────────────────────────────────────────────────
      _SectionLabel('Trend Line', Icons.show_chart_rounded,
          AppColors.accent, isDark),
      const SizedBox(height: 10),
      _buildLineChart(monthlyExpenses, monthlyIncome, isDark),
      const SizedBox(height: 24),

      // ── Category Breakdown ─────────────────────────────────────────
      _SectionLabel('Category Breakdown', Icons.donut_large_rounded,
          AppColors.expense, isDark),
      const SizedBox(height: 10),
      _buildCategorySection(expenseTotals, incomeTotals, currency, isDark),
    ];
  }

  // ── Bar Chart ───────────────────────────────────────────────────────────────

  Widget _buildBarChart(Map<String, double> expenses,
      Map<String, double> income, bool isDark) {
    final keys = expenses.keys.toList();
    final maxVal = [...expenses.values, ...income.values]
        .fold(0.0, (a, b) => a > b ? a : b);

    if (maxVal == 0) return _emptyWidget('No data yet', isDark);

    return _ChartCard(
      isDark: isDark,
      height: 230,
      legend: Row(children: [
        _Dot(AppColors.income), const SizedBox(width: 4),
        Text('Income', style: GoogleFonts.poppins(fontSize: 11)),
        const SizedBox(width: 12),
        _Dot(AppColors.expense), const SizedBox(width: 4),
        Text('Expense', style: GoogleFonts.poppins(fontSize: 11)),
      ]),
      child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.3,
        barGroups: List.generate(keys.length, (i) {
          final k = keys[i];
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: income[k] ?? 0,
              gradient: const LinearGradient(
                  colors: [Color(0xFF4DFFD8), Color(0xFF00C896)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter),
              width: 10,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            BarChartRodData(
              toY: expenses[k] ?? 0,
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF9999), Color(0xFFFF6B6B)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter),
              width: 10,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ]);
        }),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= keys.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(keys[i],
                      style: GoogleFonts.poppins(fontSize: 10,
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext)),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      )),
    );
  }

  // ── Line Chart ──────────────────────────────────────────────────────────────

  Widget _buildLineChart(Map<String, double> expenses,
      Map<String, double> income, bool isDark) {
    final keys = expenses.keys.toList();
    final maxVal = [...expenses.values, ...income.values]
        .fold(0.0, (a, b) => a > b ? a : b);

    if (maxVal == 0) return _emptyWidget('No data yet', isDark);

    LineChartBarData lineBar(
            List<FlSpot> spots, Color color, Color areaColor) =>
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3.5,
                  color: color,
                  strokeColor: Colors.white,
                  strokeWidth: 1.5)),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
                colors: [areaColor, areaColor.withOpacity(0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
          ),
        );

    return _ChartCard(
      isDark: isDark,
      height: 210,
      legend: Row(children: [
        _Dot(AppColors.income), const SizedBox(width: 4),
        Text('Income', style: GoogleFonts.poppins(fontSize: 11)),
        const SizedBox(width: 12),
        _Dot(AppColors.expense), const SizedBox(width: 4),
        Text('Expense', style: GoogleFonts.poppins(fontSize: 11)),
      ]),
      child: LineChart(LineChartData(
        lineBarsData: [
          lineBar(
              List.generate(keys.length,
                  (i) => FlSpot(i.toDouble(), income[keys[i]] ?? 0)),
              AppColors.income,
              AppColors.income.withOpacity(0.3)),
          lineBar(
              List.generate(keys.length,
                  (i) => FlSpot(i.toDouble(), expenses[keys[i]] ?? 0)),
              AppColors.expense,
              AppColors.expense.withOpacity(0.3)),
        ],
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= keys.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(keys[i],
                      style: GoogleFonts.poppins(fontSize: 10,
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext)),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
      )),
    );
  }

  // ── Category Section ─────────────────────────────────────────────────────────

  Widget _buildCategorySection(
      Map<String, double> expenseTotals,
      Map<String, double> incomeTotals,
      String currency,
      bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          // Tab bar inside card
          Container(
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.darkBackground : AppColors.lightBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelStyle: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  GoogleFonts.poppins(fontSize: 13),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor:
                  isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              tabs: const [
                Tab(text: 'Expenses'),
                Tab(text: 'Income'),
              ],
            ),
          ),
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Expense categories
                expenseTotals.isEmpty
                    ? _emptyWidget('No expenses in this period', isDark)
                    : _CategoryList(
                        totals: expenseTotals,
                        currency: currency,
                        color: AppColors.expense,
                        isDark: isDark,
                        touchedIndex: _touchedExpense,
                        onTouch: (i) =>
                            setState(() => _touchedExpense = i)),
                // Income categories
                incomeTotals.isEmpty
                    ? _emptyWidget('No income in this period', isDark)
                    : _CategoryList(
                        totals: incomeTotals,
                        currency: currency,
                        color: AppColors.income,
                        isDark: isDark,
                        touchedIndex: _touchedIncome,
                        onTouch: (i) =>
                            setState(() => _touchedIncome = i)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyWidget(String msg, bool isDark) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded,
              size: 40,
              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
          const SizedBox(height: 8),
          Text(msg,
              style: GoogleFonts.poppins(
                  color: isDark
                      ? AppColors.darkSubtext
                      : AppColors.lightSubtext,
                  fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Category List with mini donut ────────────────────────────────────────────

class _CategoryList extends StatelessWidget {
  final Map<String, double> totals;
  final String currency;
  final Color color;
  final bool isDark;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _CategoryList({
    required this.totals,
    required this.currency,
    required this.color,
    required this.isDark,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final total = top.fold(0.0, (s, e) => s + e.value);
    final touched = touchedIndex >= 0 && touchedIndex < top.length
        ? top[touchedIndex]
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // ── Centered donut with total in middle ──────────────────────
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: List.generate(top.length, (i) {
                      final isTouched = touchedIndex == i;
                      final barColor = AppColors.chartColors[
                          i % AppColors.chartColors.length];
                      return PieChartSectionData(
                        value: top[i].value,
                        color: barColor,
                        title: '',
                        radius: isTouched ? 62 : 52,
                        borderSide: isTouched
                            ? BorderSide(color: barColor, width: 2)
                            : BorderSide.none,
                      );
                    }),
                    centerSpaceRadius: 46,
                    sectionsSpace: 3,
                    pieTouchData: PieTouchData(
                      touchCallback: (e, r) =>
                          onTouch(r?.touchedSection?.touchedSectionIndex ?? -1),
                    ),
                  ),
                ),
                // Center label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      touched != null
                          ? CurrencyFormatter.formatCompact(
                              touched.value, currency)
                          : CurrencyFormatter.formatCompact(total, currency),
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: touched != null
                              ? AppColors.chartColors[touchedIndex %
                                  AppColors.chartColors.length]
                              : color),
                    ),
                    Text(
                      touched != null ? touched.key : 'Total',
                      style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.lightSubtext),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Category rows ──────────────────────────────────────────
          ...List.generate(top.length, (i) {
                final entry = top[i];
                final barColor =
                    AppColors.chartColors[i % AppColors.chartColors.length];
                final pct = total > 0 ? entry.value / total : 0.0;
                final isHighlighted = touchedIndex == i;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? barColor.withOpacity(0.1)
                        : (isDark
                            ? AppColors.darkBackground
                            : AppColors.lightBackground),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isHighlighted
                            ? barColor.withOpacity(0.4)
                            : Colors.transparent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: barColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: isHighlighted
                                      ? FontWeight.w700
                                      : FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(pct * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkSubtext
                                    : AppColors.lightSubtext),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.formatCompact(
                                entry.value, currency),
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: barColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: barColor.withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation(barColor),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                );
              }),
        ],
      ),
    );
  }
}

// ── Spending Health Card ─────────────────────────────────────────────────────

class _SpendHealthCard extends StatelessWidget {
  final double ratio;
  final double income;
  final double expense;
  final String currency;
  final bool isDark;

  const _SpendHealthCard({
    required this.ratio,
    required this.income,
    required this.expense,
    required this.currency,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final clampedRatio = ratio.clamp(0.0, 100.0) / 100;
    final color = ratio > 90
        ? AppColors.error
        : ratio > 70
            ? AppColors.warning
            : AppColors.income;
    final label = ratio > 90
        ? '⚠️ Overspending!'
        : ratio > 70
            ? '🔶 Watch Out'
            : '✅ Healthy';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('You spent',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkSubtext
                            : AppColors.lightSubtext)),
                Text('${ratio.toStringAsFixed(1)}% of income',
                    style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ]),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: clampedRatio,
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.7), color],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  label: 'Income',
                  value: CurrencyFormatter.formatCompact(income, currency),
                  color: AppColors.income,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'Spent',
                  value: CurrencyFormatter.formatCompact(expense, currency),
                  color: AppColors.expense,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatPill(
                  label: 'Saved',
                  value: CurrencyFormatter.formatCompact(
                      (income - expense).abs(), currency),
                  color: AppColors.savings,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.white54)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatPill(
      {required this.label,
      required this.value,
      required this.color,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  color:
                      isDark ? AppColors.darkSubtext : AppColors.lightSubtext)),
          Text(value,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _SectionLabel(this.title, this.icon, this.color, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _ChartCard extends StatelessWidget {
  final Widget child;
  final Widget legend;
  final bool isDark;
  final double height;

  const _ChartCard(
      {required this.child,
      required this.legend,
      required this.isDark,
      required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          legend,
          const SizedBox(height: 8),
          SizedBox(height: height - 40, child: child),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);

  @override
  Widget build(BuildContext context) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
