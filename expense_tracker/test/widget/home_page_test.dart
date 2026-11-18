import 'package:expense_tracker/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
  });

  group('HomePage Navigation & Tabs Tests', () {
    testWidgets('renders BottomNavigationBar with Books, Investment, Settings', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(
            userId: 1,
            email: 'test@example.com',
            password: 'password123',
          ),
        ),
      );
      for (int i = 0; i < 4; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Books'), findsOneWidget);
      expect(find.text('Investments'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsWidgets);
      expect(find.byIcon(Icons.auto_graph_rounded), findsWidgets);
      expect(find.byIcon(Icons.tune_rounded), findsWidgets);
    });

    testWidgets('switches to Investment tab when tapped', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(
            userId: 1,
            email: 'test@example.com',
            password: 'password123',
          ),
        ),
      );
      for (int i = 0; i < 4; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Investments'));
      for (int i = 0; i < 6; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Investments'), findsNWidgets(2));
    });

    testWidgets('switches to Settings tab when tapped', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(
            userId: 1,
            email: 'test@example.com',
            password: 'password123',
          ),
        ),
      );
      for (int i = 0; i < 4; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.tap(find.text('Settings'));
      for (int i = 0; i < 4; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Profile Information'), findsOneWidget);
    });
  });
}
