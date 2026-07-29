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
import 'package:expense_tracker/pages/Auth/login_page.dart';
import 'package:expense_tracker/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
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
                            const SizedBox(height: AppSpacing.large),
                            Text(
                              "Create Account",
                              style: AppTextTheme.displayLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Let's get you started",
                              style: AppTextTheme.bodyMedium,
                            ),
                            const SizedBox(height: 28),
                            CustomTextfield(
                              textEditingController: fullNameController,
                              hintText: "Full Name",
                              icon: Icons.person_outline,
                              isPassword: false,
                            ),
                            const SizedBox(height: AppSpacing.medium),
                            CustomTextfield(
                              textEditingController: emailController,
                              hintText: "Email",
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
                            const SizedBox(height: AppSpacing.medium),
                            CustomTextfield(
                              textEditingController: confirmPasswordController,
                              hintText: "Confirm Password",
                              icon: Icons.lock_outline,
                              isPassword: true,
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: AppDimensions.buttonHeight52,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        if (passwordController.text.trim() !=
                                            confirmPasswordController.text.trim()) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Passwords do not match!"),
                                              backgroundColor: AppColors.expense,
                                            ),
                                          );
                                          return;
                                        } else {
                                          userAuthenticated();
                                        }
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
                                        "Register",
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xLarge),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Already have an account? ",
                                  style: AppTextTheme.bodyMedium,
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (context) => const LoginPage(),
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
                                      "Sign in",
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
    final name = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Name cannot be empty"),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Email cannot be empty"),
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
            Uri.parse("${userUrl}register"),
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode({
              "name": name,
              "email": email,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode != 200 && response.statusCode != 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration failed! Please try again."),
            backgroundColor: AppColors.expense,
          ),
        );
        return;
      } else {
        final data = jsonDecode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool("isLoggedIn", true);
        await prefs.setString("email", email);
        await prefs.setString("password", password);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration successful!"),
            backgroundColor: AppColors.income,
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
      }
    } on SocketException catch (e) {
      debugPrint("Register SocketException: $e");
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
      debugPrint("Register TimeoutException: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Connection timed out. Please try again later."),
          backgroundColor: AppColors.expense,
        ),
      );
    } on http.ClientException catch (e) {
      debugPrint("Register ClientException: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Client error. Please verify network settings."),
          backgroundColor: AppColors.expense,
        ),
      );
    } catch (e) {
      debugPrint("Register unexpected exception: $e");
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
