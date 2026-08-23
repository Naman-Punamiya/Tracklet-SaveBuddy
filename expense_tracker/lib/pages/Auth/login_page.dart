import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:expense_tracker/constant.dart';
import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_dimensions.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_shadows.dart';
import 'package:expense_tracker/core/theme/app_spacing.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/custom_widgets/custom_textfield.dart';
import 'package:expense_tracker/pages/Auth/register_page.dart';
import 'package:expense_tracker/pages/home_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

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
      backgroundColor: AppColors.lightSurface,
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
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.all(Radius.circular(40)),
                  ),
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: AppSpacing.p24,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.lightSurface,
                                borderRadius: AppRadius.dialog,
                                boxShadow: AppShadows.cardShadowList,
                              ),
                              child: const Icon(
                                Icons.attach_money,
                                color: AppColors.primary,
                                size: 90,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xLarge),
                            Text(
                              "Welcome Back",
                              style: AppTextTheme.displayLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Login to continue",
                              style: AppTextTheme.bodyMedium,
                            ),
                            const SizedBox(height: AppSpacing.xxLarge),
                            CustomTextfield(
                              textEditingController: emailController,
                              hintText: 'Email',
                              icon: Icons.email_outlined,
                              isPassword: false,
                            ),
                            const SizedBox(height: AppSpacing.medium),
                            CustomTextfield(
                              textEditingController: passwordController,
                              hintText: "Password",
                              icon: Icons.lock_outline,
                              isPassword: true,
                            ),
                            const SizedBox(height: AppSpacing.xSmall),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Forgot password functionality coming soon!",
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xLarge),
                            SizedBox(
                              width: double.infinity,
                              height: AppDimensions.buttonHeight52,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        await userAuthenticated();
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                                  foregroundColor: AppColors.textWhite,
                                  elevation: 2,
                                  shadowColor: AppColors.shadowPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppRadius.medium,
                                  ),
                                ),
                                child: _isLoading
                                    ? const AppButtonLoading()
                                    : const Text(
                                        "Login",
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: AppTextTheme.bodyMedium,
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) => const RegisterPage(),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 2,
                                    ),
                                    child: Text(
                                      "Create one",
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> userAuthenticated() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email cannot be empty"),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid email address (e.g. user@example.com)"),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password cannot be empty"),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse('${userUrl}login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({"email": email, "password": password}),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = safeJsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final int fetchedUserId = (data['id'] as num?)?.toInt() ?? 0;
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool("isLoggedIn", true);
          await prefs.setString("email", email);
          await prefs.setString("password", password);
          if (fetchedUserId > 0) {
            await prefs.setInt("userId", fetchedUserId);
          }

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Login successful"),
              backgroundColor: AppColors.income,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomePage(
                userId: fetchedUserId,
                email: email,
                password: password,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Server returned an invalid response. Please try again."),
              backgroundColor: AppColors.expense,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid Credentials"),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } on SocketException catch (e) {
      debugPrint("Login SocketException: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Server is unreachable. Please check your internet connection.",
          ),
          backgroundColor: AppColors.expense,
        ),
      );
    } on TimeoutException catch (e) {
      debugPrint("Login TimeoutException: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Connection timed out. Please try again later."),
          backgroundColor: AppColors.expense,
        ),
      );
    } on http.ClientException catch (e) {
      debugPrint("Login ClientException: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Client error. Please verify network settings."),
          backgroundColor: AppColors.expense,
        ),
      );
    } catch (e) {
      debugPrint("Login unexpected exception: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unexpected error: $e"),
          backgroundColor: AppColors.expense,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
