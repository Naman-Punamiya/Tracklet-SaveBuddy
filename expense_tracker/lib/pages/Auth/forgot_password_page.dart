import 'dart:async';

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_dimensions.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_shadows.dart';
import 'package:expense_tracker/core/theme/app_spacing.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/custom_widgets/custom_textfield.dart';
import 'package:expense_tracker/pages/Auth/login_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  final UserRepository? userRepository;

  const ForgotPasswordPage({super.key, this.userRepository});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  late final UserRepository _userRepository;
  bool _isLoading = false;
  bool _submitted = false;
  String _infoMessage = '';

  @override
  void initState() {
    super.initState();
    _userRepository = widget.userRepository ?? UserRepository();
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    final email = emailController.text.trim();
    final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email cannot be empty"), backgroundColor: AppColors.expense),
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

    setState(() => _isLoading = true);
    try {
      final result = await _userRepository.forgotPassword(email: email);
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _submitted = true;
          _infoMessage = result.message;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: AppColors.expense),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: AppSpacing.p24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: AppRadius.dialog,
                  boxShadow: isDark ? null : AppShadows.cardShadowList,
                ),
                child: Icon(
                  Icons.lock_reset,
                  color: isDark ? AppColors.primaryAccent : AppColors.primary,
                  size: 64,
                ),
              ),
              const SizedBox(height: AppSpacing.xLarge),
              Text(
                'Forgot Password',
                style: AppTextTheme.displayLargeFor(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your email address and we\'ll send you instructions to reset your password.',
                style: AppTextTheme.bodyMediumFor(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxLarge),
              if (_submitted) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.1),
                    borderRadius: AppRadius.medium,
                    border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.income),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Check your email',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _infoMessage.isNotEmpty
                            ? _infoMessage
                            : "If an account exists with this email address, you will receive password reset instructions shortly.",
                        style: AppTextTheme.bodyMediumFor(context),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The reset link expires in 20 minutes. If you don\'t see the email, check your spam folder.',
                        style: AppTextTheme.bodySmallFor(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xLarge),
                SizedBox(
                  height: AppDimensions.buttonHeight52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => setState(() => _submitted = false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark
                            ? AppColors.primaryAccent
                            : AppColors.primary,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
                    ),
                    child: const Text('Use a different email'),
                  ),
                ),
              ] else ...[
                CustomTextfield(
                  textEditingController: emailController,
                  hintText: 'Email',
                  icon: Icons.email_outlined,
                  isPassword: false,
                ),
                const SizedBox(height: AppSpacing.xLarge),
                SizedBox(
                  height: AppDimensions.buttonHeight52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                      foregroundColor: AppColors.textWhite,
                      elevation: 2,
                      shadowColor: AppColors.shadowPrimary,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
                    ),
                    child: _isLoading
                        ? const AppButtonLoading()
                        : const Text(
                            'Send reset instructions',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  }
                },
                child: Text(
                  'Back to Login',
                  style: TextStyle(
                    color: isDark ? AppColors.primaryAccent : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
