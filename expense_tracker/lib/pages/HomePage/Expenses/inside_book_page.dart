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
      backgroundColor: const Color(0xFFF9FAFB),
      body: pages[currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x0D000000), // ~5% opacity soft floating shadow
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          elevation: 0,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF3EAD91),
          unselectedItemColor: Colors.grey.shade500,
          selectedFontSize: 13,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
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
                child: Icon(Icons.receipt_long_rounded, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.receipt_long_rounded, size: 24, color: Color(0xFF3EAD91)),
              ),
              label: "Expenses Details",
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.bar_chart_rounded, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.bar_chart_rounded, size: 24, color: Color(0xFF3EAD91)),
              ),
              label: "Expense Reports",
            ),
          ],
        ),
      ),
    );
  }
}
