import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_dimensions.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_shadows.dart';
import 'package:expense_tracker/core/theme/app_spacing.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/custom_widgets/custom_textfield.dart';
import 'package:expense_tracker/pages/Auth/forgot_password_page.dart';
import 'package:expense_tracker/pages/Auth/login_page.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:flutter/material.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? token;
  final UserRepository? userRepository;

  const ResetPasswordPage({super.key, this.token, this.userRepository});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  late final UserRepository _userRepository;
  bool _isLoading = false;
  bool _success = false;
  String? _errorMessage;
  bool _canRequestAnother = false;

  @override
  void initState() {
    super.initState();
    _userRepository = widget.userRepository ?? UserRepository();
  }

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isPasswordValid(String password) {
    if (password.length < 8) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    return hasLetter && hasDigit;
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    final token = (widget.token ?? '').trim();
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'This reset link is invalid or missing a token. Please request a new password reset.';
        _canRequestAnother = true;
      });
      return;
    }
    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password cannot be empty'), backgroundColor: AppColors.expense),
      );
      return;
    }
    if (!_isPasswordValid(newPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters and include at least one letter and one number'),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppColors.expense),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _canRequestAnother = false;
    });

    try {
      final result = await _userRepository.resetPassword(token: token, newPassword: newPassword);
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _success = true;
          _errorMessage = null;
        });
      } else {
        final lower = result.message.toLowerCase();
        final canRequestAnother = lower.contains('expired') || lower.contains('invalid') || lower.contains('used');
        setState(() {
          _errorMessage = result.message;
          _canRequestAnother = canRequestAnother;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _requestAnotherReset() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tokenMissing = (widget.token ?? '').trim().isEmpty;

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
                  _success ? Icons.check_circle : Icons.password,
                  color: _success
                      ? AppColors.income
                      : (isDark ? AppColors.primaryAccent : AppColors.primary),
                  size: 64,
                ),
              ),
              const SizedBox(height: AppSpacing.xLarge),
              Text(
                _success ? 'Password Reset' : 'Set New Password',
                style: AppTextTheme.displayLargeFor(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _success
                    ? 'Your password has been updated successfully.'
                    : 'Choose a strong new password for your account.',
                style: AppTextTheme.bodyMediumFor(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxLarge),
              if (_success) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.income.withValues(alpha: 0.1),
                    borderRadius: AppRadius.medium,
                    border: Border.all(color: AppColors.income.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'You can now log in with your new password.',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xLarge),
                SizedBox(
                  height: AppDimensions.buttonHeight52,
                  child: ElevatedButton(
                    onPressed: _goToLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textWhite,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
                    ),
                    child: const Text('Back to Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ] else ...[
                if (tokenMissing || _errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.large),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.expense.withValues(alpha: 0.08),
                      borderRadius: AppRadius.medium,
                      border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _errorMessage ?? 'This reset link is invalid or missing a token. Please request a new password reset.',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (_canRequestAnother || tokenMissing) ...[
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _requestAnotherReset,
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            child: Text(
                              'Request a new reset link',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.primaryAccent
                                    : AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (!tokenMissing) ...[
                  CustomTextfield(
                    textEditingController: newPasswordController,
                    hintText: 'New password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  CustomTextfield(
                    textEditingController: confirmPasswordController,
                    hintText: 'Confirm new password',
                    icon: Icons.lock_reset,
                    isPassword: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Password must be at least 8 characters and include at least one letter and one number.',
                    style: AppTextTheme.bodySmallFor(context),
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
                          : const Text('Reset password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 20),
              if (!_success)
                TextButton(
                  onPressed: _goToLogin,
                  child: Text(
                    'Back to Login',
                    style: TextStyle(
                      color:
                          isDark ? AppColors.primaryAccent : AppColors.primary,
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
