import 'dart:async';
import 'dart:io';
import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/custom_widgets/custom_textfield.dart';
import 'package:expense_tracker/pages/home_page.dart';
import 'package:expense_tracker/pages/Auth/register_page.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double deviceHeight = MediaQuery.of(context).size.height;
    double deviceWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: -deviceWidth / 1.15,
              top: -deviceHeight / 10,
              child: Transform.rotate(
                angle: 3.14 / 3.5,
                child: Container(
                  height: deviceHeight / 2,
                  width: deviceWidth,
                  decoration: const BoxDecoration(
                    color: Color(0xffe8f6f3),
                    borderRadius: BorderRadius.all(Radius.circular(40)),
                  ),
                ),
              ),
            ),
            Column(
              // mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: deviceHeight / 5),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    color: Colors.green,
                    size: 40,
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          Text(
                            "Welcome Back",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            "Login to continue",
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 25),
                          CustomTextfield(
                            textEditingController: emailController,
                            hintText: 'Email',
                            icon: Icons.email_outlined,
                            isPassword: false,
                          ),
                          SizedBox(height: 20),
                          CustomTextfield(
                            textEditingController: passwordController,
                            hintText: "Password",
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          SizedBox(height: 30),
                          SizedBox(
                            width: deviceWidth,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: () async {
                                await userAuthenticated();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xff3ead91),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text("Don't have an Account? "),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => RegisterPage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  "Register now",
                                  style: TextStyle(color: Color(0xff3ead91)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> userAuthenticated() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email cannot be empty"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password cannot be empty"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${UserUrl}login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool("isLoggedIn", true);
        await prefs.setString("email", email);
        await prefs.setString("password", password);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login successful"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomePage(
              userId: data['id'] ?? 0,
              email: email,
              password: password,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid Credentials"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on SocketException catch (e) {
      debugPrint("Login SocketException: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Server is unreachable. Please check your internet connection."),
          backgroundColor: Colors.red,
        ),
      );
    } on TimeoutException catch (e) {
      debugPrint("Login TimeoutException: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Connection timed out. Please try again later."),
          backgroundColor: Colors.red,
        ),
      );
    } on http.ClientException catch (e) {
      debugPrint("Login ClientException: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Client error. Please verify network settings."),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      debugPrint("Login unexpected exception: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unexpected error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
