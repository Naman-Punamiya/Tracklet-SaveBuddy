import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/report_components.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/currency_service.dart';

class ExpenseReport extends StatefulWidget {
  final String bookId;
  final String email;
  final String password;

  const ExpenseReport({
    super.key,
    required this.bookId,
    required this.email,
    this.password = '',
  });

  @override
  State<ExpenseReport> createState() => _ExpenseReportState();
}

class _ExpenseReportState extends State<ExpenseReport> {
  final ExpenseRepository _expenseRepo = ExpenseRepository();
  final CategoryRepository _categoryRepo = CategoryRepository();

  late Future<void> _reportFuture;
  List<dynamic> _allExpenses = [];

  // Period: 0 = Week, 1 = Month, 2 = Year
  int _selectedPeriodIndex = 1; // Default to Month (as in Stitch design)
  DateTime _selectedDate = DateTime.now();

  // Metrics
  double _totalExpense = 0.0;
  double _totalIncome = 0.0;
  double _balance = 0.0;
  double _averageExpense = 0.0;
  double _highestExpense = 0.0;
  double _lowestExpense = 0.0;
  int _expenseEntriesCount = 0;
  List<ReportCategoryData> _categoryBreakdown = [];
  List<ReportIntervalData> _intervalData = [];
  List<dynamic> _filteredItems = [];
  int? _selectedBarIndex;
  bool _showAllCategories = false;

  // Stitch Design Palette
  static const Color stitchGreen = Color(0xFF065F46);
  static const Color stitchDarkGreenText = Color(0xFF111827);
  static const Color stitchBgLight = Color(0xFFFAF8F3);

  final List<Color> _chartPalette = const [
    Color(0xFF065F46), // Food: Emerald Green
    Color(0xFF3B82F6), // Home: Blue
    Color(0xFFF59E0B), // Transport: Amber
    Color(0xFF94A3B8), // Others: Slate Gray
    Color(0xFFEC4899), // Pink
    Color(0xFF8B5CF6), // Purple
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _reportFuture = _loadData();
  }

  Future<void> _loadData() async {
    final items = await _expenseRepo.getExpenses(widget.bookId);
    await _categoryRepo.getCategories();
    if (!mounted) return;
    setState(() {
      _allExpenses = List<dynamic>.from(items);
      _recalculateReport();
    });
  }

  void _recalculateReport() {
    _filteredItems = _filterExpensesBySelectedPeriod(_allExpenses);

    double inc = 0.0;
    double exp = 0.0;
    final Map<String, double> catSums = {};
    final Map<String, int> catCounts = {};
    final List<double> expenseAmounts = [];
    int expCount = 0;

    for (var item in _filteredItems) {
      final amt = _parseAmount(item['amount']);
      final isCredit = isTransactionCredit(item['credit']);

      if (isCredit) {
        inc += amt;
      } else {
        exp += amt;
        expCount++;
        expenseAmounts.add(amt);

        final catName = _getCategoryName(item);
        catSums[catName] = (catSums[catName] ?? 0.0) + amt;
        catCounts[catName] = (catCounts[catName] ?? 0) + 1;
      }
    }

    _totalIncome = inc;
    _totalExpense = exp;
    _balance = inc - exp;
    _expenseEntriesCount = expCount;

    if (expenseAmounts.isNotEmpty) {
      _averageExpense = exp / expenseAmounts.length;
      _highestExpense = expenseAmounts.reduce((a, b) => a > b ? a : b);
      _lowestExpense = expenseAmounts.reduce((a, b) => a < b ? a : b);
    } else {
      _averageExpense = 0.0;
      _highestExpense = 0.0;
      _lowestExpense = 0.0;
    }

    // Build category breakdown sorted descending by amount
    final sortedCats = catSums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<ReportCategoryData> breakdown = [];
    for (int i = 0; i < sortedCats.length; i++) {
      final entry = sortedCats[i];
      final pct = exp > 0 ? (entry.value / exp) * 100.0 : 0.0;
      final color = _chartPalette[i % _chartPalette.length];
      breakdown.add(
        ReportCategoryData(
          name: entry.key,
          amount: entry.value,
          count: catCounts[entry.key] ?? 1,
          percentage: pct,
          color: color,
        ),
      );
    }
    _categoryBreakdown = breakdown;

    // Calculate Interval Bars (Income vs Spending)
    _intervalData = _buildIntervalData(_filteredItems);
    _selectedBarIndex = null;
  }

