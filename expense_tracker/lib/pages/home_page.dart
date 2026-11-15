import 'dart:convert';

import 'package:expense_tracker/features/expense_import/parser/parser_manager.dart';
import 'package:expense_tracker/keep_alive_service.dart';
import 'package:expense_tracker/pages/HomePage/book_page.dart';
import 'package:expense_tracker/pages/HomePage/investment_page.dart';
import 'package:expense_tracker/pages/HomePage/setting_page.dart';
import 'package:expense_tracker/services/auth_storage_service.dart';
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
    this.password = '',
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;
  String get basicAuth => AuthStorageService.instance.currentAuthToken.isNotEmpty
      ? AuthStorageService.instance.currentAuthToken
      : 'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  @override
  void initState() {
    super.initState();

    _checkSharedText();
  }

  Future<void> _checkSharedText() async {
    final text = await ShareIntentService.getSharedText();

    if (text != null) {
      final receipt = ParserManager().parse(text);

      debugPrint(receipt.toString());
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
      backgroundColor: const Color(0xFFFBF9F4),
      body: pages[currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          elevation: 0,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0A7A3E),
          unselectedItemColor: const Color(0xFF9CA3AF),
          selectedFontSize: 13,
          unselectedFontSize: 13,
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
                child: Icon(Icons.menu_book_rounded, size: 22),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 22,
                  color: Color(0xFF0A7A3E),
                ),
              ),
              label: "Books",
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.auto_graph_rounded, size: 22),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(
                  Icons.auto_graph_rounded,
                  size: 22,
                  color: Color(0xFF0A7A3E),
                ),
              ),
              label: "Investments",
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.tune_rounded, size: 22),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(
                  Icons.tune_rounded,
                  size: 22,
                  color: Color(0xFF0A7A3E),
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
