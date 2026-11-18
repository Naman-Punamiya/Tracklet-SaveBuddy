import 'package:expense_tracker/core/theme/app_colors.dart';
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
    this.password = '',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAF8F3),
      body: pages[currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF3F4F6),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            elevation: 0,
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            selectedItemColor:
                isDark ? AppColors.primaryAccent : const Color(0xFF065F46),
            unselectedItemColor:
                isDark ? AppColors.textMuted : const Color(0xFF6B7280),
            selectedFontSize: 12,
            unselectedFontSize: 12,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4.0),
                  child: Icon(Icons.receipt_long_rounded, size: 22),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4.0),
                  child: Icon(Icons.receipt_long_rounded, size: 22),
                ),
                label: "Expenses",
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4.0),
                  child: Icon(Icons.bar_chart_rounded, size: 22),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4.0),
                  child: Icon(Icons.bar_chart_rounded, size: 22),
                ),
                label: "Report",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