  List<dynamic> _filterExpensesBySelectedPeriod(List<dynamic> items) {
    return items.where((item) {
      final date = _parseDate(item['date']);
      if (_selectedPeriodIndex == 0) {
        // Week
        final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        final monday = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return date.isAfter(monday.subtract(const Duration(seconds: 1))) &&
            date.isBefore(sunday.add(const Duration(seconds: 1)));
      } else if (_selectedPeriodIndex == 1) {
        // Month
        return date.year == _selectedDate.year && date.month == _selectedDate.month;
      } else {
        // Year
        return date.year == _selectedDate.year;
      }
    }).toList();
  }

  List<ReportIntervalData> _buildIntervalData(List<dynamic> items) {
    if (_selectedPeriodIndex == 0) {
      // Week: Mon..Sun (7 bars)
      final List<double> incs = List.filled(7, 0.0);
      final List<double> exps = List.filled(7, 0.0);
      for (var item in items) {
        final date = _parseDate(item['date']);
        final dayIndex = (date.weekday - 1) % 7;
        final amt = _parseAmount(item['amount']);
        if (isTransactionCredit(item['credit'])) {
          incs[dayIndex] += amt;
        } else {
          exps[dayIndex] += amt;
        }
      }
      final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      return List.generate(7, (i) => ReportIntervalData(label: days[i], income: incs[i], expense: exps[i]));
    } else if (_selectedPeriodIndex == 1) {
      // Month: W1..W4 (4 intervals as in Stitch design)
      final List<double> incs = List.filled(4, 0.0);
      final List<double> exps = List.filled(4, 0.0);
      for (var item in items) {
        final date = _parseDate(item['date']);
        final day = date.day;
        int weekBucket = 0;
        if (day <= 7) {
          weekBucket = 0;
        } else if (day <= 14) {
          weekBucket = 1;
        } else if (day <= 21) {
          weekBucket = 2;
        } else {
          weekBucket = 3;
        }
        final amt = _parseAmount(item['amount']);
        if (isTransactionCredit(item['credit'])) {
          incs[weekBucket] += amt;
        } else {
          exps[weekBucket] += amt;
        }
      }
      return [
        ReportIntervalData(label: "W1", income: incs[0], expense: exps[0]),
        ReportIntervalData(label: "W2", income: incs[1], expense: exps[1]),
        ReportIntervalData(label: "W3", income: incs[2], expense: exps[2]),
        ReportIntervalData(label: "W4", income: incs[3], expense: exps[3]),
      ];
    } else {
      // Year: Q1..Q4
      final List<double> incs = List.filled(4, 0.0);
      final List<double> exps = List.filled(4, 0.0);
      for (var item in items) {
        final date = _parseDate(item['date']);
        final qIndex = ((date.month - 1) ~/ 3).clamp(0, 3);
        final amt = _parseAmount(item['amount']);
        if (isTransactionCredit(item['credit'])) {
          incs[qIndex] += amt;
        } else {
          exps[qIndex] += amt;
        }
      }
      return [
        ReportIntervalData(label: "Q1", income: incs[0], expense: exps[0]),
        ReportIntervalData(label: "Q2", income: incs[1], expense: exps[1]),
        ReportIntervalData(label: "Q3", income: incs[2], expense: exps[2]),
        ReportIntervalData(label: "Q4", income: incs[3], expense: exps[3]),
      ];
    }
  }

