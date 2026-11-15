import 'package:expense_tracker/core/widgets/app_empty_state.dart';
import 'package:expense_tracker/core/widgets/app_loading.dart';
import 'package:expense_tracker/custom_widgets/category_breakdown_tile.dart';
import 'package:expense_tracker/custom_widgets/custom_summarycard.dart';
import 'package:expense_tracker/custom_widgets/custom_textfield.dart';
import 'package:expense_tracker/custom_widgets/toggle_button.dart';
import 'package:expense_tracker/services/currency_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Custom Widgets Tests', () {
    testWidgets('AppLoading displays CircularProgressIndicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AppLoading()),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AppEmptyState displays title, description and button', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.menu_book_rounded,
              title: 'Empty List',
              description: 'Nothing here yet',
              buttonLabel: 'Add Item',
              onButtonPressed: () {
                pressed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Empty List'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);

      await tester.tap(find.text('Add Item'));
      expect(pressed, isTrue);
    });

    testWidgets('CustomTextfield renders icon and hintText', (WidgetTester tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomTextfield(
              textEditingController: controller,
              hintText: 'Enter Email',
              icon: Icons.email,
              isPassword: false,
            ),
          ),
        ),
      );

      expect(find.text('Enter Email'), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'test@test.com');
      expect(controller.text, 'test@test.com');
    });

    testWidgets('CustomSummaryCard renders title, amount and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomSummaryCard(
              title: 'Total Income',
              amount: 50000.0,
              icon: Icons.arrow_downward,
              color: Colors.green,
            ),
          ),
        ),
      );

      expect(find.text('Total Income'), findsOneWidget);
      expect(find.text('₹50000'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    });

    testWidgets('CategoryBreakdownTile renders category name, amount, percent', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryBreakdownTile(
              category: 'Food & Dining',
              amount: 3500.0,
              percent: 35.0,
              color: Colors.orange,
            ),
          ),
        ),
      );

      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text(CurrencyService.formatCompact(3500.0)), findsOneWidget);
      expect(find.text('35%'), findsOneWidget);
    });

    testWidgets('ToggleButton renders switches correctly', (WidgetTester tester) async {
      bool isCredit = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToggleButton(
              initialIsCredit: isCredit,
              onToggle: (val) {
                isCredit = val;
              },
            ),
          ),
        ),
      );

      expect(find.text('DEBIT'), findsOneWidget);
      expect(find.text('CREDIT'), findsOneWidget);
    });
  });
}
