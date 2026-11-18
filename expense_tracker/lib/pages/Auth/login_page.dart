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
import 'package:expense_tracker/pages/Auth/forgot_password_page.dart';
import 'package:expense_tracker/pages/Auth/register_page.dart';
import 'package:expense_tracker/pages/home_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/auth_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  final http.Client? client;
  const LoginPage({super.key, this.client});

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
                            const SizedBox(height: AppSpacing.xLarge),
                            Text(
                              "Welcome Back",
                              style: AppTextTheme.displayLargeFor(context),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Login to continue",
                              style: AppTextTheme.bodyMediumFor(context),
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
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.primaryAccent
                                        : AppColors.primary,
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
                                  style: AppTextTheme.bodyMediumFor(context),
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
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 2,
                                    ),
                                    child: Text(
                                      "Create one",
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
      final client = widget.client;
      final response = client != null
          ? await client.post(
              Uri.parse('${userUrl}login'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({"email": email, "password": password}),
            ).timeout(const Duration(seconds: 15))
          : await http.post(
              Uri.parse('${userUrl}login'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({"email": email, "password": password}),
            ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
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

          // Start cloud synchronization in the background after successful login
          final basicAuth = AuthStorageService.instance.currentAuthToken.isNotEmpty
              ? AuthStorageService.instance.currentAuthToken
              : 'Basic ${base64Encode(utf8.encode('$email:$password'))}';
          SyncEngine.markInitialSyncStarted();
          unawaited(SyncEngine.syncAll(basicAuth, client: widget.client).catchError((e) {
            debugPrint("Background sync after login error: $e");
          }));

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
