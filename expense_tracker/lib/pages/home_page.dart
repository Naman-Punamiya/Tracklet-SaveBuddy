import 'dart:convert';

import 'package:expense_tracker/pages/book_page.dart';
import 'package:expense_tracker/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      BookPage(
        userId: widget.userId,
        email: widget.email,
        password: widget.password,
      ),

      Center(
        child: Text(
          "Email: ${widget.email}",
          style: const TextStyle(fontSize: 20),
        ),
      ),

      Center(
        child: ElevatedButton(onPressed: logout, child: const Text("Logout")),
      ),
    ];
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
            icon: Icon(Icons.book, color: Colors.black),
            label: "Books",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_graph, color: Colors.black),
            label: "Investment",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, color: Colors.black),
            label: "Settings",
          ),
        ],
      ),
    );
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => LoginPage()));
  }
}
