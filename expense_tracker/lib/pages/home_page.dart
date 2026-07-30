import 'dart:convert';

import 'package:expense_tracker/keep_alive_service.dart';
import 'package:expense_tracker/pages/HomePage/book_page.dart';
import 'package:expense_tracker/pages/HomePage/investment_page.dart';
import 'package:expense_tracker/pages/HomePage/setting_page.dart';
import 'package:expense_tracker/services/share_intent_service.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  final int userId;
  final String email;
  final String password;
  const HomePage({
    super.key,
    required this.userId,
    required this.email,
    required this.password,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();

    _checkSharedText();
  }

  Future<void> _checkSharedText() async {
    final text = await ShareIntentService.getSharedText();

    if (text != null) {
      print("Received from Android:");
      print(text);
    }
  }

  @override
  void dispose() {
    KeepAliveService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      BookPage(email: widget.email, password: widget.password),

      InvestmentPage(email: widget.email, password: widget.password),

      SettingPage(email: widget.email, password: widget.password),
    ];

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
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400),
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
                child: Icon(Icons.menu_book_rounded, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 24,
                  color: Color(0xFF3EAD91),
                ),
              ),
              label: "Books",
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.auto_graph_rounded, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(
                  Icons.auto_graph_rounded,
                  size: 24,
                  color: Color(0xFF3EAD91),
                ),
              ),
              label: "Investment",
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.tune_rounded, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(
                  Icons.tune_rounded,
                  size: 24,
                  color: Color(0xFF3EAD91),
                ),
              ),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }
}
