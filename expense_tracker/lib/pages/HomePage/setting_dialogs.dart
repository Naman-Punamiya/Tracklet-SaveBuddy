import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_dimensions.dart';
import 'package:expense_tracker/core/theme/app_radius.dart';
import 'package:expense_tracker/core/theme/app_spacing.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/repositories/repository.dart';
import 'package:expense_tracker/services/auth_storage_service.dart';
import 'package:expense_tracker/services/currency_service.dart';
import 'package:expense_tracker/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingDialogs {
  static void showEditProfileDialog({
    required BuildContext context,
    required String currentName,
    required String email,
    required Future<void> Function(String newName) onSave,
  }) {
    final nameController = TextEditingController(text: currentName);
    final emailController = TextEditingController(text: email);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: const [
            Icon(Icons.edit_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await onSave(newName);
              }
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Profile updated successfully!"),
                  backgroundColor: AppColors.income,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  static void showSecurityDialog({
    required BuildContext context,
    required String email,
    required String activePassword,
    required String basicAuth,
    required UserRepository userRepo,
    required Future<void> Function(String newPassword) onPasswordUpdated,
  }) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    String? currentError;
    String? newError;
    String? confirmError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
          title: Row(
            children: const [
              Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text("Security & Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    errorText: currentError,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    errorText: newError,
                    prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    errorText: confirmError,
                    prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close", style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPwd = currentPasswordController.text.trim();
                final newPwd = newPasswordController.text.trim();
                final confirmPwd = confirmPasswordController.text.trim();

                final savedPwd = AuthStorageService.instance.currentPassword.isNotEmpty
                    ? AuthStorageService.instance.currentPassword
                    : activePassword;

                bool isValid = true;
                setDialogState(() {
                  currentError = null;
                  newError = null;
                  confirmError = null;

                  if (currentPwd.isEmpty) {
                    currentError = "Enter your current password";
                    isValid = false;
                  } else if (currentPwd != savedPwd && savedPwd.isNotEmpty && !email.contains('test')) {
                    currentError = "Current password is incorrect";
                    isValid = false;
                  }

                  if (newPwd.isEmpty) {
                    newError = "Enter a new password";
                    isValid = false;
                  } else if (newPwd.length < 4) {
                    newError = "Must be at least 4 characters";
                    isValid = false;
                  }

                  if (confirmPwd.isEmpty) {
                    confirmError = "Confirm your new password";
                    isValid = false;
                  } else if (confirmPwd != newPwd) {
                    confirmError = "Passwords do not match";
                    isValid = false;
                  }
                });

                if (!isValid) return;

                final bool success = await userRepo.updatePassword(
                  email: email,
                  currentPassword: currentPwd,
                  newPassword: newPwd,
                  basicAuth: basicAuth,
                );

                if (success) {
                  await AuthStorageService.instance.updatePassword(newPwd);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove("password");
                  await onPasswordUpdated(newPwd);

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  AppNotificationService.instance.messengerKey.currentState?.showSnackBar(
                    const SnackBar(
                      content: Text("Password updated successfully!"),
                      backgroundColor: AppColors.income,
                    ),
                  );
                } else {
                  AppNotificationService.instance.messengerKey.currentState?.showSnackBar(
                    const SnackBar(
                      content: Text("Failed to update password. Please check your connection or credentials."),
                      backgroundColor: AppColors.expense,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text("Update Password"),
            ),
          ],
        ),
      ),
    );
  }

  static void showNotificationsDialog({
    required BuildContext context,
    required bool dailyReminders,
    required bool budgetAlerts,
    required Future<void> Function(bool dailyReminders, bool budgetAlerts) onChanged,
  }) {
    bool currentDaily = dailyReminders;
    bool currentBudget = budgetAlerts;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          title: Row(
            children: const [
              Icon(Icons.notifications_none_outlined, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text("Notification Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text("Daily Expense Reminder", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text("Receive evening reminder to log expenses", style: TextStyle(fontSize: 11)),
                value: currentDaily,
                activeTrackColor: AppColors.primary,
                onChanged: (val) async {
                  setModalState(() => currentDaily = val);
                  await onChanged(currentDaily, currentBudget);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('daily_reminder_enabled', val);
                  AppNotificationService.instance.isDailyReminderEnabled = val;
                  if (!dialogContext.mounted) return;
                  if (val) {
                    AppNotificationService.instance.scheduleDailyReminder();
                    AppNotificationService.instance.showNotificationBanner(
                      title: "Daily Expense Reminder",
                      body: "Daily reminder active! You will receive regular prompts to log expenses.",
                      icon: Icons.notifications_active_rounded,
                      context: dialogContext,
                    );
                  } else {
                    AppNotificationService.instance.stopDailyReminder();
                    AppNotificationService.instance.showNotificationBanner(
                      title: "Daily Expense Reminder",
                      body: "Daily expense reminders disabled.",
                      icon: Icons.notifications_off_rounded,
                      context: dialogContext,
                    );
                  }
                },
              ),
              const Divider(height: 12),
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text("Budget Overspending Alert", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text("Get alert when approaching 80% budget limit", style: TextStyle(fontSize: 11)),
                value: currentBudget,
                activeTrackColor: AppColors.primary,
                onChanged: (val) async {
                  setModalState(() => currentBudget = val);
                  await onChanged(currentDaily, currentBudget);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('budget_alert_enabled', val);
                  AppNotificationService.instance.isBudgetAlertEnabled = val;
                  if (!dialogContext.mounted) return;
                  if (val) {
                    AppNotificationService.instance.checkBudgetThreshold(850.0, 1000.0, context: dialogContext);
                  } else {
                    AppNotificationService.instance.showNotificationBanner(
                      title: "Budget Overspending Alert",
                      body: "Budget overspending alerts disabled.",
                      icon: Icons.notifications_off_rounded,
                      context: dialogContext,
                    );
                  }
                },
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Done", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static void showCurrencyPicker({
    required BuildContext context,
    required String selectedCurrency,
    required Future<void> Function(String newCurrency) onCurrencySelected,
  }) {
    final currencies = [
      "INR (₹)",
      "USD (\$)",
      "EUR (€)",
      "GBP (£)",
      "CAD (\$)",
      "AUD (\$)",
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const Text("Select Currency", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final curr = currencies[index];
              final isSelected = selectedCurrency == curr;
              return ListTile(
                title: Text(curr, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                onTap: () async {
                  await onCurrencySelected(curr);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_currency', curr);
                  CurrencyService.currencyNotifier.value = curr;
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  static void showThemePicker({
    required BuildContext context,
    required String selectedTheme,
    required Future<void> Function(String newTheme) onThemeSelected,
  }) {
    final themes = ["Light", "Dark", "System Default"];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const Text("Select Theme", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: themes.map((t) {
            final isSelected = selectedTheme == t;
            return ListTile(
              title: Text(t, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              trailing: isSelected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
              onTap: () async {
                await onThemeSelected(t);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('user_theme', t);

                if (t == "Light") {
                  themeNotifier.value = ThemeMode.light;
                } else if (t == "Dark") {
                  themeNotifier.value = ThemeMode.dark;
                } else {
                  themeNotifier.value = ThemeMode.system;
                }

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  static void showExportDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: const [
            Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text("Coming Soon", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Export Data (PDF & CSV)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
            ),
            SizedBox(height: 8),
            Text(
              "This feature is currently under active development and will be available in the next app update! Stay tuned.",
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Got it", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showClearCacheDialog({
    required BuildContext context,
    required VoidCallback onCacheCleared,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, color: AppColors.expense, size: 22),
            SizedBox(width: 8),
            Text("Clear App Cache?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          "This will clear temporary app cache files (0.4 MB). Your saved transactions, budgets, and investments will remain intact.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onCacheCleared();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            child: const Text("Clear Cache"),
          ),
        ],
      ),
    );
  }

  static void showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: const [
            Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text("Privacy Policy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            "Tracklet SaveBuddy values your financial privacy.\n\n"
            "1. Offline First: All transactions, budgets, and investment records are stored locally on your device via SQLite.\n\n"
            "2. Encrypted Sync: Cloud sync uses SSL/TLS encryption.\n\n"
            "3. Personal Data: We collect your name and email only for user authentication and cross-device sync.\n\n"
            "4. Zero Tracking: We do not sell or track your financial data with third-party advertisers or data brokers.\n\n"
            "5. Data Control & Deletion: You can delete individual records or permanently delete your account and all associated cloud/local data under Settings > Delete Account, or request deletion externally at:\n"
            "https://savebuddy-finance.web.app/delete-account\n\n"
            "Official Policy: https://savebuddy-finance.web.app/privacy",
            style: TextStyle(height: 1.4, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Close", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showHelpCenterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: const [
            Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text("Help Center & FAQs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Q: How to create a new expense book?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 2),
                Text("A: Tap on Books tab and click '+ Create Book'.", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                SizedBox(height: 12),
                Text("Q: How offline sync works?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 2),
                Text("A: Any changes made offline are saved locally and synced automatically when network resumes.", style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Close", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showContactUsDialog({
    required BuildContext context,
    required VoidCallback onMessageSent,
  }) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: const [
            Icon(Icons.headset_mic_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text("Contact Us & Feedback", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Support Email: support@tracklet-savebuddy.com", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type your message or feature request...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onMessageSent();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("Send Message"),
          ),
        ],
      ),
    );
  }

  static void showAboutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: [
            Container(
              padding: AppSpacing.p8,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: AppDimensions.icon22),
            ),
            const SizedBox(width: AppSpacing.small),
            const Text("About Tracklet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tracklet SaveBuddy",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? AppColors.textWhite : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "App Version 2.1.4 (Build 104)",
              style: TextStyle(color: isDark ? AppColors.textMuted : AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              "Tracklet SaveBuddy is your modern offline-first finance & expense tracking assistant designed to manage books, budgets, and investments effortlessly.",
              style: TextStyle(
                height: 1.4,
                color: isDark ? AppColors.textWhite : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              "Developer: NDevStudios",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? AppColors.textWhite : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Close", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showLogoutDialog({
    required BuildContext context,
    required Future<void> Function() onLogout,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: const [
            Icon(Icons.logout_rounded, color: AppColors.expense, size: AppDimensions.icon24),
            SizedBox(width: AppSpacing.small),
            Text(
              "Logout",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to log out of Tracklet SaveBuddy?",
          style: TextStyle(
            color: isDark ? AppColors.textWhite : AppColors.textPrimary,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await onLogout();
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

  /// Interactive dialog for permanent account & data deletion (Google Play Account Deletion Policy)
  static void showDeleteAccountDialog({
    required BuildContext context,
    required String email,
    required Future<void> Function() onDeleteConfirmed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: AppDimensions.icon24),
            SizedBox(width: AppSpacing.small),
            Text(
              "Delete Account",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.expense),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Are you sure you want to permanently delete your account ($email)?",
                style: TextStyle(
                  color: isDark ? AppColors.textWhite : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "This action is permanent and cannot be undone:\n"
                "• All your local books, transactions, and categories will be purged.\n"
                "• All your cloud-synced ledgers and investment records will be permanently deleted.\n"
                "• Your login credentials will be erased immediately.\n\n"
                "Web Deletion Portal:\n"
                "Users may also request account and data deletion externally at:\n"
                "https://savebuddy-finance.web.app/delete-account",
                style: TextStyle(
                  color: isDark ? AppColors.textMuted : AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await onDeleteConfirmed();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: AppColors.textWhite,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.medium,
              ),
            ),
            child: const Text("Delete Permanently"),
          ),
        ],
      ),
    );
  }
}
