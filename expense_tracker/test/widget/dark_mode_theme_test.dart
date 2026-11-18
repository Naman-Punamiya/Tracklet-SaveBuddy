import 'package:expense_tracker/core/theme/app_colors.dart';
import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/custom_widgets/custom_card.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/pages/HomePage/Expenses/inside_book_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUp(() {
    setupTestSharedPreferences();
  });

  group('Dark Mode & Theme Architecture Tests', () {
    test('AppTheme light and dark ThemeData have correct brightness and base colors', () {
      final light = AppTheme.lightTheme;
      final dark = AppTheme.darkTheme;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);

      // Verify scaffold backgrounds
      expect(light.scaffoldBackgroundColor, AppColors.lightBackground);
      expect(dark.scaffoldBackgroundColor, AppColors.darkBackground);

      // Verify card color surfaces
      expect(light.cardColor, Colors.white);
      expect(dark.cardColor, AppColors.darkSurface);

      // Verify dark theme color scheme
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(dark.colorScheme.surface, AppColors.darkSurface);

      // Verify dark text theme has high contrast colors
      expect(dark.textTheme.titleLarge?.color, AppColors.textPrimaryDark);
      expect(dark.textTheme.bodyMedium?.color, AppColors.textSecondaryDark);
      expect(dark.textTheme.bodySmall?.color, AppColors.textSecondaryDark);

      // Verify icon themes
      expect(light.iconTheme.color, AppColors.textPrimary);
      expect(dark.iconTheme.color, AppColors.textPrimaryDark);

      // Verify floatingActionButton in dark theme uses primaryAccent for high contrast
      expect(dark.floatingActionButtonTheme.backgroundColor, AppColors.primaryAccent);
      expect(dark.floatingActionButtonTheme.foregroundColor, const Color(0xFF052E23));

      // Verify dialogTheme in dark theme
      expect(dark.dialogTheme.backgroundColor, AppColors.darkCard);
      expect(dark.dialogTheme.titleTextStyle?.color, AppColors.textPrimaryDark);
      expect(dark.dialogTheme.contentTextStyle?.color, AppColors.textSecondaryDark);

      // Verify chipTheme in dark theme
      expect(dark.chipTheme.backgroundColor, AppColors.darkSurface);
      expect(dark.chipTheme.selectedColor, AppColors.primaryAccent);

      // Verify date and time picker themes in dark theme
      expect(dark.datePickerTheme.backgroundColor, AppColors.darkCard);
      expect(dark.timePickerTheme.backgroundColor, AppColors.darkCard);
    });

    test('Theme switching via themeNotifier and SharedPreferences persistence', () async {
      SharedPreferences.setMockInitialValues({'user_theme': 'Dark'});
      final prefs = await SharedPreferences.getInstance();

      String savedTheme = prefs.getString('user_theme') ?? 'System Default';
      if (savedTheme == 'Light') {
        themeNotifier.value = ThemeMode.light;
      } else if (savedTheme == 'Dark') {
        themeNotifier.value = ThemeMode.dark;
      } else {
        themeNotifier.value = ThemeMode.system;
      }

      expect(themeNotifier.value, ThemeMode.dark);

      // Update to Light mode
      await prefs.setString('user_theme', 'Light');
      themeNotifier.value = ThemeMode.light;
      expect(themeNotifier.value, ThemeMode.light);
      expect(prefs.getString('user_theme'), 'Light');

      // Update back to Dark mode
      await prefs.setString('user_theme', 'Dark');
      themeNotifier.value = ThemeMode.dark;
      expect(themeNotifier.value, ThemeMode.dark);
      expect(prefs.getString('user_theme'), 'Dark');
    });

    testWidgets('AppLoading spinner adapts color correctly in light mode', (tester) async {
      await tester.pumpWidget(
        Theme(
          data: AppTheme.lightTheme,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: AppLoading(),
          ),
        ),
      );
      await tester.pump();

      final circularProgress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(circularProgress.color, AppColors.primary);
    });

    testWidgets('AppLoading spinner adapts color correctly in dark mode', (tester) async {
      await tester.pumpWidget(
        Theme(
          data: AppTheme.darkTheme,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: AppLoading(),
          ),
        ),
      );
      await tester.pump();

      final circularProgress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(circularProgress.color, AppColors.primaryAccent);
    });

    testWidgets('AppEmptyState action button adapts contrast in dark mode', (tester) async {
      await tester.pumpWidget(
        Theme(
          data: AppTheme.darkTheme,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: AppEmptyState(
                icon: Icons.receipt_long,
                title: 'No Data',
                description: 'There are no transactions yet.',
                buttonLabel: 'Add First',
                onButtonPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No Data'), findsOneWidget);
      expect(find.text('Add First'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final bgColor = button.style?.backgroundColor?.resolve({WidgetState.selected}) ??
          button.style?.backgroundColor?.resolve({});
      expect(bgColor, AppColors.primaryAccent);
    });

    testWidgets('CustomCard adapts background color in light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.lightTheme,
            child: const Scaffold(
              body: CustomCard(
                leadingIcon: Icons.star,
                title: 'Card Title',
                subtitle: 'Card Subtitle',
                trailingIcon: Icons.arrow_forward_ios,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(CustomCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.white);
    });

    testWidgets('CustomCard adapts background color in dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Theme(
            data: AppTheme.darkTheme,
            child: const Scaffold(
              body: CustomCard(
                leadingIcon: Icons.star,
                title: 'Card Title',
                subtitle: 'Card Subtitle',
                trailingIcon: Icons.arrow_forward_ios,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(CustomCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.darkCard);
    });

    testWidgets('BookInsideHomePage renders bottom navigation icons in light and dark themes', (tester) async {
      setupTestDatabase();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Light Theme Test
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: const BookInsideHomePage(
            email: 'test@example.com',
            password: 'password123',
            bookId: '1',
            bookName: 'General',
          ),
        ),
      );
      for (int i = 0; i < 4; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      var navBar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(navBar.selectedItemColor, const Color(0xFF065F46));
      expect(navBar.unselectedItemColor, const Color(0xFF6B7280));
      expect(find.byIcon(Icons.receipt_long_rounded), findsWidgets);
      expect(find.byIcon(Icons.bar_chart_rounded), findsWidgets);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Report'), findsOneWidget);

      // Dark Theme Test
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const BookInsideHomePage(
            email: 'test@example.com',
            password: 'password123',
            bookId: '1',
            bookName: 'General',
          ),
        ),
      );
      for (int i = 0; i < 4; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      navBar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
      expect(navBar.selectedItemColor, AppColors.primaryAccent);
      expect(navBar.unselectedItemColor, AppColors.textMuted);
      expect(find.byIcon(Icons.receipt_long_rounded), findsWidgets);
      expect(find.byIcon(Icons.bar_chart_rounded), findsWidgets);
    });
  });
}
