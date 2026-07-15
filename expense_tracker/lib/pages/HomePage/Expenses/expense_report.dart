import 'dart:convert';

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
  late Future<void> reportFuture;
  List<dynamic> allExpenses = [];
  List<dynamic> filteredExpenses = [];
  String selectedPeriod = "This Month";

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

  final List<String> periods = ["Today", "This Week", "This Month"];
  final List<Color> categoryColors = [
    Colors.orange,
    Colors.purple,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.red,
    Colors.pink,
    Colors.amber,
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
    if (!mounted) return;
    setState(() {
      allExpenses = List<dynamic>.from(items);
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
        case "This Week":
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(const Duration(days: 7));
          return date.isAfter(
                startOfWeek.subtract(const Duration(seconds: 1)),
              ) &&
              date.isBefore(endOfWeek);
        case "This Month":
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
          "Others";
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
    switch (category.toLowerCase()) {
      case "food":
        return Icons.fastfood;
      case "shopping":
        return Icons.shopping_bag;
      case "travel":
        return Icons.flight;
      case "bills":
      case "utilities":
        return Icons.receipt_long;
      case "investment":
        return Icons.trending_up;
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.09),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAmount(amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
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
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    if (categoryWiseExpense.isEmpty || expense == 0) {
      return const SizedBox(
        height: 220,
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
          radius: i == 0 ? 64 : 56,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 230,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 36,
              sectionsSpace: 3,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (int i = 0; i < entries.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: categoryColors[i % categoryColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${entries[i].key}: ${_formatAmount(entries[i].value)}",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    final maxY = [income, expense].reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 210,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 10 : maxY * 1.2,
          alignment: BarChartAlignment.spaceAround,
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

                  return Text(label, style: const TextStyle(fontSize: 10));
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
                      child: Text("Income"),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text("Expense"),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: income,
                  color: Colors.green,
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
                  color: Colors.red,
                  width: 32,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ],
        ),
      ),
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
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xff5B5FEF),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xff5B5FEF).withValues(alpha: 0.10),
              ),
            ),
          ],
          gridData: FlGridData(show: true, drawVerticalLine: false),
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

                  return Text(label, style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxX > 7 ? (maxX / 4).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final day = value.toInt();

                  // Show only selected labels to avoid crowding
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
                      style: const TextStyle(fontSize: 10),
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
                CircleAvatar(
                  radius: 16,
                  backgroundColor: categoryColors[i % categoryColors.length]
                      .withValues(alpha: 0.15),
                  child: Icon(
                    _categoryIcon(entries[i].key),
                    color: categoryColors[i % categoryColors.length],
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entries[i].key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _formatAmount(entries[i].value),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                Text(
                  "${((entries[i].value / expense) * 100).toStringAsFixed(0)}%",
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
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
        "Others";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.emoji_events, color: Colors.amber, size: 22),
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
              const Icon(Icons.currency_rupee, color: Colors.red, size: 20),
              const SizedBox(width: 4),
              Text(
                _formatAmount(_parseAmount(item['amount'])),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.category_outlined, size: 18, color: Colors.blue),
              const SizedBox(width: 6),
              Text(category),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(DateFormat("dd MMM yyyy").format(date)),
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
            "Others";
        final date = _parseDate(item['date']);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isCredit
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.red.withValues(alpha: 0.12),
                child: Icon(
                  isCredit ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isCredit ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCredit ? "Income" : "Expense",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCredit ? Colors.green : Colors.red,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "${isCredit ? "+" : "-"}${_formatAmount(amount)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCredit ? Colors.green : Colors.red,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Reports & Analytics",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await _loadReports();

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Reports updated"),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                    child: const Text("Retry"),
                  ),
                ],
              ),
            );
          }

          if (allExpenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: Colors.grey.shade500,
                    size: 64,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "No Reports Available",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Start adding expenses to see analytics.",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          if (filteredExpenses.isEmpty) {
            return _buildNoPeriodData();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _loadReports();

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Reports updated"),
                  duration: Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        selectedPeriod,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedPeriod,
                            borderRadius: BorderRadius.circular(12),
                            items: periods.map((period) {
                              return DropdownMenuItem<String>(
                                value: period,
                                child: Text(period),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              _onPeriodChanged(value);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOverviewCard(
                          "Income",
                          income,
                          Colors.green,
                          Icons.arrow_upward,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildOverviewCard(
                          "Expense",
                          expense,
                          Colors.red,
                          Icons.arrow_downward,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildOverviewCard(
                    "Balance",
                    balance,
                    balance > 0
                        ? Colors.green
                        : balance < 0
                        ? Colors.red
                        : Colors.blue,
                    Icons.account_balance_wallet_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: "Spending Pie Chart",
                    child: _buildPieChart(),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: "Income vs Expense",
                    child: _buildBarChart(),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: "Monthly Spending Trend",
                    child: _buildLineChart(),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: "Category Breakdown",
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 70,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 20),

            Text(
              "No transactions for $selectedPeriod",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              "Try selecting another period.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
