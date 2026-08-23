import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/pages/splash_screen.dart';
import 'package:expense_tracker/services/currency_service.dart';
import 'package:expense_tracker/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppNotificationService.instance.init();

  SharedPreferences prefs = await SharedPreferences.getInstance();

  bool isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
  String email = prefs.getString("email") ?? "";
  String password = prefs.getString("password") ?? "";

  String savedTheme = prefs.getString("user_theme") ?? "System Default";
  if (savedTheme == "Light") {
    themeNotifier.value = ThemeMode.light;
  } else if (savedTheme == "Dark") {
    themeNotifier.value = ThemeMode.dark;
  } else {
    themeNotifier.value = ThemeMode.system;
  }

  String savedCurrency = prefs.getString("user_currency") ?? "USD (\$)";
  CurrencyService.currencyNotifier.value = savedCurrency;

  runApp(MyApp(isLoggedIn: isLoggedIn, email: email, password: password));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String email;
  final String password;
  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.email,
    required this.password,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          scaffoldMessengerKey: AppNotificationService.instance.messengerKey,
          title: 'Tracklet SaveBuddy',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          home: SplashScreen(
            isLoggedIn: isLoggedIn,
            email: email,
            password: password,
          ),
        );
      },
    );
  }
}
