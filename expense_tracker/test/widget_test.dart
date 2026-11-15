import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/pages/Auth/login_page.dart';
import 'package:expense_tracker/pages/home_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers/test_helpers.dart';

void main() {
  setupTestDatabase();

  setUp(() async {
    setupTestSharedPreferences();
    await resetTestDatabase();
  });

  group('MyApp Root Widget Tests', () {
    testWidgets('renders LoginPage when not logged in', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MyApp(isLoggedIn: false, email: '', password: '', userId: 0),
      );
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('renders HomePage when logged in', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MyApp(isLoggedIn: true, email: 'user@test.com', password: 'password', userId: 1),
      );
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Here are your books'), findsOneWidget);
    });
  });
}
