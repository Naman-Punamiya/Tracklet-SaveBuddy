import 'package:expense_tracker/pages/HomePage/Expenses/expense_page.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/expense_report.dart';
import 'package:flutter/material.dart';

class BookInsideHomePage extends StatefulWidget {
  final String email;
  final String password;
  final String bookId;
  final String bookName;
  const BookInsideHomePage({
    super.key,
    required this.email,
    required this.password,
    required this.bookId,
    required this.bookName,
  });

  @override
  State<BookInsideHomePage> createState() => _BookInsideHomePageState();
}

class _BookInsideHomePageState extends State<BookInsideHomePage> {
  int currentIndex = 0;
  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();

    pages = [
      ExpensePage(
        email: widget.email,
        password: widget.password,
        bookId: widget.bookId,
        bookName: widget.bookName,
      ),
      ExpenseReport(
        bookId: widget.bookId,
        email: widget.email,
        password: widget.password,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long, color: Colors.black),
            label: "Expenses Details",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart, color: Colors.black),
            label: "Expense Reports",
          ),
        ],
      ),
    );
  }
}
