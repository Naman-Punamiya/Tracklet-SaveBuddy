import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/pages/splash_screen.dart';
import 'package:expense_tracker/services/auth_storage_service.dart';
import 'package:expense_tracker/services/currency_service.dart';
import 'package:expense_tracker/services/deep_link_service.dart';
import 'package:expense_tracker/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppNotificationService.instance.init();

  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Initialize secure credential storage and safely migrate legacy plaintext password if present
  await AuthStorageService.instance.init(prefs: prefs);

  bool isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
  String email = prefs.getString("email") ?? "";
  int? storedUserId = prefs.getInt("userId");

  // Validate session integrity: if userId is invalid/missing, require login
  if (isLoggedIn && (storedUserId == null || storedUserId <= 0 || email.isEmpty)) {
    isLoggedIn = false;
    storedUserId = null;
  }

  // Verify that an active auth token exists in secure storage for persistent session
  if (isLoggedIn && AuthStorageService.instance.currentAuthToken.isEmpty) {
    final token = await AuthStorageService.instance.getAuthToken();
    if (token.isEmpty) {
      isLoggedIn = false;
      storedUserId = null;
    }
  }

  int userId = storedUserId ?? 0;

  String savedTheme = prefs.getString("user_theme") ?? "System Default";
  if (savedTheme == "Light") {
    themeNotifier.value = ThemeMode.light;
  } else if (savedTheme == "Dark") {
    themeNotifier.value = ThemeMode.dark;
  } else {
    themeNotifier.value = ThemeMode.system;
  }

  String savedCurrency = prefs.getString("user_currency") ?? "INR (₹)";
  CurrencyService.currencyNotifier.value = savedCurrency;

  runApp(MyApp(
    isLoggedIn: isLoggedIn,
    email: email,
    userId: userId,
  ));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;
  final String email;
  final String password;
  final int userId;
  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.email,
    this.password = '',
    required this.userId,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.init(_navigatorKey);
    });
  }

  @override
  void dispose() {
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: AppNotificationService.instance.messengerKey,
          title: 'Tracklet SaveBuddy',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: isDark
                  ? AppTheme.darkSystemUiOverlayStyle
                  : AppTheme.lightSystemUiOverlayStyle,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: SplashScreen(
            isLoggedIn: widget.isLoggedIn,
            email: widget.email,
            password: widget.password,
            userId: widget.userId,
          ),
        );
      },
    );
  }
}
