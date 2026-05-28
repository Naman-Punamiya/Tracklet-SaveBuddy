import 'package:expense_tracker/pages/home_page.dart';
import 'package:expense_tracker/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences prefs = await SharedPreferences.getInstance();

  bool isLoggedIn = prefs.getBool("isLoggedIn") ?? false;

  String email = prefs.getString("email") ?? "";

  String password = prefs.getString("password") ?? "";

  runApp(MyApp(isLoggedIn: isLoggedIn, email: email, password: password));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String email;
  final String password;
  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.email,
    required this.password,
  });
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: isLoggedIn
          ? HomePage(userId: 0, email: email, password: password)
          : LoginPage(),
    );
  }
}
