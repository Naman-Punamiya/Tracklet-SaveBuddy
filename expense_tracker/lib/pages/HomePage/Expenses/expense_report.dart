import 'dart:convert';

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExpenseReport extends StatefulWidget {
  final String bookId;
  final String email;
  final String password;
  const ExpenseReport({
    super.key,
    required this.bookId,
    required this.email,
    required this.password,
  });

  @override
  State<ExpenseReport> createState() => _ExpenseReportState();
}

class _ExpenseReportState extends State<ExpenseReport> {
  final ExpenseRepository expenseRepo = ExpenseRepository();
  final CategoryRepository categoryRepo = CategoryRepository();

  late Future<void> reportFuture;
  List<dynamic> allExpenses = [];
  List<dynamic> filteredExpenses = [];
  List<dynamic> categories = [];
  String selectedPeriod = "Monthly";

  double income = 0;
  double expense = 0;
  double balance = 0;
  double averageExpense = 0;
  double highestExpense = 0;
  double lowestExpense = 0;
  double highestIncome = 0;
  double lowestIncome = 0;
  Map<String, double> categoryWiseExpense = {};
  List<double> dailyExpenses = [];
  Map<String, dynamic>? largestExpense;
  List<dynamic> recentTransactions = [];
  int totalTransactions = 0;

