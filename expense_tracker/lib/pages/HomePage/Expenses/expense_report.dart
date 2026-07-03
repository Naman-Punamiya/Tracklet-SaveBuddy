import 'dart:convert';

import 'package:expense_tracker/custom_widgets/category_breakdown_tile.dart';
import 'package:expense_tracker/custom_widgets/custom_summarycard.dart';
import 'package:expense_tracker/custom_widgets/item_legend.dart';
import 'package:expense_tracker/services/expense_api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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
  late Future<List<dynamic>> expensesFuture;
  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();

    expensesFuture = fetchExpenses(widget.bookId, basicAuth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Expense Report",
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 30),
        ),
        toolbarHeight: 100,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: expensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No expenses found"));
          }

          final items = snapshot.data!;
          final report = generateReport(items);
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Card(
                    elevation: 2,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(flex: 2, child: buildSummary(report)),
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 230,
                                  child: PieChart(
                                    PieChartData(
                                      centerSpaceRadius: 50,
                                      sectionsSpace: 2,
                                      sections: buildPieChartSections(report),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20),
                          Wrap(
                            spacing: 15,
                            runSpacing: 5,
                            children: buildLegend(report),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Expenses by Category",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 5),
                  Card(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(children: buildCategoryBreakdown(report)),
                    ),
                  ),
                  SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Summary",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 5),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          CustomSummaryCard(
                            title: "Total Income",
                            amount: report['income'],
                            color: Colors.blue,
                            icon: Icons.arrow_upward,
                          ),
                          SizedBox(width: 10),
                          CustomSummaryCard(
                            title: "Total Expenses",
                            amount: report['expense'],
                            color: Colors.red,
                            icon: Icons.arrow_downward,
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      CustomSummaryCard(
                        title: "Remaining",
                        amount: report['balance'],
                        color: Colors.green,
                        icon: Icons.account_balance_wallet,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> generateReport(List<dynamic> items) {
    double income = 0;
    double expense = 0;
    Map<String, double> categoryTotals = {};

    for (var item in items) {
      double amount = item['amount'];
      bool isIncome = item['credit'];
      if (isIncome) {
        income += amount;
      } else {
        expense += amount;

        String category = item['category']['name'];
        categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
      }
    }

    return {
      'income': income,
      'expense': expense,
      'balance': income - expense,
      'categories': categoryTotals,
    };
  }

  List<PieChartSectionData> buildPieChartSections(Map<String, dynamic> report) {
    Map<String, double> categories = Map<String, double>.from(
      report['categories'],
    );
    List<Color> colors = [
      Colors.orange,
      Colors.red,
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.pink,
      Colors.teal,
      Colors.amber,
    ];
    final List<PieChartSectionData> sections = [];
    int index = 0;
    double income = report['income'];

    categories.forEach((category, total) {
      double percent = income == 0 ? 0 : (total / income) * 100;
      final section = PieChartSectionData(
        color: colors[index % colors.length],
        value: total,
        title: "${percent.toStringAsFixed(1)}%",
        radius: 45,
        titleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
      sections.add(section);
      index++;
    });
    final double remaining = report['income'] - report['expense'];
    double remainingPercent = income == 0 ? 0 : (remaining / income) * 100;

    if (remaining > 0) {
      sections.add(
        PieChartSectionData(
          value: remaining,
          color: Colors.green,
          title: "${remainingPercent.toStringAsFixed(1)}%",
          radius: 45,
          titleStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return sections;
  }

  Widget buildSummary(Map<String, dynamic> report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Total Income",
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),

        Text(
          "₹${report['income']}",
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        SizedBox(height: 20),
        Text("Remaining", style: TextStyle(fontSize: 16, color: Colors.grey)),

        Text(
          "₹${report['balance']}",
          style: TextStyle(
            fontSize: 18,
            color: report['balance'] >= 0 ? Colors.green : Colors.red,
          ),
        ),
        SizedBox(height: 10),
        Text(
          "Total Expenses",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),

        Text(
          "₹${report['expense']}",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  List<Widget> buildLegend(Map<String, dynamic> report) {
    final categories = Map<String, double>.from(report['categories']);

    List<Color> colors = [
      Colors.orange,
      Colors.red,
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.pink,
      Colors.teal,
      Colors.amber,
    ];

    List<Widget> widgets = [];

    int index = 0;

    categories.forEach((category, amount) {
      widgets.add(
        LegendBox(color: colors[index], name: category, amount: amount),
      );

      index++;
    });

    widgets.add(
      LegendBox(
        color: Colors.green,
        name: "Remaining",
        amount: report['balance'],
      ),
    );

    return widgets;
  }

  List<Widget> buildCategoryBreakdown(Map<String, dynamic> report) {
    final categories = Map<String, double>.from(report['categories']);
    double income = report['income'];
    List<Color> colors = [
      Colors.orange,
      Colors.red,
      Colors.blue,
      Colors.purple,
      Colors.green,
      Colors.pink,
      Colors.teal,
      Colors.amber,
    ];

    List<Widget> widgets = [];
    int index = 0;

    categories.forEach((category, amount) {
      double percent = income == 0 ? 0 : (amount / income) * 100;
      widgets.add(
        CategoryBreakdownTile(
          category: category,
          amount: amount,
          percent: percent,
          color: colors[index % colors.length],
          // icon: getCategoryIcon(category),
        ),
      );
      index++;
    });

    return widgets;
  }

  IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case "food":
        return Icons.restaurant;

      case "shopping":
        return Icons.shopping_bag;

      case "transport":
        return Icons.directions_car;

      case "medical":
        return Icons.local_hospital;

      case "salary":
        return Icons.payments;

      default:
        return Icons.category;
    }
  }
}
