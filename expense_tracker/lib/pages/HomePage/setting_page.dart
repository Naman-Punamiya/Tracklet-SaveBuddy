import 'dart:convert';

import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_dimensions.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_shadows.dart';
import 'package:expense_tracker/core/theme/app_spacing.dart';
import 'package:expense_tracker/core/theme/app_text_theme.dart';
import 'package:expense_tracker/keep_alive_service.dart';
import 'package:expense_tracker/pages/Auth/login_page.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/category_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingPage extends StatefulWidget {
  final String email;
  final String password;
  const SettingPage({super.key, required this.email, required this.password});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool isDarkMode = false;

  String get basicAuth =>
      'Basic ${base64Encode(utf8.encode('${widget.email}:${widget.password}'))}';

  String _getUserInitial() {
    if (widget.email.isNotEmpty) {
      return widget.email[0].toUpperCase();
    }
    return 'U';
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xLarge),
        backgroundColor: AppColors.lightSurface,
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: AppColors.expense, size: AppDimensions.icon24),
            SizedBox(width: AppSpacing.small),
            Text(
              "Logout",
              style: AppTextTheme.titleLarge,
            ),
          ],
        ),
        content: const Text(
          "Are you sure you want to log out of Tracklet SaveBuddy?",
          style: AppTextTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Cancel", style: AppTextTheme.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: AppColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.medium,
              ),
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xLarge),
        backgroundColor: AppColors.lightSurface,
        title: Row(
          children: [
            Container(
              padding: AppSpacing.p8,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: AppDimensions.icon22),
            ),
            const SizedBox(width: AppSpacing.small),
            const Text("About Tracklet", style: AppTextTheme.titleLarge),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tracklet SaveBuddy",
              style: AppTextTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              "Version 1.0.0 (Build 100)",
              style: AppTextTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              "Tracklet SaveBuddy is your modern offline-first finance & expense tracking assistant designed to manage books, budgets, and investments effortlessly.",
              style: AppTextTheme.bodyMedium.copyWith(height: 1.4),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              "Developer: Tracklet Dev Team",
              style: AppTextTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Close", style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xLarge),
        backgroundColor: AppColors.lightSurface,
        title: Text(title, style: AppTextTheme.titleLarge),
        content: Text(message, style: AppTextTheme.bodyMedium.copyWith(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Close", style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.large, 4, AppSpacing.xSmall),
      child: Text(
        title,
        style: AppTextTheme.labelSmall.copyWith(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xSmall),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: AppRadius.large,
        boxShadow: AppShadows.cardShadowList,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.large,
        child: InkWell(
          borderRadius: AppRadius.large,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: AppSpacing.p12,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: AppDimensions.icon20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextTheme.bodyLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: AppDimensions.icon22,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: AppSpacing.p20,
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: AppRadius.xLarge,
        boxShadow: AppShadows.cardShadowList,
      ),
      child: Row(
        children: [
          Container(
            width: AppDimensions.avatarSize56,
            height: AppDimensions.avatarSize56,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getUserInitial(),
                style: AppTextTheme.headlineLarge.copyWith(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.email.split('@').first,
                  style: AppTextTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.email,
                  style: AppTextTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xSmall),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: AppRadius.medium,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.cloud_done_rounded, color: AppColors.primary, size: 13),
                      SizedBox(width: 4),
                      Text(
                        "Auto Sync Active",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        surfaceTintColor: AppColors.lightBackground,
        elevation: 0,
        title: Text(
          "Settings",
          style: AppTextTheme.displayLarge,
        ),
        toolbarHeight: 70,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(AppSpacing.medium, AppSpacing.xSmall, AppSpacing.medium, 40),
        children: [
          _buildProfileCard(),

          _buildSectionHeader("ACCOUNT"),
          _buildSettingTile(
            icon: Icons.person_outline_rounded,
            title: "Profile Information",
            subtitle: "Update account details & credentials",
            onTap: () => _showInfoDialog("Profile Information", "Account Email: ${widget.email}\nStatus: Active User"),
          ),
          _buildSettingTile(
            icon: Icons.category_outlined,
            title: "Category Management",
            subtitle: "Create, edit & customize expense categories",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryPage(
                    email: widget.email,
                    password: widget.password,
                  ),
                ),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.security_outlined,
            title: "Security & Passwords",
            subtitle: "Manage password & login protection",
            onTap: () => _showInfoDialog("Security", "Your account credentials are encrypted and stored safely."),
          ),

          _buildSectionHeader("PREFERENCES"),
          _buildSettingTile(
            icon: Icons.palette_outlined,
            title: "Dark Mode Theme",
            subtitle: "Switch between light and dark themes",
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: AppRadius.small,
                  ),
                  child: Text(
                    "Coming Soon",
                    style: AppTextTheme.labelSmall.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                Switch.adaptive(
                  value: isDarkMode,
                  activeTrackColor: AppColors.primary,
                  onChanged: (val) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Dark Mode theme coming soon in next update!"),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _buildSettingTile(
            icon: Icons.notifications_outlined,
            title: "Notifications",
            subtitle: "Manage daily expense reminder alerts",
            onTap: () => _showInfoDialog("Notifications", "Daily expense reminder notifications are enabled."),
          ),
          _buildSettingTile(
            icon: Icons.currency_rupee_rounded,
            title: "Currency Unit",
            subtitle: "₹ INR (Indian Rupee)",
            onTap: () => _showInfoDialog("Currency", "Default currency is set to Indian Rupee (₹)."),
          ),
          _buildSettingTile(
            icon: Icons.language_rounded,
            title: "Language",
            subtitle: "English (Default)",
            onTap: () => _showInfoDialog("Language", "App language is set to English."),
          ),

          _buildSectionHeader("DATA & SYNC"),
          _buildSettingTile(
            icon: Icons.download_rounded,
            title: "Export Data",
            subtitle: "Backup your transactions in PDF or CSV format",
            onTap: () => _showInfoDialog("Export Data", "Go to Reports & Analytics to export PDF/CSV files."),
          ),
          _buildSettingTile(
            icon: Icons.cloud_done_outlined,
            title: "Auto Sync Status",
            subtitle: "Seamless offline SQLite & Spring Boot sync",
            onTap: () => _showInfoDialog("Auto Sync", "Offline-first sync engine is actively running in background."),
          ),

          _buildSectionHeader("APP & ABOUT"),
          _buildSettingTile(
            icon: Icons.privacy_tip_outlined,
            title: "Privacy Policy",
            subtitle: "Read our data protection policies",
            onTap: () => _showInfoDialog("Privacy Policy", "Tracklet SaveBuddy values your financial privacy. All transaction data remains strictly encrypted."),
          ),
          _buildSettingTile(
            icon: Icons.description_outlined,
            title: "Terms & Conditions",
            subtitle: "Review terms of service",
            onTap: () => _showInfoDialog("Terms & Conditions", "By using Tracklet SaveBuddy, you agree to local offline record keeping guidelines."),
          ),
          _buildSettingTile(
            icon: Icons.mail_outline_rounded,
            title: "Contact Developer",
            subtitle: "Get help & submit feedback",
            onTap: () => _showInfoDialog("Contact Developer", "Reach out to support@tracklet-savebuddy.com for assistance."),
          ),
          _buildSettingTile(
            icon: Icons.info_outline_rounded,
            title: "About Tracklet SaveBuddy",
            subtitle: "Version 1.0.0 (Build 100)",
            onTap: _showAboutDialog,
          ),

          const SizedBox(height: AppSpacing.medium),

          Container(
            decoration: BoxDecoration(
              color: AppColors.expenseTint,
              borderRadius: AppRadius.large,
              border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: AppRadius.large,
              child: InkWell(
                borderRadius: AppRadius.large,
                onTap: _showLogoutDialog,
                child: Padding(
                  padding: AppSpacing.p16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout_rounded, color: AppColors.expense, size: AppDimensions.icon22),
                      SizedBox(width: AppSpacing.small),
                      Text(
                        "Logout Account",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> logout() async {
    KeepAliveService.stop();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }
}