  final List<String> periods = ["Today", "Weekly", "Monthly", "Yearly"];
  final List<Color> categoryColors = [
    const Color(0xFF3EAD91),
    const Color(0xFFF59E0B),
    const Color(0xFF8B5CF6),
    const Color(0xFF3B82F6),
    const Color(0xFF14B8A6),
    const Color(0xFFEC4899),
    const Color(0xFF6366F1),
    const Color(0xFF10B981),
  ];

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();
    reportFuture = _loadReports();
  }

  Future<void> _loadReports() async {
    final items = await fetchExpenses(widget.bookId, basicAuth);
    final cats = await categoryRepo.getCategories();
    if (!mounted) return;
    setState(() {
      allExpenses = List<dynamic>.from(items);
      categories = List<dynamic>.from(cats);
      _recalculateReports();
    });
  }

  Future<List<dynamic>> fetchExpenses(String bookId, String basicAuth) async {
    return await expenseRepo.getExpenses(bookId);
  }

  void _onPeriodChanged(String period) {
    if (!mounted) return;
    setState(() {
      selectedPeriod = period;
      _recalculateReports();
    });
  }

  void _recalculateReports() {
    filteredExpenses = _filterExpensesByPeriod(allExpenses);
    income = calculateIncome(filteredExpenses);
    expense = calculateExpense(filteredExpenses);
    balance = income - expense;
    averageExpense = calculateAverageExpense(filteredExpenses);
    highestExpense = calculateHighestExpense(filteredExpenses);
    lowestExpense = calculateLowestExpense(filteredExpenses);
    highestIncome = _calculateHighestIncome(filteredExpenses);
    lowestIncome = _calculateLowestIncome(filteredExpenses);
    categoryWiseExpense = calculateCategoryWiseExpense(filteredExpenses);
    dailyExpenses = calculateDailyExpenses(filteredExpenses);
    largestExpense = calculateLargestExpense(filteredExpenses);
    recentTransactions = calculateRecentTransactions(filteredExpenses);
    totalTransactions = filteredExpenses.length;
  }

  List<dynamic> _filterExpensesByPeriod(List<dynamic> items) {
    final now = DateTime.now();
    return items.where((item) {
      final date = _parseDate(item['date']);
      switch (selectedPeriod) {
        case "Today":
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        case "Weekly":
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 7));
          return date.isAfter(
                startOfWeek.subtract(const Duration(seconds: 1)),
              ) &&
              date.isBefore(endOfWeek);
        case "Yearly":
          return date.year == now.year;
        case "Monthly":
        default:
          return date.year == now.year && date.month == now.month;
      }
    }).toList();
  }

  double calculateIncome(List<dynamic> expenses) {
    return expenses.fold(0.0, (total, item) {
      if (_isCredit(item)) {
        return total + _parseAmount(item['amount']);
      }
      return total;
    });
  }

  double calculateExpense(List<dynamic> expenses) {
    return expenses.fold(0.0, (total, item) {
      if (!_isCredit(item)) {
        return total + _parseAmount(item['amount']);
      }
      return total;
    });
  }

  double calculateAverageExpense(List<dynamic> expenses) {
    final onlyExpenses = expenses.where((item) => !_isCredit(item)).toList();
    if (onlyExpenses.isEmpty) {
      return 0;
    }
    return calculateExpense(expenses) / onlyExpenses.length;
  }

  double calculateHighestExpense(List<dynamic> expenses) {
    final onlyExpenses = expenses.where((item) => !_isCredit(item)).toList();
    if (onlyExpenses.isEmpty) {
      return 0;
    }
    return onlyExpenses
        .map((item) => _parseAmount(item['amount']))
        .reduce((a, b) => a > b ? a : b);
  }

  double calculateLowestExpense(List<dynamic> expenses) {
    final onlyExpenses = expenses.where((item) => !_isCredit(item)).toList();
    if (onlyExpenses.isEmpty) {
      return 0;
    }
    return onlyExpenses
        .map((item) => _parseAmount(item['amount']))
        .reduce((a, b) => a < b ? a : b);
  }

  Map<String, double> calculateCategoryWiseExpense(List<dynamic> expenses) {
    final map = <String, double>{};
    for (final item in expenses) {
      if (_isCredit(item)) {
        continue;
      }
      final categoryName =
          item['category']?['name']?.toString() ??
          item['category_name']?.toString() ??
          "Uncategorized";
      map[categoryName] =
          (map[categoryName] ?? 0) + _parseAmount(item['amount']);
    }
    return map;
  }

  List<double> calculateDailyExpenses(List<dynamic> expenses) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final totals = List<double>.filled(daysInMonth, 0);

    for (final item in expenses) {
      if (_isCredit(item)) {
        continue;
      }
      final date = _parseDate(item['date']);
      if (date.year == now.year && date.month == now.month) {
        totals[date.day - 1] += _parseAmount(item['amount']);
      }
    }
    return totals;
  }

  Map<String, dynamic>? calculateLargestExpense(List<dynamic> expenses) {
    final onlyExpenses = expenses.where((item) => !_isCredit(item)).toList();
    if (onlyExpenses.isEmpty) {
      return null;
    }
    onlyExpenses.sort(
      (a, b) => _parseAmount(b['amount']).compareTo(_parseAmount(a['amount'])),
    );
    return onlyExpenses.first;
  }

  List<dynamic> calculateRecentTransactions(List<dynamic> expenses) {
    final sorted = List<dynamic>.from(expenses);
    sorted.sort(
      (a, b) => _parseDate(b['date']).compareTo(_parseDate(a['date'])),
    );
    return sorted.take(5).toList();
  }

  double _calculateHighestIncome(List<dynamic> expenses) {
    final onlyIncome = expenses.where((item) => _isCredit(item)).toList();
    if (onlyIncome.isEmpty) {
      return 0;
    }
    return onlyIncome
        .map((item) => _parseAmount(item['amount']))
        .reduce((a, b) => a > b ? a : b);
  }

  double _calculateLowestIncome(List<dynamic> expenses) {
    final onlyIncome = expenses.where((item) => _isCredit(item)).toList();
    if (onlyIncome.isEmpty) {
      return 0;
    }
    return onlyIncome
        .map((item) => _parseAmount(item['amount']))
        .reduce((a, b) => a < b ? a : b);
  }

  bool _isCredit(dynamic item) {
    final credit = item['credit'];
    return credit == true ||
        credit == 1 ||
        credit.toString().toLowerCase() == "true";
  }

  double _parseAmount(dynamic amount) {
    if (amount is num) {
      return amount.toDouble();
    }
    return double.tryParse(amount?.toString() ?? "0") ?? 0;
  }

  DateTime _parseDate(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? "") ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  final NumberFormat formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  String _formatAmount(double value) {
    return formatter.format(value);
  }

  IconData _categoryIcon(String category) {
    for (final c in categories) {
      if (c['name'] == category) {
        return _getIconFromName(c['icon']);
      }
    }
    return _getIconFromName(category);
  }

  IconData _getIconFromName(String? iconName) {
    switch (iconName) {
      case "Food":
        return Icons.fastfood_rounded;
      case "Transportation":
        return Icons.directions_car_rounded;
      case "Shopping":
        return Icons.shopping_bag_rounded;
      case "Home":
        return Icons.home_rounded;
      case "Receipt":
        return Icons.receipt_long_rounded;
      case "Investment":
        return Icons.trending_up_rounded;
      case "Savings":
        return Icons.account_balance_wallet_rounded;
      case "Utilities":
        return Icons.lightbulb_outline_rounded;
      case "Healthcare":
        return Icons.medical_services_rounded;
      case "Gifts":
        return Icons.card_giftcard_rounded;
      case "Travel":
        return Icons.flight_rounded;
      case "Education":
        return Icons.school_rounded;
      case "Pets":
        return Icons.pets_rounded;
      case "Person":
        return Icons.person_rounded;
      case "More":
        return Icons.more_horiz_rounded;
      default:
        return Icons.category_outlined;
    }
  }

  Widget _buildOverviewCard(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _formatAmount(amount),
                    key: ValueKey<double>(amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTopSpendingCategoryCard() {
    if (categoryWiseExpense.isEmpty || expense == 0) {
      return const SizedBox.shrink();
    }

    final sortedEntries = categoryWiseExpense.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategory = sortedEntries.first;
    final percent = ((topCategory.value / expense) * 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6F3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3EAD91).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF3EAD91),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _categoryIcon(topCategory.key),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Top Spending Category",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3EAD91),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  topCategory.key,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
                Text(
                  "$percent% of total expenses",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatAmount(topCategory.value),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3EAD91),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    if (categoryWiseExpense.isEmpty || expense == 0) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text("No expense data for this period")),
      );
    }

    final entries = categoryWiseExpense.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < entries.length; i++) {
      final percent = (entries[i].value / expense) * 100;
      sections.add(
        PieChartSectionData(
          color: categoryColors[i % categoryColors.length],
          value: entries[i].value,
          title: "${percent.toStringAsFixed(0)}%",
          radius: i == 0 ? 52 : 44,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 32,
              sectionsSpace: 3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Redesigned Scan Legend: 🟢 Food   $240 (32%)
        Column(
          children: [
            for (int i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: categoryColors[i % categoryColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        _categoryIcon(entries[i].key),
                        size: 16,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entries[i].key,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade900,
                          ),
                        ),
                      ),
                      Text(
                        _formatAmount(entries[i].value),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F6F3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${((entries[i].value / expense) * 100).toStringAsFixed(0)}%",
                          style: const TextStyle(
                            color: Color(0xFF3EAD91),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    final maxY = [income, expense].reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        // Income / Expense Badges Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  "Income",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  "Expense",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 210,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 10 : maxY * 1.2,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.grey.shade900,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = groupIndex == 0 ? "Income" : "Expense";
                    return BarTooltipItem(
                      "$label\n${_formatAmount(rod.toY)}",
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: maxY == 0 ? 5 : (maxY * 1.2) / 4,
                    getTitlesWidget: (value, meta) {
                      String label;
                      if (value >= 100000) {
                        label = "₹${(value / 100000).toStringAsFixed(1)}L";
                      } else if (value >= 1000) {
                        label = "₹${(value / 1000).toStringAsFixed(0)}k";
                      } else {
                        label = "₹${value.toInt()}";
                      }
                      return Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() == 0) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text("Income", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text("Expense", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                ),
              ),
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: income,
                      color: const Color(0xFF10B981),
                      width: 32,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [
                    BarChartRodData(
                      toY: expense,
                      color: const Color(0xFFEF4444),
                      width: 32,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart() {
    final spots = <FlSpot>[];
    for (int i = 0; i < dailyExpenses.length; i++) {
      spots.add(FlSpot((i + 1).toDouble(), dailyExpenses[i]));
    }
    final maxY = dailyExpenses.fold<double>(
      0,
      (previous, amount) => amount > previous ? amount : previous,
    );
    double maxX = dailyExpenses.isEmpty ? 1 : dailyExpenses.length.toDouble();

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: maxX,
          minY: 0,
          maxY: maxY == 0 ? 10 : maxY * 1.2,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.grey.shade900,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    "Day ${spot.x.toInt()}\n${_formatAmount(spot.y)}",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF3EAD91),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF3EAD91).withValues(alpha: 0.12),
              ),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: maxY == 0 ? 5 : (maxY * 1.2) / 4,
                getTitlesWidget: (value, meta) {
                  String label;
                  if (value >= 100000) {
                    label = "₹${(value / 100000).toStringAsFixed(1)}L";
                  } else if (value >= 1000) {
                    label = "₹${(value / 1000).toStringAsFixed(0)}k";
                  } else {
                    label = "₹${value.toInt()}";
                  }
                  return Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxX > 7 ? (maxX / 4).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final day = value.toInt();
                  if (day != 1 &&
                      day != 8 &&
                      day != 15 &&
                      day != 22 &&
                      day != 29) {
                    return const SizedBox.shrink();
                  }

                  final now = DateTime.now();
                  final date = DateTime(now.year, now.month, day);

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat("d MMM").format(date),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (categoryWiseExpense.isEmpty || expense == 0) {
      return const Text("No expense category data for this period");
    }

    final entries = categoryWiseExpense.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        for (int i = 0; i < entries.length; i++)
          Container(
            margin: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F6F3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _categoryIcon(entries[i].key),
                    color: const Color(0xFF3EAD91),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entries[i].key,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.grey.shade900,
                    ),
                  ),
                ),
                Text(
                  _formatAmount(entries[i].value),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F6F3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "${((entries[i].value / expense) * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(
                      color: Color(0xFF3EAD91),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLargestExpense() {
    if (largestExpense == null) {
      return const Text("No expenses available in this period");
    }

    final item = largestExpense!;
    final date = _parseDate(item['date']);
    final category =
        item['category']?['name']?.toString() ??
        item['category_name']?.toString() ??
        "Uncategorized";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 22),
              SizedBox(width: 8),
              Text(
                "Largest Expense",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item['description']?.toString() ?? "No Description",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.currency_rupee, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 4),
              Text(
                _formatAmount(_parseAmount(item['amount'])),
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F6F3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _categoryIcon(category),
                  size: 14,
                  color: const Color(0xFF3EAD91),
                ),
              ),
              const SizedBox(width: 6),
              Text(category, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(DateFormat("dd MMM yyyy").format(date), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (recentTransactions.isEmpty) {
      return const Text("No transactions available in this period");
    }

    return Column(
      children: recentTransactions.map((item) {
        final isCredit = _isCredit(item);
        final amount = _parseAmount(item['amount']);
        final category =
            item['category']?['name']?.toString() ??
            item['category_name']?.toString() ??
            "Uncategorized";
        final date = _parseDate(item['date']);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isCredit
                      ? const Color(0xFFE6F4EA)
                      : const Color(0xFFFDE8E8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCredit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['description']?.toString() ?? "",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$category • ${DateFormat("dd MMM").format(date)}",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isCredit
                          ? const Color(0xFFE6F4EA)
                          : const Color(0xFFFDE8E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isCredit ? "Income" : "Expense",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${isCredit ? "+" : "-"}${_formatAmount(amount)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                "Total Transactions",
                totalTransactions.toString(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                "Average Expense",
                _formatAmount(averageExpense),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                "Highest Expense",
                _formatAmount(highestExpense),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                "Lowest Expense",
                _formatAmount(lowestExpense),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                "Highest Income",
                _formatAmount(highestIncome),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatTile(
                "Lowest Income",
                _formatAmount(lowestIncome),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              value,
              key: ValueKey<String>(value),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        surfaceTintColor: const Color(0xFFF9FAFB),
        elevation: 0,
        title: Text(
          "Reports & Analytics",
          style: TextStyle(
            color: Colors.grey.shade900,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F6F3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              iconSize: 20,
              tooltip: "Refresh",
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await _loadReports();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Reports updated"),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3EAD91)),
            ),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Failed to load reports"),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      await _loadReports();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textWhite,
                    ),
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          if (allExpenses.isEmpty) {
            return AppEmptyState(
              icon: Icons.analytics_outlined,
              title: "No Report Data",
              description: "Add transactions to generate insightful reports.",
              buttonLabel: "Add Transaction",
              onButtonPressed: () {
                Navigator.pop(context);
              },
            );
          }

          return RefreshIndicator(
            color: const Color(0xFF3EAD91),
            onRefresh: () async {
              await _loadReports();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period Filter Chips Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: periods.map((period) {
                        final isSelected = selectedPeriod == period;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(
                              period == "Weekly"
                                  ? "This Week"
                                  : period == "Monthly"
                                      ? "This Month"
                                      : period == "Yearly"
                                          ? "This Year"
                                          : period,
                            ),
                            selectedColor: const Color(0xFFE8F6F3),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF3EAD91)
                                  : Colors.grey.shade200,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF3EAD91)
                                  : Colors.grey.shade700,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) => _onPeriodChanged(period),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (filteredExpenses.isEmpty)
                    _buildNoPeriodData()
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildOverviewCard(
                            "Income",
                            income,
                            const Color(0xFF10B981),
                            Icons.arrow_upward_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildOverviewCard(
                            "Expense",
                            expense,
                            const Color(0xFFEF4444),
                            Icons.arrow_downward_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildOverviewCard(
                      "Net Savings",
                      balance,
                      balance >= 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      Icons.account_balance_wallet_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildTopSpendingCategoryCard(),
                    _buildSectionCard(
                      title: "Spending Breakdown",
                      child: _buildPieChart(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: "Income vs Expense",
                      child: _buildBarChart(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: "Spending Trend",
                      child: _buildLineChart(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: "Category Details",
                      child: _buildCategoryBreakdown(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: "Largest Expense",
                      child: _buildLargestExpense(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: "Recent Transactions",
                      child: _buildRecentTransactions(),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      title: "Quick Statistics",
                      child: _buildQuickStats(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoPeriodData() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F6F3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.analytics_outlined,
                size: 64,
                color: Color(0xFF3EAD91),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "No transactions for $selectedPeriod",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Try selecting another period filter above.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