  String _getCategoryName(dynamic item) {
    if (item == null) return "General";
    if (item['category'] is Map && item['category']['name'] != null) {
      return item['category']['name'].toString();
    }
    if (item['category_name'] != null && item['category_name'].toString().trim().isNotEmpty) {
      return item['category_name'].toString();
    }
    return "General";
  }

  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    return double.tryParse(amount.toString()) ?? 0.0;
  }

  DateTime _parseDate(dynamic raw) {
    if (raw == null) return DateTime.now();
    try {
      return DateTime.parse(raw.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatAmount(double amount) {
    return CurrencyService.formatCompact(amount);
  }

  void _onPeriodTabChanged(int index) {
    if (_selectedPeriodIndex == index) return;
    setState(() {
      _selectedPeriodIndex = index;
      _recalculateReport();
    });
  }

  void _navigatePeriod(int direction) {
    setState(() {
      if (_selectedPeriodIndex == 0) {
        _selectedDate = _selectedDate.add(Duration(days: direction * 7));
      } else if (_selectedPeriodIndex == 1) {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + direction, 1);
      } else {
        _selectedDate = DateTime(_selectedDate.year + direction, 1, 1);
      }
      _recalculateReport();
    });
  }

  String _getPeriodSelectorTitle() {
    if (_selectedPeriodIndex == 0) {
      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return "${DateFormat('d MMM').format(startOfWeek)} – ${DateFormat('d MMM yyyy').format(endOfWeek)}";
    } else if (_selectedPeriodIndex == 1) {
      return DateFormat('MMMM yyyy').format(_selectedDate);
    } else {
      return DateFormat('yyyy').format(_selectedDate);
    }
  }

  String _getPeriodWord() {
    if (_selectedPeriodIndex == 0) return "week";
    if (_selectedPeriodIndex == 1) return "month";
    return "year";
  }

  void _showMonthPickerSheet() {
    ReportComponents.showMonthPickerSheet(
      context: context,
      selectedDate: _selectedDate,
      onDateSelected: (newDate) {
        setState(() {
          _selectedDate = newDate;
          _recalculateReport();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : stitchBgLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _reportFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoading();
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text(
                        "Unable to load report data",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _reportFuture = _loadData();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: stitchGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              color: stitchGreen,
              onRefresh: () async {
                await _loadData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header Section (Cursive Title + Period Pill Toggle)
                    _buildHeader(isDark),

                    const SizedBox(height: 12),

                    // Period Navigator
                    ReportComponents.buildPeriodNavigator(
                      context: context,
                      isDark: isDark,
                      selectedPeriodIndex: _selectedPeriodIndex,
                      selectedDate: _selectedDate,
                      periodSelectorTitle: _getPeriodSelectorTitle(),
                      periodWord: _getPeriodWord(),
                      onPrevious: () => _navigatePeriod(-1),
                      onNext: () => _navigatePeriod(1),
                      onCurrent: () {
                        setState(() {
                          _selectedDate = DateTime.now();
                          _recalculateReport();
                        });
                      },
                      onSelectMonth: _showMonthPickerSheet,
                    ),

                    const SizedBox(height: 16),

                    // 2. Total Spent Section
                    ReportComponents.buildTotalSpentSection(
                      isDark: isDark,
                      periodWord: _getPeriodWord(),
                      totalExpense: _totalExpense,
                      totalIncome: _totalIncome,
                      balance: _balance,
                      formatAmount: _formatAmount,
                    ),

                    const SizedBox(height: 24),

                    // 3. Breakdown Section (Donut Chart + Category Bars)
                    ReportComponents.buildBreakdownSection(
                      isDark: isDark,
                      categoryBreakdown: _categoryBreakdown,
                      totalExpense: _totalExpense,
                      expenseEntriesCount: _expenseEntriesCount,
                      periodWord: _getPeriodWord(),
                      formatAmount: _formatAmount,
                    ),

                    const SizedBox(height: 24),

                    // 4. Income vs Spending Section (Paired Bar Chart)
                    ReportComponents.buildIncomeVsSpendingCard(
                      isDark: isDark,
                      intervalData: _intervalData,
                      selectedBarIndex: _selectedBarIndex,
                      onBarSelected: (idx) {
                        setState(() {
                          _selectedBarIndex = idx;
                        });
                      },
                      formatAmount: _formatAmount,
                    ),

                    const SizedBox(height: 20),

                    // 5. Highlight Card (Cursive Insight)
                    ReportComponents.buildHighlightCard(
                      isDark: isDark,
                      categoryBreakdown: _categoryBreakdown,
                      totalExpense: _totalExpense,
                      periodWord: _getPeriodWord(),
                    ),

                    const SizedBox(height: 20),

                    // 6. Overview Stats (Avg, Highest, Lowest)
                    ReportComponents.buildOverviewStats(
                      isDark: isDark,
                      averageExpense: _averageExpense,
                      highestExpense: _highestExpense,
                      lowestExpense: _lowestExpense,
                      expenseEntriesCount: _expenseEntriesCount,
                      formatAmount: _formatAmount,
                    ),

                    const SizedBox(height: 20),

                    // 7. All Categories Breakdown List
                    ReportComponents.buildAllCategoriesSection(
                      isDark: isDark,
                      categoryBreakdown: _categoryBreakdown,
                      showAllCategories: _showAllCategories,
                      onToggle: () {
                        setState(() {
                          _showAllCategories = !_showAllCategories;
                        });
                      },
                      formatAmount: _formatAmount,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header Section
  // ---------------------------------------------------------------------------
  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (Navigator.canPop(context)) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 26,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
            Text(
              "Report",
              style: GoogleFonts.caveat(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                color: isDark ? Colors.white : stitchDarkGreenText,
                height: 1.0,
              ),
            ),
          ],
        ),

        // Toggle Pill: Week | Month | Year
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDEDEA),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPeriodPillButton("Week", 0, isDark),
              _buildPeriodPillButton("Month", 1, isDark),
              _buildPeriodPillButton("Year", 2, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodPillButton(String title, int index, bool isDark) {
    final isSelected = _selectedPeriodIndex == index;
    return GestureDetector(
      onTap: () => _onPeriodTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF34D399) : stitchGreen)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? const Color(0xFF34D399) : stitchGreen)
                        .withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF052E23) : Colors.white)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
          ),
        ),
      ),
    );
  }
}
