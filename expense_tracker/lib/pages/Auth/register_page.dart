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
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/pages/Auth/login_page.dart';
import 'package:expense_tracker/pages/home_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/auth_storage_service.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double deviceHeight = MediaQuery.of(context).size.height;
    double deviceWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightSurface,
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
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primaryAccent.withValues(alpha: 0.10)
                        : AppColors.primaryTint,
                    borderRadius: const BorderRadius.all(Radius.circular(40)),
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
                                color: isDark
                                    ? AppColors.darkSurface
                                    : AppColors.lightSurface,
                                borderRadius: AppRadius.dialog,
                                boxShadow: isDark
                                    ? null
                                    : AppShadows.cardShadowList,
                              ),
                              child: Icon(
                                Icons.attach_money,
                                color: isDark
                                    ? AppColors.primaryAccent
                                    : AppColors.primary,
                                size: 90,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.large),
                            Text(
                              "Create Account",
                              style: AppTextTheme.displayLargeFor(context),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Let's get you started",
                              style: AppTextTheme.bodyMediumFor(context),
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
                                onPressed: _isLoading ? null : userAuthenticated,
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
                                  style: AppTextTheme.bodyMediumFor(context),
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
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 2,
                                    ),
                                    child: Text(
                                      "Sign in",
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.primaryAccent
                                            : AppColors.primary,
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
    final confirmPassword = confirmPasswordController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your full name"),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your email address"),
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
          content: Text("Please enter a password"),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password must be at least 6 characters long"),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
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
        final data = safeJsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final int fetchedUserId = (data['id'] as num?)?.toInt() ?? 0;
          SharedPreferences prefs = await SharedPreferences.getInstance();
          final String? previousEmail = prefs.getString("last_logged_in_email") ?? prefs.getString("email");
          final String normalizedPreviousEmail = (previousEmail ?? "").trim().toLowerCase();
          final String normalizedIncomingEmail = email.trim().toLowerCase();

          // If a different user was previously logged in on this device, purge local tables for user isolation
          if (normalizedPreviousEmail.isNotEmpty && normalizedPreviousEmail != normalizedIncomingEmail) {
            await DatabaseHelper.instance.clearAllData();
            SyncEngine.resetInitialSync();
          }

          // Update last_logged_in_email to the successfully authenticated account
          await prefs.setString("last_logged_in_email", normalizedIncomingEmail);
          await prefs.setBool("isLoggedIn", true);
          await prefs.setString("email", email);
          // Securely save credentials into Keystore backed storage
          await AuthStorageService.instance.saveCredentials(email: email, password: password);
          // Purge any legacy plaintext password from SharedPreferences
          await prefs.remove("password");
          if (fetchedUserId > 0) {
            await prefs.setInt("userId", fetchedUserId);
          }

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
