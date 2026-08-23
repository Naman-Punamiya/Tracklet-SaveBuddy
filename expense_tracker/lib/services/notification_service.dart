import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotificationService {
  static final AppNotificationService instance = AppNotificationService._();
  AppNotificationService._();

  Timer? _dailyTimer;

  bool isDailyReminderEnabled = true;
  bool isBudgetAlertEnabled = true;

  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    isDailyReminderEnabled = prefs.getBool('daily_reminder_enabled') ?? true;
    isBudgetAlertEnabled = prefs.getBool('budget_alert_enabled') ?? true;

    if (isDailyReminderEnabled) {
      scheduleDailyReminder();
    }
  }

  void scheduleDailyReminder() {
    _dailyTimer?.cancel();
    _dailyTimer = Timer.periodic(const Duration(hours: 4), (timer) {
      if (isDailyReminderEnabled) {
        showNotificationBanner(
          title: "Daily Expense Reminder",
          body: "Don't forget to log your daily expenses in Tracklet SaveBuddy!",
          icon: Icons.notifications_active_rounded,
        );
      }
    });
  }

  void stopDailyReminder() {
    _dailyTimer?.cancel();
    _dailyTimer = null;
  }

  void checkBudgetThreshold(double currentSpent, double totalBudget, {BuildContext? context}) {
    if (!isBudgetAlertEnabled || totalBudget <= 0) return;
    final ratio = currentSpent / totalBudget;
    if (ratio >= 0.8) {
      final percentage = (ratio * 100).toStringAsFixed(0);
      showNotificationBanner(
        title: "Budget Overspending Warning",
        body: "Alert: You have reached $percentage% of your allocated budget!",
        icon: Icons.warning_amber_rounded,
        isWarning: true,
        context: context,
      );
    }
  }

  void showNotificationBanner({
    required String title,
    required String body,
    IconData icon = Icons.notifications_active_rounded,
    bool isWarning = false,
    BuildContext? context,
  }) {
    final snackBar = SnackBar(
      elevation: 6,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isWarning ? const Color(0xFFDC2626) : const Color(0xFF059669),
      duration: const Duration(seconds: 4),
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (context != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } else if (messengerKey.currentState != null) {
      messengerKey.currentState!.hideCurrentSnackBar();
      messengerKey.currentState!.showSnackBar(snackBar);
    }
  }
}
